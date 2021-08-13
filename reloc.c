/*
 * Loading and relocation of relocatable ELF objects (REL)
 *
 * Copyright (C) 2021 Martin Krastev <blu.dark@gmail.com>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libelf.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdint.h>
#include <errno.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/mman.h>

int apply_relocate_add(Elf64_Shdr **sechdrs,
					   unsigned int symsec,
					   unsigned int relsec);

/* Following code based on IBM s390 elf relocation sample */
/* https://www.ibm.com/docs/en/zos/2.2.0?topic=file-example-relocating-addresses-within-elf */

typedef uint64_t uint64;
typedef int64_t  int64;

/*  ELF file details
*/
typedef struct ElfDetails_s {
	Elf*                ed_elf;          /* ->ELF instance for CU          */

	/* ELF Section details                                                 */
	Elf64_Shdr**        ed_shdrs;        /* List of ->ELF section header   */
	uint64              ed_n_elf_scns;   /* Number of ELF sections         */

	Elf64_Section       ed_text_idx;     /* .text section index            */
	Elf64_Section       ed_rodata_idx;   /* .rodata section index          */
	Elf64_Section       ed_rel_text_idx; /* .rel.text section index        */
	Elf64_Section       ed_rela_text_idx;/* .rela.text section index       */
	Elf64_Section       ed_symtab_idx;   /* .symtab section index          */
	Elf64_Section       ed_strtab_idx;   /* .strtab section index          */
	Elf64_Section       ed_shstrtab_idx; /* .shstrtab section index        */
} *ElfDetails;

const char *str_from_st_type(uint8_t x)
{
	switch (x) {
	case STT_NOTYPE:
		return "STT_NOTYPE";
	case STT_OBJECT:
		return "STT_OBJECT";
	case STT_FUNC:
		return "STT_FUNC";
	case STT_SECTION:
		return "STT_SECTION";
	case STT_FILE:
		return "STT_FILE";
	case STT_COMMON:
		return "STT_COMMON";
	case STT_TLS:
		return "STT_TLS";
	case STT_NUM:
		return "STT_NUM";
#if 0
	case STT_LOOS:
		return "STT_LOOS";
#endif
	case STT_GNU_IFUNC:
		return "STT_GNU_IFUNC";
	case STT_HIOS:
		return "STT_HIOS";
	case STT_LOPROC:
		return "STT_LOPROC";
	case STT_HIPROC:
		return "STT_HIPROC";
	}
	return "unknown_st_type";
}

const char *str_from_st_bind(uint8_t x)
{
	switch (x) {
	case STB_LOCAL:
		return "STB_LOCAL";
	case STB_GLOBAL:
		return "STB_GLOBAL";
	case STB_WEAK:
		return "STB_WEAK";
	case STB_NUM:
		return "STB_NUM";
#if 0
	case STB_LOOS:
		return "STB_LOOS";
#endif
	case STB_GNU_UNIQUE:
		return "STB_GNU_UNIQUE";
	case STB_HIOS:
		return "STB_HIOS";
	case STB_LOPROC:
		return "STB_LOPROC";
	case STB_HIPROC:
		return "STB_HIPROC";
	}
	return "unknown_st_bind";
}

const char *str_from_sh_name(
	Elf64_Word name,
	Elf *elf)
{
	return elf_strptr(elf,
		elf64_getehdr(elf)->e_shstrndx, name);
}

const char *str_from_st_shndx(
	Elf64_Section shndx,
	Elf *elf)
{
	if (shndx != SHN_UNDEF && shndx < SHN_LORESERVE)
		return elf_strptr(elf,
			elf64_getehdr(elf)->e_shstrndx,
			elf64_getshdr(elf_getscn(elf, shndx))->sh_name);

	switch (shndx) {
	case SHN_UNDEF:
		return "SHN_UNDEF";
	case SHN_ABS:
		return "SHN_ABS";
	case SHN_COMMON:
		return "SHN_COMMON";
	case SHN_XINDEX:
		return "SHN_XINDEX";
	}

	return "<unknown section>";
}

