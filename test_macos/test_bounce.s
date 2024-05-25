	.global _start

	.equ SYS_write, 4
	.equ SYS_exit, 1
	.equ SYS_select, 93
	.equ STDOUT_FILENO, 1

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
	adrf	x1, fb_end
	bl	memset32

.Lfb_done:
	mov	w5, wzr // blip pos_x
	mov	w6, wzr // blip pos_y
	mov	x7, FRAMES
	mov	w10, 1 // blip step_x
	mov	w11, 1 // blip step_y
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
	mov	w3, 0x5d5b
	mov	w4, FB_DIM_X
	madd	w4, w4, w6, w5
	strh	w3, [x1, x4]

	// update position
	add	w5, w5, w10
	add	w6, w6, w11

	// check bounds & update step accordingly
	cmp	w5, FB_DIM_X - 2
	ccmp	w5, 0, 4, NE
	cneg	w10, w10, EQ

	cmp	w6, FB_DIM_Y - 1
	ccmp	w6, 0, 4, NE
	cneg	w11, w11, EQ

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
	.dword 0, 12300

	.section .bss
	.align 6
fb:
	.fill FB_DIM_Y * FB_DIM_X
fb_end:
fb_len = . - fb
