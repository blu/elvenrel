	.arch armv8-a

	.global memset32
	.global memset
	.text

// memset a buffer of 32B alignment to a given value
// x0: buffer
// x1: buffer + length
// v0: byte value splatted to ASIMD width
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

// memset a buffer to a given value
// x0: buffer
// x1: length
// v0: byte value splatted to ASIMD width
// clobbers: x2, x3
	.align 4
memset:
	ands	x3, x1, -32
	and	x2, x1, -16
	add	x3, x3, x0
	add	x2, x2, x0
	add	x1, x1, x0
	beq	.LLtail0
.LLloop32:
	stp	q0, q0, [x0], 32
	cmp	x0, x3
	bne	.LLloop32
.LLtail0:
	cmp	x0, x2
	beq	.LLtail1
	str	q0, [x0], 16
.LLtail1:
	cmp	x0, x1
	beq	.LLdone
	str	b0, [x0], 1
	b	.LLtail1
.LLdone:
	ret