/* Process 64-bit ELF symbol table
*/
static int
	_load_elf64_symbol_table(
		ElfDetails details)
{
	Elf* elf;
	Elf64_Sym* symtab;
	uint64 n_symbols, i;

	elf = details->ed_elf;
	if (elf == NULL) {
		return -1;
	}

	n_symbols = (details->ed_shdrs[details->ed_symtab_idx]->sh_size) / sizeof(Elf64_Sym);
	if (n_symbols == 0) {
		return -1;
	}

	/* Process the .symtab section */
	symtab = (Elf64_Sym*)(details->ed_shdrs[details->ed_symtab_idx]->sh_addr);

	for (i = 0; i < n_symbols; i++, symtab++) {
		if (ELF64_ST_TYPE(symtab->st_info) == STT_SECTION) {
			/* Section symbols cannot index anything else but their respective sections */
			if (symtab->st_shndx == SHN_UNDEF || symtab->st_shndx >= SHN_LORESERVE) {
				return -1;
			}
			if (symtab->st_shndx >= details->ed_n_elf_scns) {
				return -1;
			}

			symtab->st_value = details->ed_shdrs[symtab->st_shndx]->sh_addr;
		}
		else if (symtab->st_shndx != SHN_UNDEF && symtab->st_shndx < SHN_LORESERVE) {
			/* Non-section symbols without special indices must index valid sections */
			if (symtab->st_shndx >= details->ed_n_elf_scns) {
				return -1;
			}

			symtab->st_value += details->ed_shdrs[symtab->st_shndx]->sh_addr;
		}
	}

	return 0;
}

