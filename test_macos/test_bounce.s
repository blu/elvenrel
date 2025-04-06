	.global _start

	.equ SYS_write, 4
	.equ SYS_exit, 1
	.equ SYS_select, 93
	.equ STDOUT_FILENO, 1

	.equ COORD_FRAC, 16
.if 0
	.equ FB_DIM_X, 203
	.equ FB_DIM_Y, 48
	.equ FRAMES, 1024
.else
	// symbols supplied by CLI
.endif
	.include "macro.inc"

	.text
_start:
	// clear screen
	mov	x16, SYS_write
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
	mov	w5, wzr // blip pos_x
	mov	w6, wzr // blip pos_y
	mov	x7, FRAMES
	mov	w9, (FB_DIM_X - 2) << COORD_FRAC // max bound_x
	mov	w10, (FB_DIM_Y - 1) << COORD_FRAC // max bound_y
	mov	w11, 0x1 << (COORD_FRAC - 0) // blip step_x
	mov	w12, 0x8 << (COORD_FRAC - 4) // blip step_y
.Lframe:
	// reset cursor; x16 = SYS_write
	mov	x2, fb_cursor_len
	adr	x1, fb_cursor_cmd
	mov	x0, STDOUT_FILENO
	svc	0

	// access to fb: addr & len as per SYS_write
	ldr	w2, =fb_len
	adrf	x1, fb

	// plot blip in fb
	asr	w13, w5, COORD_FRAC
	asr	w14, w6, COORD_FRAC
	// round fractional coords to +inf
	ubfx	w17, w5, (COORD_FRAC - 1), #1
	ubfx	w19, w6, (COORD_FRAC - 1), #1
	add	w13, w13, w17
	add	w14, w14, w19

	mov	w3, 0x5d5b
	mov	w4, FB_DIM_X
	madd	w4, w4, w14, w13
	strh	w3, [x1, x4]

	// update position
	add	w5, w5, w11
	add	w6, w6, w12

	// check bounds & update step accordingly
	cmp	w5, w9
	ccmp	w5, 0, 4, NE
	cneg	w11, w11, EQ

	cmp	w6, w10
	ccmp	w6, 0, 4, NE
	cneg	w12, w12, EQ

	// output fb; x16 = SYS_write
	mov	x0, STDOUT_FILENO
	svc	0

	// erase blip from fb
	adrf	x1, fb
	mov	w3, 0x2020
	strh	w3, [x1, x4]

	// xnu has no nanosleep
	mov	x16, SYS_select
	adr	x4, timeval
	mov	x3, xzr
	mov	x2, xzr
	mov	x1, xzr
	mov	x0, xzr
	svc	0

	mov	x16, SYS_write
	subs	x7, x7, 1
	bne	.Lframe

	mov	x16, SYS_exit
	mov	x0, xzr
	svc	0

fb_clear_cmd:
	.ascii "\033[2J"
fb_clear_len = . - fb_clear_cmd

fb_cursor_cmd:
	.ascii "\033[1;1H"
fb_cursor_len = . - fb_cursor_cmd

	.align 3
timeval:
	.dword 0, 15500

	.section .bss
	.align 6
fb:
	.fill FB_DIM_Y * FB_DIM_X
fb_len = . - fb
