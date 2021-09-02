	.global _start

	.equ SYS_write, 64
	.equ SYS_exit, 93
	.equ STDOUT_FILENO, 1

	.text
_start:
	mov	x8, SYS_write
	mov	x2, len
	adr	x1, buf
	mov	x0, STDOUT_FILENO
	svc	0

	adrp	x1, code
	ldr	x2, [x1, :lo12:code]
	add	x2, x2, 1
	str	x2, [x1, :lo12:code]

	mov	x8, SYS_exit
	ldr	x0, [x1, :lo12:code]
	svc	0

	.section .bss
code:
	.dword	0

	.section .rodata
buf:
	.ascii	"hello from ET_REL\n"
len = . - buf
