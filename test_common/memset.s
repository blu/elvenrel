	.arch armv8-a

	.global memset
	.text

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
	tbz	x1, 4, .LLtail1
	str	q0, [x0], 16
.LLtail1:
	tbz	x1, 3, .LLtail2
	str	d0, [x0], 8
.LLtail2:
	tbz	x1, 2, .LLtail3
	str	s0, [x0], 4
.LLtail3:
	tbz	x1, 1, .LLtail4
	str	h0, [x0], 2
.LLtail4:
	tbz	x1, 0, .LLdone
	str	b0, [x0]
.LLdone:
	ret