/* Load ELF file section and symbol tables; relocate sections and symbols based on loading/mapping vaddr
*/
static int
	_load_elf_file_details(
		Elf*                elf,
		ElfDetails*         ret_details,
		ptrdiff_t           diff_exec)
{
	ElfDetails details;
	char* ehdr_ident;
	Elf64_Ehdr* ehdr64;
	Elf64_Shdr* shdr64;
	Elf_Scn* scn;
	Elf_Data* data;
	char* scn_name;
	Elf64_Shdr** section_list;
	uint64 scn_idx, n_elf_scns, shstrtab_idx;
	int rc;

	/* Determine if 64-bit or 32-bit ELF file */
	if ((ehdr_ident = elf_getident(elf, NULL)) == NULL) {
		return -1;
	}

	if (ehdr_ident[EI_CLASS] != ELFCLASS64) {
		return -1;
	}

	/* Access the ELF file header */
	if ((ehdr64 = elf64_getehdr(elf)) == NULL) {
		return -1;
	}

	/* Validate the ELF type */
	if (ehdr64->e_type != ET_REL) {
		return -1;
	}

	/* Validate machine type */
	if (ehdr64->e_machine != EM_AARCH64) {
		return -1;
	}

	n_elf_scns   = ehdr64->e_shnum;
	shstrtab_idx = ehdr64->e_shstrndx;

	/* Allocate the new ElfDetails object */
	if (n_elf_scns == 0) {
		return -1;
	}

	details = (ElfDetails) calloc(sizeof(struct ElfDetails_s), 1);
	if (details == NULL) {
		return -2; /* out of memory */
	}

	/* Initialize the new object */
	details->ed_elf          = elf;
	details->ed_n_elf_scns   = n_elf_scns;
	details->ed_shstrtab_idx = shstrtab_idx;

	/* Allocate list object (array of Elf64_Shdr*) for the ELF sections */
	section_list = (Elf64_Shdr**) calloc(sizeof(Elf64_Shdr*), n_elf_scns);
	if (section_list == NULL) {
		return -2; /* out of memory */
	}
	details->ed_shdrs = section_list;

	/* Populate the ELF section lists */
	scn_idx = 0;
	scn = NULL;

	while ((scn = elf_nextscn(elf, scn)) != NULL) {
		scn_idx = elf_ndxscn(scn);

		if (scn_idx >= n_elf_scns) {
			return -1;
		}

		if ((shdr64 = elf64_getshdr(scn)) == NULL) {
			return -1;
		}

		section_list[scn_idx] = shdr64;

		if ((scn_name = elf_strptr(elf, shstrtab_idx, shdr64->sh_name)) == NULL) {
			return -1;
		}

		if (strcmp(scn_name,".text") == 0) {
			if (shdr64->sh_type != SHT_PROGBITS) {
				return -1;
			}
			/* Validate there is only one .text section */
			if (details->ed_text_idx != 0) {
				return -1;
			}
			details->ed_text_idx = scn_idx;
		}

		if (strcmp(scn_name,".rodata") == 0) {
			if (shdr64->sh_type != SHT_PROGBITS) {
				return -1;
			}
			/* Validate there is only one .rodata section */
			if (details->ed_rodata_idx != 0) {
				return -1;
			}
			details->ed_rodata_idx = scn_idx;
		}

		if (strcmp(scn_name,".rel.text") == 0) {
			if (shdr64->sh_type != SHT_REL) {
				return -1;
			}
			/* Validate there is only one .rel.text section */
			if (details->ed_rel_text_idx != 0) {
				return -1;
			}
			details->ed_rel_text_idx = scn_idx;
		}

		if (strcmp(scn_name,".rela.text") == 0) {
			if (shdr64->sh_type != SHT_RELA) {
				return -1;
			}
			/* Validate there is only one .rel.text section */
			if (details->ed_rela_text_idx != 0) {
				return -1;
			}
			details->ed_rela_text_idx = scn_idx;
		}
		else if (strcmp(scn_name,".symtab") == 0) {
			if (shdr64->sh_type != SHT_SYMTAB) {
				return -1;
			}
			/* Validate there is only one .symtab section */
			if (details->ed_symtab_idx != 0) {
				return -1;
			}
			details->ed_symtab_idx = scn_idx;
		}
		else if (strcmp(scn_name,".strtab") == 0) {
			if (shdr64->sh_type != SHT_STRTAB) {
				return -1;
			}
			/* Validate there is only one .strtab section */
			if (details->ed_strtab_idx != 0) {
				return -1;
			}
			details->ed_strtab_idx = scn_idx;
		}
		else if (strcmp(scn_name,".shstrtab") == 0) {
			if (shdr64->sh_type != SHT_STRTAB) {
				return -1;
			}
			/* Validate there is only one .shstrtab section */
			if (details->ed_shstrtab_idx != scn_idx) {
				return -1;
			}
			if (shstrtab_idx != scn_idx) {
				return -1;
			}
		}

		/* Resolve the vaddr and size of ELF section data */
		if ((data = elf_getdata(scn, 0)) != NULL) {
			if (shdr64->sh_size != data->d_size) {
				return -1;
			}
			shdr64->sh_addr = (Elf64_Addr)data->d_buf;

			if (scn_idx == details->ed_text_idx ||
			    scn_idx == details->ed_rodata_idx) {
				shdr64->sh_addr += diff_exec;
			}
		}
	}

	/* Ensure the file has all required sections */
	if ((details->ed_text_idx     == 0) ||
	    (details->ed_symtab_idx   == 0) ||
	    (details->ed_strtab_idx   == 0) ||
	    (details->ed_shstrtab_idx == 0)) {
		return -1;
	}

	/* Process the symbol table from the ELF .symtab section */
	rc = _load_elf64_symbol_table(details);
	if (rc) return rc;

	/* Return the ElfDetails object to the caller */
	*ret_details = details;

	return 0;
}

/* Terminate ELF loader processing, release resources
*/
static int
	_load_elf_term(
		ElfDetails details)
{
	if (details == NULL) {
		return 0;
	}

	if (details->ed_shdrs != NULL) {
		free(details->ed_shdrs);
	}

	free(details);

	return 0;
}

