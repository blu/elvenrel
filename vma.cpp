/*
 * Parsing of /proc/self/maps and optional disposing or sting-matched VMAs
 *
 * Copyright (C) 2021 Martin Krastev <blu.dark@gmail.com>
 */

#if __aarch64__ == 0
#error wrong target architecture
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <assert.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>

#include "vma.h"

extern "C" {
	void string_x8(void*, uint8_t) asm ("string_x8");
	void string_x16(void*, uint16_t) asm ("string_x16");
	void string_x32(void*, uint32_t) asm ("string_x32");
	void string_x64(void*, uint64_t) asm ("string_x64");
	size_t strlen_linux(const char*) asm ("strlen_linux");
}

#define FILENO_STDIN  0
#define FILENO_STDOUT 1
#define FILENO_STDERR 2

#define SYS_mremap    0x19 //  25
#define SYS_write     0x40 //  64
#define SYS_exit      0x5d //  93
#define SYS_munmap    0xd7 // 215
#define SYS_mmap      0xde // 222

#define xxstr(s) #s
#define xstr(s) xxstr(s)

template < typename T, size_t N >
int8_t (& noneval_countof(const T (&)[N]))[N];

#define countof(x) sizeof(noneval_countof(x))

namespace sys {

static intptr_t mmap(
	void *addr, size_t length, int prot, int flags, int fd, off_t offset)
{
	register uint64_t x0 asm ("x0") = (uintptr_t)addr;
	register uint64_t x1 asm ("x1") = length;
	register uint64_t x2 asm ("x2") = prot;
	register uint64_t x3 asm ("x3") = flags;
	register uint64_t x4 asm ("x4") = fd;
	register uint64_t x5 asm ("x5") = offset;

	asm volatile (
		"mov	x8, " xstr(SYS_mmap) "\n\t"
		"svc	0"
		: "+r" (x0)
		: "r" (x1), "r" (x2), "r" (x3), "r" (x4), "r" (x5)
		: "x8", "memory");

	return x0;
}

static int munmap(void *addr, size_t length)
{
	register uint64_t x0 asm ("x0") = (uintptr_t)addr;
	register uint64_t x1 asm ("x1") = length;

	asm volatile (
		"mov	x8, " xstr(SYS_munmap) "\n\t"
		"svc	0"
		: "+r" (x0)
		: "r" (x1)
		: "x2", "x3", "x4", "x5", "x8", "memory");

	return x0;
}

static intptr_t mremap(
	void *addr, size_t old_length, size_t new_length, int flags, void *new_addr)
{
	register uint64_t x0 asm ("x0") = (uintptr_t)addr;
	register uint64_t x1 asm ("x1") = old_length;
	register uint64_t x2 asm ("x2") = new_length;
	register uint64_t x3 asm ("x3") = flags;
	register uint64_t x4 asm ("x4") = (uintptr_t)new_addr;

	asm volatile (
		"mov	x8, " xstr(SYS_mremap) "\n\t"
		"svc	0"
		: "+r" (x0)
		: "r" (x1), "r" (x2), "r" (x3), "r" (x4)
		: "x8", "memory");

	return x0;
}

static int64_t write(int fileno, const void *ptr, size_t len)
{
	register uint64_t x0 asm ("x0") = fileno;
	register uint64_t x1 asm ("x1") = (uintptr_t) ptr;
	register uint64_t x2 asm ("x2") = len;

	asm volatile (
		"mov	x8, " xstr(SYS_write) "\n\t"
		"svc	0"
		: "+r" (x0)
		: "r" (x1), "r" (x2)
		: "x3", "x4", "x5", "x8", "memory");

	return x0;
}

static void exit(int code)
{
	register uint64_t x0 asm ("x0") = code;

	asm volatile (
		"mov	x8, " xstr(SYS_exit) "\n\t"
		"svc	0"
		: : "r" (x0));
}

} // namespace sys

namespace alt {

static int64_t putc(int fileno, char c)
{
	return sys::write(fileno, &c, 1);
}

} // namespace alt

struct vma_t {
	uintptr_t start;
	uintptr_t end;

	size_t offset;
	uint16_t src; // start of source string in the pool

	static size_t str_image_offset; // offset of optional image path in string

	int8_t perm_read  : 1;
	int8_t perm_write : 1;
	int8_t perm_exec  : 1;
	int8_t perm_priv  : 1;
	int8_t cookie     : 1;

	int8_t major;
	int8_t minor;

