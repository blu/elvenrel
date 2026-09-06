	.arch armv8-a

	.global _start

	.equ SYS_write, 64
	.equ SYS_exit, 93
	.equ STDOUT_FILENO, 1
	.equ FPCR_AH, 1 << 1

	.text

	.align	4
// x0: bitmask
// clobbers: x1
fpcr_set:
	mrs	x1, fpcr
	orr	x1, x1, x0
	msr	fpcr, x1
	ret

	.align	4
// x0: bitmask
// clobbers: x1
fpcr_reset:
	mrs	x1, fpcr
	bic	x1, x1, x0
	msr	fpcr, x1
	ret

_start:
	movi	v0.4s, 0
	fneg	s1, s0
	mov	x0, FPCR_AH

	bl	fpcr_reset
	fdiv	s7, s0, s1

	bl	fpcr_set
	fdiv	s8, s0, s1

	ldr	x3, =msg

	fmov	w1, s7
	add	x0, x3, 15
	bl	string_x32

	fmov	w1, s8
	add	x0, x3, 15 + 9 + 13
	bl	string_x32

	mov	x8, SYS_write
	mov	x2, msg_len
	mov	x1, x3
	mov	x0, STDOUT_FILENO
	svc	0

	mov	x8, SYS_exit
	mov	x0, xzr
	svc	0

	.section .data
msg:
	.ascii	"FPCR_AH clear: "
	.ascii	"########\n"
	.ascii	"FPCR_AH set: "
	.ascii	"########\n"
msg_len = . - msg
