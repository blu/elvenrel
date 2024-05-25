	.global _start

	.equ SYS_write, 4
	.equ SYS_exit, 1
	.equ STDOUT_FILENO, 1

	.include "macro.inc"

	.text
_start:
	mov	x16, SYS_write
	mov	x2, len
	adrf	x1, buf
	mov	x0, STDOUT_FILENO
	svc	0

	mov	x16, SYS_exit
	mov	x0, xzr
	svc	0

	.section .rodata
buf:
	.ascii	"hello from ET_REL\n"
len = . - buf
