	.global _start

	.equ SYS_write, 4
	.equ SYS_exit, 1
	.equ STDOUT_FILENO, 1

	.text
_start:
	mov	x16, SYS_write
	mov	x2, len
	adr	x1, buf
	mov	x0, STDOUT_FILENO
	svc	0

	mov	x16, SYS_exit
	mov	x0, xzr
	svc	0

buf:
	.ascii	"hello from ET_REL\n"
len = . - buf
