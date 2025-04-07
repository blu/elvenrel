	.global _start

	.equ SYS_write, 64
	.equ SYS_exit, 93
	.equ STDOUT_FILENO, 1

	.equ sample_bitset_num_u32, 100 * 1000 * 1000

	.include "macro.inc"

	.text
_start:
	/* alloca local room */
	sub	sp, sp, 32

	mrs	x0, cntfrq_el0
	mrs	x1, cntvct_el0
	stp	x0, x1, [sp, 16]

	/* block tested { */
	adrf	x0, sample_bitset_u32
	movl	x1, sample_bitset_num_u32
	ands	x2, x1, -16
	add	x3, x0, 32
	movi	v0.2d, 0
	movi	v1.2d, 0
	movi	v2.2d, 0
	movi	v3.2d, 0
	b.eq	.Lbulk8
.Lbulk16:
	ldp	q4, q5, [x3, -32]
	ldp	q6, q7, [x3], 64
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
	subs	x2, x2, 16
	b.ne	.Lbulk16
.Lbulk8:
	sub	x3, x3, 32
	tbz	x1, 3, .Lbulk4
	ldp	q4, q5, [x3], 32
	cnt	v4.16b, v4.16b
	cnt	v5.16b, v5.16b

	uaddlp	v4.8h, v4.16b
	uaddlp	v5.8h, v5.16b

	uadalp	v0.4s, v4.8h
	uadalp	v1.4s, v5.8h
.Lbulk4:
	tbz	x1, 2, .Lbulk2
	ldr	q6, [x3], 16
	cnt	v6.16b, v6.16b

	uaddlp	v6.8h, v6.16b
	uadalp	v2.4s, v6.8h
.Lbulk2:
	tbz	x1, 1, .Lunit
	ldr	d7, [x3], 8
	cnt	v7.8b, v7.8b

	uaddlp	v7.4h, v7.8b
	uadalp	v3.4s, v7.8h /* implicit widening to match acc width */
.Lunit:
	tbz	x1, 0, .Lfinal
	ldr	s4, [x3]
	cnt	v4.8b, v4.8b

	uaddlp	v4.4h, v4.8b
	uadalp	v0.4s, v4.8h /* implicit widening to match acc width */
.Lfinal:
	add	v0.4s, v1.4s, v0.4s
	add	v1.4s, v3.4s, v2.4s
	add	v0.4s, v1.4s, v0.4s
	addv	s0, v0.4s
	fmov	w2, s0
	/* } block tested */

	/* fill in elapsed time message */
	mrs	x0, cntvct_el0
	ldr	x1, [sp, 24]
	sub	x0, x0, x1
	stp	x2, x0, [sp]

	ldr	x2, =string_x64
	ldr	x1, [sp, 16]
	adrf	x0, msg01_arg0
	blr	x2 /* string_x64 far call */

	ldr	x1, [sp, 8]
	adrf	x0, msg01_arg1
	blr	x2 /* string_x64 far call */

	/* fill in result message */
	ldr	x2, =string_x32
	ldr	w1, [sp]
	adrf	x0, msg02_arg0
	blr	x2 /* string_x32 far call */

	/* dealloc local room */
	add	sp, sp, 32

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
