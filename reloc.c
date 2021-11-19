/*
 * Loading and relocation of relocatable ELF objects (REL)
 *
 * Copyright (C) 2021 Martin Krastev <blu.dark@gmail.com>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if __APPLE__ != 0
#include <libelf/libelf.h>
#else
#include <libelf.h>
#endif
#include <fcntl.h>
#include <stddef.h>
#include <stdint.h>
#include <errno.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/mman.h>

#if __APPLE__ != 0
#include "char_ptr_arr.h"
#else
#include "vma.h"
#endif

#if __APPLE__ != 0
#ifndef EM_AARCH64
#define EM_AARCH64 183
#endif

#ifndef MAP_POPULATE
#define MAP_POPULATE 0
#endif

typedef Elf64_Half Elf64_Section;
#endif

int apply_relocate_add(Elf64_Shdr **sechdrs,
                       unsigned int symsec,
                       unsigned int relsec);

/* Following code based on IBM s390 ELF relocation sample */
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
	Elf64_Section       ed_rel_text_idx; /* .rel.text section index        */
	Elf64_Section       ed_rela_text_idx;/* .rela.text section index       */
	Elf64_Section       ed_symtab_idx;   /* .symtab section index          */
	Elf64_Section       ed_strtab_idx;   /* .strtab section index          */
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
	case STT_LOOS:
		return "STT_LOOS";
#if 0
	case STT_GNU_IFUNC:
		return "STT_GNU_IFUNC";
#endif
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
	case STB_LOOS:
		return "STB_LOOS";
#if 0
	case STB_GNU_UNIQUE:
		return "STB_GNU_UNIQUE";
#endif
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

/* Seek a symbol by name in a previously loaded REL; don't try to resolve section
   names, as Elf64_Ehdr.e_shstrndx has been repurposed as e_strtabndx */
static Elf64_Sym *seek_prev_symbol(Elf *elf, const char *name)
{
	Elf_Scn *scn;
	Elf64_Shdr *shdr64;

	if (elf == NULL) {
		return NULL;
	}

	/* Enumerate the ELF sections, seeking for .symtab */
	scn = NULL;

	while ((scn = elf_nextscn(elf, scn)) != NULL) {
		shdr64 = elf64_getshdr(scn);

		if (shdr64->sh_type == SHT_SYMTAB) {
			uint64 n_symbols, i;
			Elf64_Sym *symtab;

			n_symbols = shdr64->sh_size / sizeof(*symtab);

			/* Process the .symtab section, skipping the first dummy */
			symtab = (Elf64_Sym*)shdr64->sh_addr;
			symtab++;

			for (i = 1; i < n_symbols; i++, symtab++) {
				if (symtab->st_shndx != SHN_UNDEF &&
					ELF64_ST_TYPE(symtab->st_info) != STT_SECTION &&
					ELF64_ST_BIND(symtab->st_info) == STB_GLOBAL) {
					/* Elf64_Ehdr.e_shstrndx has been repurposed as e_strtabndx;
					   getting a section name actually gives us a symbol name */
					const char *sym_name = str_from_sh_name(symtab->st_name, elf);

					if (strcmp(sym_name, name) == 0) {
						return symtab;
					}
				}
			}
			/* More than one SHT_SYMTAB section is not supported */
			break;
		}
	}

	/* Fall back to earlier RELs */
	return seek_prev_symbol((Elf *)elf64_getehdr(elf)->e_entry, name);
}

/* Process 64-bit ELF symbol table
*/
static int
	_load_elf64_symbol_table(
		ElfDetails details)
{
	Elf *elf;
	Elf64_Sym *symtab;
	uint64 n_symbols, i;

	elf = details->ed_elf;
	if (elf == NULL) {
		return -1;
	}

	n_symbols = (details->ed_shdrs[details->ed_symtab_idx]->sh_size) / sizeof(*symtab);
	if (n_symbols == 0) {
		return -1;
	}

	/* Process the .symtab section, skipping the first dummy */
	symtab = (Elf64_Sym*)(details->ed_shdrs[details->ed_symtab_idx]->sh_addr);
	symtab++;

	for (i = 1; i < n_symbols; i++, symtab++) {
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
		else if (symtab->st_shndx == SHN_UNDEF && ELF64_ST_BIND(symtab->st_info) == STB_GLOBAL) {
			/* Seek undefined symbols from this REL in previous RELs */
			const char *name = elf_strptr(elf, details->ed_strtab_idx, symtab->st_name);
			const Elf64_Sym *prev_symtab = seek_prev_symbol((Elf *)elf64_getehdr(elf)->e_entry, name);

			if (prev_symtab == NULL) {
				fprintf(stderr, "error: undefined symbol '%s'\n", name);
				return -1;
			}

			symtab->st_value = prev_symtab->st_value;
		}
	}

	return 0;
}

