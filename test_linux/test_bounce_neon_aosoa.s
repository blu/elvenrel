	.global _start

	.equ SYS_write, 64
	.equ SYS_exit, 93
	.equ SYS_nanosleep, 101
	.equ STDOUT_FILENO, 1

.if 0
	.equ FB_DIM_X, 203
	.equ FB_DIM_Y, 48
	.equ FRAMES, 2048
.else
	// symbols supplied by CLI
.endif
	.include "macro.inc"

	.text
_start:
	// clear screen
	mov	x8, SYS_write
	mov	x2, fb_clear_len
	adr	x1, fb_clear_cmd
	mov	x0, STDOUT_FILENO
	svc	0

	// clear fb
	movi	v0.16b, ' '
	adrf	x0, fb
	ldr	w1, =fb_len
	bl	memset

.Lfb_done:
	mov	w4, FB_DIM_X
	mov	w5, FB_DIM_X - 2
	mov	w6, FB_DIM_Y - 1
	fmov	s4, w4
	dup	v5.4s, w5
	dup	v6.4s, w6

	mov	x9, FRAMES
.Lframe:
	// reset cursor; x8 = SYS_write
	mov	x2, fb_cursor_len
	adr	x1, fb_cursor_cmd
	mov	x0, STDOUT_FILENO
	svc	0

	// access to fb: addr & len as per SYS_write
	ldr	w2, =fb_len
	adrf	x1, fb

	// plot blips in fb
	adrf	x10, blip
	adrf	x11, blip_end
	mov	x12, x11
.Lpack_plot:
	// four Q-form regs hold SoA { pos_x, pos_y, step_x, step_y }
	ldp	q0, q1, [x10]
	ldp	q2, q3, [x10, 32]

	mov	v7.16b, v0.16b
	mla	v7.4s, v1.4s, v4.s[0]

	str	q7, [x12], 16

	fmov	w4, s7
	mov	w5, v7.s[1]
	mov	w6, v7.s[2]
	mov	w7, v7.s[3]

	mov	w3, 0x5d5b
	strh	w3, [x1, x4]
	strh	w3, [x1, x5]
	strh	w3, [x1, x6]
	strh	w3, [x1, x7]

	// update positions
	add	v0.4s, v0.4s, v2.4s
	add	v1.4s, v1.4s, v3.4s

	// check bounds & update steps accordingly
	cmeq	v7.4s, v0.4s, v5.4s
	cmeq	v8.4s, v0.4s, 0
	cmeq	v9.4s, v1.4s, v6.4s
	cmeq	v10.4s, v1.4s, 0
	orr	v7.16b, v7.16b, v8.16b
	orr	v9.16b, v9.16b, v10.16b
	eor	v2.16b, v7.16b, v2.16b
	eor	v3.16b, v9.16b, v3.16b
	sub	v2.4s, v2.4s, v7.4s
	sub	v3.4s, v3.4s, v9.4s

	stp	q0, q1, [x10], 32
	stp	q2, q3, [x10], 32

	cmp	x10, x11
	bne	.Lpack_plot

	// output fb; x8 = SYS_write
	mov	x0, STDOUT_FILENO
	svc	0

	// erase blips from fb
	adrf	x10, blip_end
	adrf	x11, erase_end
.Lpack_erase:
	ldp	w4, w5, [x10], 8
	ldp	w6, w7, [x10], 8

	mov	w3, 0x2020
	strh	w3, [x1, x4]
	strh	w3, [x1, x5]
	strh	w3, [x1, x6]
	strh	w3, [x1, x7]

	cmp	x10, x11
	bne	.Lpack_erase

	mov	x8, SYS_nanosleep
	mov	x1, xzr
	adr	x0, timespec
	svc	0

	mov	x8, SYS_write
	subs	x9, x9, 1
	bne	.Lframe

	mov	x8, SYS_exit
	mov	x0, xzr
	svc	0

fb_clear_cmd:
	.ascii "\033[2J"
fb_clear_len = . - fb_clear_cmd

fb_cursor_cmd:
	.ascii "\033[1;1H"
fb_cursor_len = . - fb_cursor_cmd

	.align 3
timespec:
	.dword 0, 15500000

	.section .bss
	.align 6
fb:
	.fill FB_DIM_Y * FB_DIM_X
fb_len = . - fb