	// parse a line from /proc/pid/maps into stuctured data
	bool parse(const char *str)
	{
		char flag[4];
		unsigned off;
		if (6 != sscanf(str, "%lx-%lx %4c %x %hhx:%hhx",
			&start,
			&end,
			flag,
			&off,
			&major,
			&minor)) {
			return false;
		}

		perm_read  = flag[0] == 'r' ? 1 : 0;
		perm_write = flag[1] == 'w' ? 1 : 0;
		perm_exec  = flag[2] == 'x' ? 1 : 0;
		perm_priv  = flag[3] == 'p' ? 1 : 0;
		offset = off;

		return true;
	}

	size_t str(char *const buffer, const size_t len) const
	{
		const size_t pos[] = { 0, 17, 34, 35, 36, 37, 39, 48, 51, 53 };

		if (pos[countof(pos) - 1] > len)
			return 0;

		size_t i = 0;
		string_x64(buffer + pos[i++], start);
		string_x64(buffer + pos[i++], end);
		buffer[pos[i++]] = perm_read  ? 'r' : '-';
		buffer[pos[i++]] = perm_write ? 'w' : '-';
		buffer[pos[i++]] = perm_exec  ? 'x' : '-';
		buffer[pos[i++]] = perm_priv  ? 'p' : '-';
		string_x32(buffer + pos[i++], offset);
		string_x8(buffer + pos[i++], major);
		string_x8(buffer + pos[i++], minor);

		return pos[i];
	}

	ssize_t print() const
	{
		char buffer[] = "################-################ #### ######## ##:##";
		const size_t len = str(buffer, countof(buffer));

		return sys::write(FILENO_STDOUT, buffer, len);
	}
};

size_t vma_t::str_image_offset = 64;

class vma_set_t {
	char *pool; // char pool; sequentially filled in string chunks
	size_t last; // start of last added string in the pool

	size_t index; // current-entry index
	size_t offset; // offset in current-entry string

	size_t depth; // entries capacity
	size_t capa; // pool capacity

	vma_t *vma; // entries array

	// fill in a chunk of a line, possibly terminated, to the pool; parse ready lines
	void fill(const char* const src, const size_t len, const bool eol)
	{
		const int flag_move = MREMAP_MAYMOVE;

		if (last + offset + len >= capa) {
			const size_t old_size = sizeof(*pool) * capa;
			capa += capa;
			const size_t new_size = sizeof(*pool) * capa;
			pool = (char *)sys::mremap(pool, old_size, new_size, flag_move, nullptr);

			if (pool == MAP_FAILED) {
				fprintf(stderr, "error: cannot mremap char pool\n");
				sys::exit(-1);
			}
		}

		if (index == depth) {
			const size_t old_size = sizeof(*vma) * depth;
			depth += depth;
			const size_t new_size = sizeof(*vma) * depth;
			vma = (vma_t *)sys::mremap(vma, old_size, new_size, flag_move, nullptr);

			if (vma == MAP_FAILED) {
				fprintf(stderr, "error: cannot mremap entries array\n");
				sys::exit(-1);
			}
		}

		char *const str = pool + last;
		memcpy(str + offset, src, len);
		offset += len;

		if (!eol)
			return;

		str[offset] = '\0';

		if (!vma[index].parse(str))
			fprintf(stderr, "error: failed to parse line %lu\n", index);

		assert((1UL << sizeof(vma_t::src) * 8) - 1 >= last);
		vma[index].src = last;

		last += offset + 1;
		index += 1;
		offset = 0;
	}

public:
	vma_set_t() : last(0), index(0), offset(0), depth(PAGE_SIZE / sizeof(*vma)), capa(PAGE_SIZE / sizeof(*pool))
	{
		const int prot_rw = PROT_READ | PROT_WRITE;
		const int flag_priv_anon = MAP_PRIVATE | MAP_ANONYMOUS | MAP_POPULATE;

		pool = (char *)sys::mmap(nullptr, sizeof(*pool) * capa, prot_rw, flag_priv_anon, -1, 0);

		if (pool == MAP_FAILED) {
			fprintf(stderr, "error: cannot mmap char pool\n");
			sys::exit(-1);
		}

		vma = (vma_t *)sys::mmap(nullptr, sizeof(*vma) * depth, prot_rw, flag_priv_anon, -1, 0);

		if (vma == MAP_FAILED) {
			fprintf(stderr, "error: cannot mmap entries array\n");
			sys::exit(-1);
		}
	}

	~vma_set_t()
	{
		sys::munmap((void *)vma, sizeof(*vma) * depth);
		sys::munmap((void *)pool, sizeof(*pool) * capa);
	}

