	.arch armv8-a

	.global memset32
	.text

// memset a buffer of preferred 32B alignment to a given value
// x0: buffer
// x1: buffer + length
// v0: byte value splatted to ASIMD width
// clobbers: x2, x3
	.align 4
memset32:
	ands	x3, x1, -32
	and	x2, x1, -16
	beq	.Lclear_fb_tail_0
.Lclear_fb:
	stp	q0, q0, [x0], 32
	cmp	x0, x3
	bne	.Lclear_fb
.Lclear_fb_tail_0:
	cmp	x0, x2
	beq	.Lclear_fb_tail_1
	str	q0, [x0], 16
.Lclear_fb_tail_1:
	cmp	x0, x1
	beq	.Lfb_done
	str	b0, [x0], 1
	b	.Lclear_fb_tail_1
.Lfb_done:
	ret