/* Load ELF file, relocate based on loading/mapping vaddr, and print symtab
*/
static int
	relocate_elf_load_cu(
		Elf* elf,
		void** start,
		ptrdiff_t diff_exec)
{
	ElfDetails details = NULL;
	Elf64_Sym* symtab;
	uint64 n_symbols, i;
	int rc;

	/* Load ELF file section and symbol tables */
	rc = _load_elf_file_details(elf, &details, diff_exec);
	if (rc)
		goto term;

	/* Print all symbols, except the first dummy */
	symtab = (Elf64_Sym*)(details->ed_shdrs[details->ed_symtab_idx]->sh_addr);
	symtab++;
	n_symbols = (details->ed_shdrs[details->ed_symtab_idx]->sh_size) / sizeof(Elf64_Sym);

	printf("    symtab_value____ symtab_type__ symtab_bind___ symtab_section___ symtab_name__\n");

	for (i = 1; i < n_symbols; i++, symtab++) {
		const char* name = "_____________";

		/* Resolve the symbol name */
		if (symtab->st_name == 0) {
			if (ELF64_ST_TYPE(symtab->st_info) == STT_SECTION) {
				name = str_from_st_shndx(symtab->st_shndx, elf);
			}
		}
		else {
			name = elf_strptr(details->ed_elf, details->ed_strtab_idx, symtab->st_name);

			if (symtab->st_shndx == details->ed_text_idx && !strcmp(name, "_start")) {
				*start = (void *)symtab->st_value;
			}
		}

		printf("%2ld: %016lx %-13s %-14s %-17s %s\n",
			i,
			symtab->st_value,
			str_from_st_type(ELF64_ST_TYPE(symtab->st_info)),
			str_from_st_bind(ELF64_ST_BIND(symtab->st_info)),
			str_from_st_shndx(symtab->st_shndx, elf),
			name);
	}

	/* Apply any SHT_REL relocations */
	if (details->ed_rel_text_idx != 0) {
		fprintf(stderr, "error: cannot handle SHT_REL section\n");
		rc = -1;
		goto term;
	}

	/* Apply any SHT_RELA relocations */
	if (details->ed_rela_text_idx != 0) {
		rc = apply_relocate_add(details->ed_shdrs,
				details->ed_symtab_idx,
				details->ed_rela_text_idx);
	}

term:
	/* Remove temporary tables */
	_load_elf_term(details);

	return rc;
}

int main(int argc, char** argv)
{
	int fd;
	struct stat sb;
	void *p, *q, *start = NULL;
	int rc;
	Elf *elf;

	if (argc != 2) {
		printf("usage: %s <elf_rel>\n", argv[0]);
		return -1;
	}

	elf_version(EV_CURRENT);

	fd = open(argv[1], O_RDONLY);

	if (fd < 0) {
		fprintf(stderr, "error: cannot open file\n");
		return -1;
	}

	if (fstat(fd, &sb) < 0) {
		close(fd);
		fprintf(stderr, "error: cannot stat file\n");
		return -1;
	}

	/* Get two distinct mappings to the same file -- 1st to be used for
	   writable sections, 2nd -- for the read-only/exec sections; pass
	   the 1st mapping to the ELF parser, but also make it aware of the
	   2nd mapping via a ptrdiff */
	p = mmap(NULL, sb.st_size, PROT_READ | PROT_WRITE, MAP_PRIVATE, fd, 0);
	q = mmap(NULL, sb.st_size, PROT_READ | PROT_WRITE, MAP_PRIVATE, fd, 0);
	close(fd);

	if (p == MAP_FAILED || q == MAP_FAILED) {
		fprintf(stderr, "error: cannot mmap file\n");
		return -1;
	}

	/* Process ELF via the 1st mapping */
	elf = elf_memory(p, sb.st_size);

	if (elf == NULL) {
		fprintf(stderr, "error: cannot elf_memory\n");
		return -1;
	}

	rc = relocate_elf_load_cu(elf, &start, q - p);

	if (rc) {
		fprintf(stderr, "error: cannot relocate_elf_load_cu\n");
		return -1;
	}

	rc = mprotect(q, sb.st_size, PROT_READ | PROT_EXEC);

	if (rc) {
		fprintf(stderr, "error: cannot mprotect\n");
		return -1;
	}

	if (start != NULL)
		((void (*)(void))start)();

	return 0;
}
