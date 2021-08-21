/*
 * Hex-to-ascii routines for various bitnesses
 *
 * Copyright (C) 2019-2021 Martin Krastev <blu.dark@gmail.com>
 */

	.arch armv8-a

	.global string_x8
	.global string_x16
	.global string_x16_1
	.global string_x16_2
	.global string_x32
	.global string_x64
	.global string_x64_1
	.text

// convert x8 to string
// x0: output buffer
// w1: value to convert, bits [7:0]
// clobbers: x2, x3, x4, x5
	.align 4
string_x8:
	mov     w4, '0' - 0x0
	mov     w5, 'a' - 0xa
	ubfx    w2, w1,  4, 4
	and     w1, w1, 15
	cmp     w2, 0xa
	csel    w3, w4, w5, LO
	cmp     w1, 0xa
	csel    w4, w4, w5, LO
	add     w2, w2, w3
	strb    w2, [x0, 0]
	add     w1, w1, w4
	strb    w1, [x0, 1]
	ret

// convert x16 to string
// x0: output buffer
// w1: value to convert, bits [15:0]
// clobbers: x2, x3, x4, x5, x6, x7, x8, x9
	.align 4
string_x16:
	mov     w5, '0' - 0x0
	mov     w6, 'a' - 0xa
	ubfx    w4, w1, 12, 4
	ubfx    w3, w1,  8, 4
	ubfx    w2, w1,  4, 4
	and     w1, w1, 15
	cmp     w4, 0xa
	csel    w7, w5, w6, LO
	cmp     w3, 0xa
	csel    w8, w5, w6, LO
	cmp     w2, 0xa
	csel    w9, w5, w6, LO
	cmp     w1, 0xa
	csel    w5, w5, w6, LO
	add     w4, w4, w7
	strb    w4, [x0, 0]
	add     w3, w3, w8
	strb    w3, [x0, 1]
	add     w2, w2, w9
	strb    w2, [x0, 2]
	add     w1, w1, w5
	strb    w1, [x0, 3]
	ret

// convert x16 to string
// x0: output buffer
// w1: value to convert, bits [15:0]
// clobbers: x2, x3, x4, x5, x6, x7
	.align 4
string_x16_1:
	mov     w3, '0' - 0x0
	mov     w4, 'a' - 0xa
	mov     w5, 0xa
	mov     w6, 0x0f0f
	lsr     w2, w1, 4
	and     w1, w1, w6 // even-index nibbles
	and     w2, w2, w6 // odd-index nibbles
	cmp     w5, w1, UXTB
	csel    w6, w3, w4, HI
	cmp     w5, w2, UXTB
	csel    w7, w3, w4, HI
	add     w1, w1, w6
	add     w2, w2, w7
	strb    w1, [x0, 3]
	strb    w2, [x0, 2]
	lsr     w1, w1, 8
	lsr     w2, w2, 8
	cmp     w5, w1, UXTB
	csel    w6, w3, w4, HI
	cmp     w5, w2, UXTB
	csel    w7, w3, w4, HI
	add     w1, w1, w6
	add     w2, w2, w7
	strb    w1, [x0, 1]
	strb    w2, [x0, 0]
	ret

// convert x16 to string
// x0: output buffer
// w1: value to convert, bits [15:0]
// clobbers: v0, v1, v3, v4, v5, v6
	.align 4
string_x16_2:
	rev16   w1, w1 // we write the result via a single store op, so correct for digit order, part one: swap octet order
	movi    v3.8b, '0' - 0x0
	movi    v4.8b, 'a' - 0xa
	movi    v5.8b, 0xa
	movi    v6.8b, 0xf
	fmov    s0, w1
	ushr    v1.8b, v0.8b, 4
	and     v0.8b, v0.8b, v6.8b
	zip1    v0.8b, v1.8b, v0.8b // we write the result via a single store op, so correct for digit order, part two: swap nibble order
	cmhi    v1.8b, v5.8b, v0.8b
	bsl     v1.8b, v3.8b, v4.8b
	add     v0.8b, v0.8b, v1.8b
	str     s0, [x0]
	ret

// convert x32 to string
// x0: output buffer
// w1: value to convert, bits [31:0]
// clobbers: v0, v1, v3, v4, v5, v6
	.align 4
string_x32:
	rev     w1, w1 // we write the result via a single store op, so correct for digit order, part one: swap octet order
	movi    v3.8b, '0' - 0x0
	movi    v4.8b, 'a' - 0xa
	movi    v5.8b, 0xa
	movi    v6.8b, 0xf
	fmov    s0, w1
	ushr    v1.8b, v0.8b, 4
	and     v0.8b, v0.8b, v6.8b
	zip1    v0.8b, v1.8b, v0.8b // we write the result via a single store op, so correct for digit order, part two: swap nibble order
	cmhi    v1.8b, v5.8b, v0.8b
	bsl     v1.8b, v3.8b, v4.8b
	add     v0.8b, v0.8b, v1.8b
	str     d0, [x0]
	ret

// convert x64 to string
// x0: output buffer
// x1: value to convert, bits [63:0]
// clobbers: v0, v1, v3, v4, v5, v6
	.align 4
string_x64:
	rev     x1, x1 // we write the result via a single store op, so correct for digit order, part one: swap octet order
	movi    v3.16b, '0' - 0x0
	movi    v4.16b, 'a' - 0xa
	movi    v5.16b, 0xa
	movi    v6.16b, 0xf
	fmov    d0, x1
	ushr    v1.8b, v0.8b, 4
	and     v0.8b, v0.8b, v6.8b
	zip1    v0.16b, v1.16b, v0.16b // we write the result via a single store op, so correct for digit order, part two: swap nibble order
	cmhi    v1.16b, v5.16b, v0.16b
	bsl     v1.16b, v3.16b, v4.16b
	add     v0.16b, v0.16b, v1.16b
	str     q0, [x0]
	ret

// convert x64 to string
// x0: output buffer
// x1: value to convert, bits [63:0]
// clobbers: v0, v1, v3, v4, v5, v6
	.align 4
string_x64_1:
	rev     x1, x1 // we write the result via a single store op, so correct for digit order, part one: swap octet order
	movi    v6.16b, 0xf
	fmov    d0, x1
	movi    v3.16b, '0' - 0x0
	movi    v4.16b, 'a' - 0xa
	movi    v5.16b, 0xa
	ushr    v1.8b, v0.8b, 4
	and     v0.8b, v0.8b, v6.8b
	zip1    v0.16b, v1.16b, v0.16b // we write the result via a single store op, so correct for digit order, part two: swap nibble order
	cmhi    v1.16b, v5.16b, v0.16b
	bsl     v1.16b, v3.16b, v4.16b
	add     v0.16b, v0.16b, v1.16b
	str     q0, [x0]
	ret