enum {
	REL_CAPS_RW_SECTIONS = 1U, /* REL has RW SHT_PROGBITS sections */
	REL_CAPS_RO_SECTIONS = 2U  /* REL has RO SHT_PROGBITS sections */
};

/* Load ELF file section and symbol tables; relocate sections and symbols based on loading/mapping VA
*/
static int
	_load_elf_file_details(
		Elf *elf,
		ElfDetails *ret_details,
		unsigned *ret_caps,
		void *rawdata_rw,
		void *rawdata_ro)
{
	ElfDetails details;
	char *ehdr_ident;
	Elf64_Ehdr *ehdr64;
	Elf64_Shdr *shdr64;
	Elf_Scn *scn;
	const char *scn_name;
	Elf64_Shdr **section_list;
	size_t scn_idx, n_elf_scns;
	Elf64_Section shstrtab_idx = 0;
	Elf64_Section symtab_idx = 0;
	Elf64_Section strtab_idx = 0;
	Elf64_Section rodata_idx = 0;
	Elf64_Section data_idx = 0;
	Elf64_Section bss_idx = 0;
	Elf64_Section text_idx = 0;
	Elf64_Section rel_text_idx = 0;
	Elf64_Section rela_text_idx = 0;
	unsigned caps = 0;
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

	details = (ElfDetails) calloc(sizeof(*details), 1);
	if (details == NULL) {
		return -2; /* out of memory */
	}

	/* Initialize the new object */
	details->ed_elf          = elf;
	details->ed_n_elf_scns   = n_elf_scns;

	/* Allocate list object (array of Elf64_Shdr*) for the ELF sections */
	section_list = (Elf64_Shdr**) calloc(sizeof(*section_list), n_elf_scns);
	if (section_list == NULL) {
		return -2; /* out of memory */
	}
	details->ed_shdrs = section_list;

	/* Enumerate the ELF sections and compute their mapping addresses */
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
			if (text_idx != 0) {
				return -1;
			}
			details->ed_text_idx = text_idx = scn_idx;
		}
		else if (strcmp(scn_name,".rodata") == 0) {
			if (shdr64->sh_type != SHT_PROGBITS) {
				return -1;
			}
			/* Validate there is only one .rodata section */
			if (rodata_idx != 0) {
				return -1;
			}
			rodata_idx = scn_idx;
		}
		else if (strcmp(scn_name,".data") == 0) {
			if (shdr64->sh_type != SHT_PROGBITS) {
				return -1;
			}
			/* Validate there is only one .data section */
			if (data_idx != 0) {
				return -1;
			}
			data_idx = scn_idx;
		}
		else if (strcmp(scn_name, ".bss") == 0) {
			if (shdr64->sh_type != SHT_NOBITS) {
				return -1;
			}
			/* Validate there is only one .bss section */
			if (bss_idx != 0) {
				return -1;
			}
			bss_idx = scn_idx;
		}
		else if (strcmp(scn_name,".rel.text") == 0) {
			if (shdr64->sh_type != SHT_REL) {
				return -1;
			}
			/* Validate there is only one .rel.text section */
			if (rel_text_idx != 0) {
				return -1;
			}
			details->ed_rel_text_idx = rel_text_idx = scn_idx;
		}
		else if (strcmp(scn_name,".rela.text") == 0) {
			if (shdr64->sh_type != SHT_RELA) {
				return -1;
			}
			/* Validate there is only one .rela.text section */
			if (rela_text_idx != 0) {
				return -1;
			}
			details->ed_rela_text_idx = rela_text_idx = scn_idx;
		}
		else if (strcmp(scn_name,".symtab") == 0) {
			if (shdr64->sh_type != SHT_SYMTAB) {
				return -1;
			}
			/* Validate there is only one .symtab section */
			if (symtab_idx != 0) {
				return -1;
			}
			details->ed_symtab_idx = symtab_idx = scn_idx;
		}
		else if (strcmp(scn_name,".strtab") == 0) {
			if (shdr64->sh_type != SHT_STRTAB) {
				return -1;
			}
			/* Validate there is only one .strtab section */
			if (strtab_idx != 0) {
				return -1;
			}
			details->ed_strtab_idx = strtab_idx = scn_idx;
		}
		else if (strcmp(scn_name,".shstrtab") == 0) {
			if (shdr64->sh_type != SHT_STRTAB) {
				return -1;
			}
			/* Validate there is only one .shstrtab section */
			if (shstrtab_idx != scn_idx) {
				return -1;
			}
		}

		/* Resolve the VA of non-empty ELF section data */
		if (shdr64->sh_size != 0) {
			/* Section .bss does not have file backing */
			if (scn_idx == bss_idx) {
				const int prot_rw = PROT_READ | PROT_WRITE;
				const int flag_priv_anon = MAP_PRIVATE | MAP_ANONYMOUS | MAP_POPULATE;

				void *p = mmap(NULL, shdr64->sh_size, prot_rw, flag_priv_anon, -1, 0);

				if (p == MAP_FAILED) {
					fprintf(stderr, "error: cannot mmap bss\n");
					return -1;
				}

				shdr64->sh_addr = (Elf64_Addr)p;
			} else {
				if (scn_idx == text_idx || scn_idx == rodata_idx) {
					shdr64->sh_addr = (Elf64_Addr)(rawdata_ro + shdr64->sh_offset);
					caps |= REL_CAPS_RO_SECTIONS;
				} else {
					shdr64->sh_addr = (Elf64_Addr)(rawdata_rw + shdr64->sh_offset);
					if (shdr64->sh_type == SHT_PROGBITS) {
						caps |= REL_CAPS_RW_SECTIONS;
					}
				}
			}
		}
	}

	/* Ensure the file has all required sections */
	if (text_idx     == 0 ||
	    symtab_idx   == 0 ||
	    strtab_idx   == 0 ||
	    shstrtab_idx == 0) {
		return -1;
	}

	/* Process the symbol table from the ELF .symtab section */
	rc = _load_elf64_symbol_table(details);
	if (rc) return rc;

	/* Return the ElfDetails object to the caller */
	*ret_details = details;
	*ret_caps = caps;

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

