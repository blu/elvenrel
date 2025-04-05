	.global _start

	.equ SYS_write, 64
	.equ SYS_exit, 93
	.equ STDOUT_FILENO, 1

	.equ sample_bitset_num_u32, 128 * 16
	.include "macro.inc"

	.text
_start:
	/* alloca local room */
	sub	sp, sp, 32

	mrs	x0, cntfrq_el0
	mrs	x1, cntvct_el0
	stp	x0, x1, [sp, 16]

	/* block tested { */
	movl	x1, sample_bitset_num_u32
	adrf	x0, sample_bitset_u32
	and	x7, x1, 0xfffffff0
	add	x8, x0, 32
	movi	v0.2d, 0
	movi	v1.2d, 0
	movi	v2.2d, 0
	movi	v3.2d, 0
.Lbulk:
	ldp	q4, q5, [x8, -32]
	ldp	q6, q7, [x8], 64
	cnt	v4.16b, v4.16b
	cnt	v5.16b, v5.16b
	cnt	v6.16b, v6.16b
	cnt	v7.16b, v7.16b

	uaddlp	v4.8h, v4.16b
	uaddlp	v5.8h, v5.16b
	uaddlp	v6.8h, v6.16b
	uaddlp	v7.8h, v7.16b

	uadalp	v0.4s, v4.8h
	uadalp	v1.4s, v5.8h
	uadalp	v2.4s, v6.8h
	uadalp	v3.4s, v7.8h
	subs	x7, x7, 16
	b.ne	.Lbulk

	add	v0.4s, v1.4s, v0.4s
	add	v1.4s, v3.4s, v2.4s
	add	v0.4s, v1.4s, v0.4s
	addv	s0, v0.4s
	fmov	w8, s0
	/* } block tested */

	/* fill in elapsed time message */
	mrs	x0, cntvct_el0
	ldr	x1, [sp, 24]
	sub	x0, x0, x1
	stp	x8, x0, [sp]

	ldr	x1, [sp, 16]
	adrf	x0, msg01_arg0
	bl	string_x64

	ldr	x1, [sp, 8]
	adrf	x0, msg01_arg1
	bl	string_x64

	/* fill in result message */
	ldr	w1, [sp]
	adrf	x0, msg02_arg0
	bl	string_x32

	/* dealloc local room */
	add	sp, sp, 32

/*
	mov	x8, SYS_write
	mov	x2, msg02_len
	adrf	x1, msg02
	mov	x0, STDOUT_FILENO
	svc	0
*/
	mov	x8, SYS_write
	mov	x2, msg01_len + msg02_len
	adrf	x1, msg01
	mov	x0, STDOUT_FILENO
	svc	0

	mov	x8, SYS_exit
	mov	x0, xzr
	svc	0

	.section .data
msg01:
	.ascii	"elapsed_frq: "
msg01_arg0:
	.ascii	"0123456789abcdef\n"
	.ascii	"elapsed_vct: "
msg01_arg1:
	.ascii	"0123456789abcdef\n"
msg01_len = . - msg01

msg02:
	.ascii	"count: "
msg02_arg0:
	.ascii "01234567\n"
msg02_len = . - msg02

	.section .rodata

	.align 12
sample_bitset_u32:
	.rept	sample_bitset_num_u32
	.long	0x01020408
	.endr
