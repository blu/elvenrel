	.arch armv8-a

	.global advance_timeval_us

	.include "macro.inc"

	.text

.if 0
// advance timeval by a non-negative dtime in us
//
// an overengineered version, as if timeval::tv_usec
// could overflow at addition with dtime (it can't)
//
// x0: timeval ptr
// w1: dtime us; must be less than 1e6
// clobbers: x2, x3, x4
	.align 4
advance_timeval_us:
	movl	w2, 1000000
	sub	w2, w2, w1
	ldp	x3, x4, [x0]
	subs	w2, w4, w2
	blo	.Lupdate_only_us
	add	x3, x3, 1
	stp	x3, x2, [x0]
	ret
.Lupdate_only_us:
	add	w4, w4, w1
	str	x4, [x0, 8]
	ret

.else
// advance timeval by a non-negative dtime in us
// x0: timeval ptr
// w1: dtime us; must be less than 1e6
// clobbers: x2, x3, x4
	.align 4
advance_timeval_us:
	movl	w2, 1000000
	ldp	x3, x4, [x0]
	add	w4, w4, w1
	cmp	w4, w2
	blo	.Lupdate_timeval
	add	x3, x3, 1
	sub	w4, w4, w2
.Lupdate_timeval:
	stp	x3, x4, [x0]
	ret

.endif