/* Load ELF file, relocate based on loading/mapping VA, and print symtab
*/
static int
	relocate_elf_load_cu(
		Elf *elf,
		void **start,
		unsigned *caps,
		void *rawdata_rw,
		void *rawdata_ro,
		int flag_quiet)
{
	ElfDetails details = NULL;
	Elf64_Sym *symtab;
	uint64 n_symbols, i;
	int rc;

	if (!elf || !start || !caps || !rawdata_rw || !rawdata_ro) {
		return -1;
	}

	/* Load ELF file section and symbol tables */
	rc = _load_elf_file_details(elf, &details, caps, rawdata_rw, rawdata_ro);
	if (rc)
		goto term;

	/* Print all symbols, except the first dummy */
	symtab = (Elf64_Sym*)(details->ed_shdrs[details->ed_symtab_idx]->sh_addr);
	symtab++;
	n_symbols = (details->ed_shdrs[details->ed_symtab_idx]->sh_size) / sizeof(*symtab);

	if (!flag_quiet) {
		printf("    symtab_value____ symtab_type__ symtab_bind___ symtab_section___ symtab_name__\n");
	}

	for (i = 1; i < n_symbols; i++, symtab++) {
		const char *name = "_____________";

		/* Resolve the symbol name */
		if (symtab->st_name == 0) {
			if (ELF64_ST_TYPE(symtab->st_info) == STT_SECTION) {
				name = str_from_st_shndx(symtab->st_shndx, elf);
			}
		}
		else {
			name = elf_strptr(details->ed_elf, details->ed_strtab_idx, symtab->st_name);

			if (symtab->st_shndx == details->ed_text_idx && strcmp(name, "_start") == 0) {
				if (*start != NULL) {
					fprintf(stderr, "error: multiple _start\n");
					rc = -1;
					goto term;
				}
				*start = (void *)symtab->st_value;
			}
		}

		if (!flag_quiet) {
			printf("%2lu: %016lx %-13s %-14s %-17s %s\n",
				i,
				symtab->st_value,
				str_from_st_type(ELF64_ST_TYPE(symtab->st_info)),
				str_from_st_bind(ELF64_ST_BIND(symtab->st_info)),
				str_from_st_shndx(symtab->st_shndx, elf),
				name);
		}
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

	/* Repurpose Elf64_Ehdr.e_shstrndx as e_strtabndx */
	elf64_getehdr(elf)->e_shstrndx = details->ed_strtab_idx;

term:
	/* Remove temporary tables */
	_load_elf_term(details);

	return rc;
}

static void print_usage(char **argv)
{
	printf("usage: %s <elf_rel_file> [<elf_rel_file>] ..\n"
#if __linux__ != 0
	       "\t--filter <string> : filter file mappings containing the specified string\n"
#endif
	       "\t--quiet           : suppress all reports\n"
	       "\t--break           : raise SIGTRAP before passing control to REL\n"
	       "\t--help            : this message\n", argv[0]);
}

struct rel_info_t {
	char *name;   /* File name */
	void *vma_rw; /* Ptr to RW VMA */
	size_t size;  /* File size */
};

int main(int argc, char **argv)
{
	size_t areas_capacity = 0, objs_capacity = 0;
#if __linux__ != 0
	struct char_ptr_arr_t areas = { .count = 0, .arr = NULL };
#endif
	struct {
		size_t count;
		struct rel_info_t *arr;
	} objs = { .count = 0, .arr = NULL };
	Elf *prev_elf = NULL;
	void *start = NULL;
	int flag_quiet = 0;
	int flag_break = 0;
	size_t i;

	if (argc == 1) {
		print_usage(argv);
		return -1;
	}

	for (i = 1; i < argc; ++i) {
		if (!strcmp(argv[i], "--help")) {
			print_usage(argv);
			return 0;
		}

		if (!strcmp(argv[i], "--quiet")) {
			flag_quiet = 1;
			continue;
		}

		if (!strcmp(argv[i], "--break")) {
			flag_break = 1;
			continue;
		}

#if __linux__ != 0
		if (!strcmp(argv[i], "--filter")) {
			if (++i == argc) {
				print_usage(argv);
				return -1;
			}
			if (areas.count == areas_capacity) {
				areas.arr = (char **)realloc(areas.arr, sizeof(*areas.arr) * (areas_capacity = (areas_capacity + 1) * 2));
			}
			areas.arr[areas.count++] = argv[i];
			continue;
		}

#endif
		/* Unprefixed arg must be a file */
		if (objs.count == objs_capacity) {
			objs.arr = (struct rel_info_t *)realloc(objs.arr, sizeof(*objs.arr) * (objs_capacity = (objs_capacity + 1) * 2));
		}

		objs.arr[objs.count++].name = argv[i];
	}

	if (objs.count == 0) {
		print_usage(argv);
		return -1;
	}

	elf_version(EV_CURRENT);

	for (i = 0; i < objs.count; ++i) {
		struct stat sb;
		void *p, *q;
		Elf *elf;
		Elf64_Ehdr *ehdr64;
		unsigned caps;

		const int fd = open(objs.arr[i].name, O_RDONLY);

		if (fd < 0) {
			fprintf(stderr, "error: cannot open file\n");
			return -1;
		}

		if (fstat(fd, &sb) < 0) {
			close(fd);
			fprintf(stderr, "error: cannot stat file\n");
			return -1;
		}

		/* Get two distinct mappings to the same file -- first to be used for
		   writable sections, second -- for the read-only/exec sections; use
		   the first mapping for libelf purposes */
		p = mmap(NULL, sb.st_size, PROT_READ | PROT_WRITE, MAP_PRIVATE, fd, 0);
		q = mmap(NULL, sb.st_size, PROT_READ | PROT_WRITE, MAP_PRIVATE, fd, 0);
		close(fd);

		if (p == MAP_FAILED || q == MAP_FAILED) {
			fprintf(stderr, "error: cannot mmap file\n");
			return -1;
		}

		elf = elf_memory(p, sb.st_size);

		if (elf == NULL) {
			fprintf(stderr, "error: cannot elf_memory\n");
			return -1;
		}

		/* Elf64_Ehdr.e_entry is nil in a REL -- repurpose it to
		   form a linked list of all RELs loaded to this point */
		if ((ehdr64 = elf64_getehdr(elf)) == NULL) {
			return -1;
		}

		ehdr64->e_entry = (Elf64_Addr)prev_elf;
		prev_elf = elf;

		if (relocate_elf_load_cu(elf, &start, &caps, p, q, flag_quiet)) {
			fprintf(stderr, "error: cannot relocate_elf_load_cu\n");
			return -1;
		}

		/* Finalize RO mapping depending on presence of RO SHT_PROGBITS */
		if (caps & REL_CAPS_RO_SECTIONS) {
			if (mprotect(q, sb.st_size, PROT_READ | PROT_EXEC)) {
				fprintf(stderr, "error: cannot mprotect\n");
				return -1;
			}
		} else {
			if (munmap(q, sb.st_size)) {
				fprintf(stderr, "error: cannot munmap\n");
				return -1;
			}
		}

		/* Defer unmapping of RW mapping depending on presence of RW SHT_PROGBITS */
		if (caps & REL_CAPS_RW_SECTIONS) {
			objs.arr[i].vma_rw = NULL;
		} else {
			objs.arr[i].vma_rw = p;
			objs.arr[i].size = sb.st_size;
		}
	}

	/* All SHN_UNDEFs have been processed -- unmap unneeded RW mappings */
	for (i = 0; i < objs.count; ++i) {
		if (objs.arr[i].vma_rw != NULL) {
			if (munmap(objs.arr[i].vma_rw, objs.arr[i].size)) {
				fprintf(stderr, "error: cannot munmap\n");
				return -1;
			}
		}
	}

#if __linux__ != 0
	if (areas.count && areas.arr != NULL)
		vma_process(&areas, flag_quiet);

	/* Don't try to free anything from heap here as there may not be a heap */

#endif
	if (start != NULL) {
		if (flag_break) {
			__asm__ __volatile__ ("brk 42");
		}
		((void (*)(void))start)();
	}

	return 0;
}
