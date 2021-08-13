	.global _start

	.equ SYS_write, 64
	.equ SYS_exit, 93
	.equ STDOUT_FILENO, 1

	.text
_start:
	mov	x8, SYS_write
	mov	x2, len
	adr	x1, buf
	ldr w3, =0x4c45525f
	str w3, [x1, 13]
	mov	x0, STDOUT_FILENO
	svc	0

	mov	x8, SYS_exit
	mov	x0, xzr
	svc	0

	.section .data
buf:
	.ascii	"hello from ET....\n"
len = . - buf