	// current size of the container
	size_t size() const
	{
		return index;
	}

	// vma source string accessor
	const char* src(const size_t idx) const
	{
		assert(size() > idx);
		return pool + vma[idx].src;
	}

	// vma sparse string writer in user buffer; return span of chars written
	size_t str(const size_t idx, char *const buffer, const size_t len) const
	{
		assert(size() > idx);
		return vma[idx].str(buffer, len);
	}

	// vma printer; return number of chars printed
	ssize_t print(const size_t idx) const
	{
		assert(size() > idx);
		return vma[idx].print();
	}

	// update vma_t::str_image_offset from an estimate to correct value
	void update_str_image_offset()
	{
		for (size_t i = 0; i < size(); ++i) {
			const char *const str = src(i);

			// seek vma strings with images at the end
			for (size_t j = strlen(str); j > vma_t::str_image_offset; ) {
				const char c = str[--j];
				if (c == ' ' || c == '\t') {
					vma_t::str_image_offset = j;
					return;
				}
			}
		}
	}

	// filter VMAs according to a set of image needles -- a matching image results in setting vma's cookie flag
	void filter(const size_t filter_count, char **const filter)
	{
		for (size_t i = 0; i < size(); ++i) {
			vma[i].cookie = 0;

			for (size_t j = 0; j < filter_count; ++j) {
				const char *const str = src(i);

				if (strlen(str) > vma_t::str_image_offset && strstr(str + vma_t::str_image_offset, filter[j])) {
					vma[i].cookie = 1;
					break;
				}
			}
		}
	}

	// deserialize from /proc/pid/maps
	int read_from_proc();

	const vma_t& operator [](const size_t idx) const
	{
		assert(size() > idx);
		return vma[idx];
	}
};

// seek new-line in a string of specified length; return pos, -1 if no new-line
static ssize_t seek_eol(const char *const buffer, const size_t len)
{
	const char *seek = buffer;
	while (buffer + len != seek && *seek != '\n') ++seek;

	if (buffer + len == seek)
		return -1;

	return seek - buffer;
}

int vma_set_t::read_from_proc()
{
	char buffer[128];
	const int fd = open("/proc/self/maps", O_RDONLY);

	if (-1 == fd)
		return -1;

	// read /proc/pid/maps in uniform chunks
	ssize_t bytes;
	do {
		bytes = read(fd, buffer, countof(buffer));

		if (-1 == bytes) {
			fprintf(stderr, "error: reading file: %s\n", strerror(errno));
			close(fd);
			return -1;
		}

		// reached eof?
		if (0 == bytes)
			break;

		size_t eol = 0;
		do {
			const size_t eol_last = eol;
			const ssize_t eol_inc = seek_eol(buffer + eol, bytes - eol);

			if (-1 == eol_inc) {
				fill(buffer + eol, bytes - eol, false);
				break;
			}

			eol += eol_inc;
			fill(buffer + eol_last, eol - eol_last, true);
			eol += 1;
		}
		while (eol != bytes);
	}
	while (bytes == countof(buffer));

	close(fd);
	return 0;
}

void vma_process(struct char_ptr_arr_t *areas)
{
	assert(areas != nullptr);

	vma_set_t vma;
	vma.read_from_proc();
	vma.update_str_image_offset();
	vma.filter(areas->count, areas->arr);

	// libc-free zone from here

	alt::putc(FILENO_STDOUT, '\n');

	char buffer[] = "#### \033[38;5;14m ################-################ #### ######## ##:##";

	for (size_t i = 0; i < vma.size(); ++i) {

		// nuke filtered VMAs
		if (vma[i].cookie) {
			const uintptr_t start = vma[i].start;
			const uintptr_t end = vma[i].end;
			sys::munmap((void*)start, end - start);

			buffer[13] = '3';
		}
		else
			buffer[13] = i & 1 ? '4' : '5';

		string_x16(buffer, i);
		vma.str(i, buffer + 16, countof(buffer) - 16);
		sys::write(FILENO_STDOUT, buffer, countof(buffer) - 1);

		const char *const str = vma.src(i);
		const size_t len = strlen_linux(str);

		if (len > vma_t::str_image_offset)
			sys::write(FILENO_STDOUT, str + vma_t::str_image_offset, len - vma_t::str_image_offset);

		const char term[] = " \033[0m\n";
		sys::write(FILENO_STDOUT, term, countof(term) - 1);
	}

	alt::putc(FILENO_STDOUT, '\n');
}
