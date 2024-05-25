	.global _start

	.equ SYS_write, 64
	.equ SYS_exit, 93
	.equ STDOUT_FILENO, 1

	.include "macro.inc"

	.text
_start:
	mov	x8, SYS_write
	mov	x2, len
	adrf	x1, buf
	mov	x0, STDOUT_FILENO
	svc	0

	adrp	x1, code
	ldr	x0, [x1, :lo12:code]
	add	x0, x0, 1
	str	x0, [x1, :lo12:code]

	mov	x8, SYS_exit
	svc	0

	.section .bss
code:
	.dword	0

	.section .rodata
buf:
	.ascii	"hello from ET_REL\n"
len = . - buf
