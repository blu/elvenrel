// DISPCLAIMER: the source code in this translation unit originates from 3rd-
// party software and is not subject to the repo license agreement; such code
// is included solely for research purposes and is not otherwise used by the
// rest of the project in any capacity other than testing.

	.arch armv8-a

	.global memset_woa
	.text

// WindowsOnArm RTC_memset -- rountine reverse-engineered from WoA CRT
// x0: buffer
// x1: value
// x2: length
// clobbers: x9
	.align 4
memset_woa:
	ands	x9, x2, -16
	and	x2, x2, 15
	beq	.Lwoa_tail0
	add	x9, x9, x0
.Lwoa_loop16:
	stp	x1, x1, [x0], 16
	cmp	x0, x9
	blo	.Lwoa_loop16
	cbnz	x2, .Lwoa_tail0
.Lwoa_done:
	ret
.Lwoa_tail0:
	cmp	x2, 8
	blo	.Lwoa_tail1
	str	x1, [x0], 8
	sub	x2, x2, 8
.Lwoa_tail1:
	cbz	x2, .Lwoa_done
	add	x2, x2, x0
.Lwoa_loop1:
	strb	w1, [x0], 1
	cmp	x0, x2
	blo	.Lwoa_loop1
	ret
