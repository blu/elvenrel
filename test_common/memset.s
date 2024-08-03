	.arch armv8-a

	.global memset32
	.global memset
	.text

// memset a buffer of 32B alignment to a given value
// x0: buffer
// x1: buffer + length
// v0: byte value replicated to Q-form
// clobbers: x2, x3
	.align 4
memset32:
	ands	x3, x1, -32
	and	x2, x1, -16
	beq	.Ltail0
.Lloop32:
	stp	q0, q0, [x0], 32
	cmp	x0, x3
	bne	.Lloop32
.Ltail0:
	cmp	x0, x2
	beq	.Ltail1
	str	q0, [x0], 16
.Ltail1:
	cmp	x0, x1
	beq	.Ldone
	str	b0, [x0], 1
	b	.Ltail1
.Ldone:
	ret

// memset a buffer to a given value; does unaligned writes
// x0: buffer
// x1: length
// v0: byte value replicated to Q-form
// clobbers: x2
	.align 4
memset:
	lsr	x2, x1, 5
	cbz	x2, .LLtail0
.LLloop:
	stp	q0, q0, [x0], 32
	subs	x2, x2, 1
	bne	.LLloop
.LLtail0:
	tst	x1, 16
	beq	.LLtail1
	str	q0, [x0], 16
.LLtail1:
	tst	x1, 8
	beq	.LLtail2
	str	d0, [x0], 8
.LLtail2:
	tst	x1, 4
	beq	.LLtail3
	str	s0, [x0], 4
.LLtail3:
	tst	x1, 2
	beq	.LLtail4
	str	h0, [x0], 2
.LLtail4:
	tst	x1, 1
	beq	.LLdone
	str	b0, [x0]
.LLdone:
	ret
