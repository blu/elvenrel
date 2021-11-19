	.global _start

	.equ SYS_write, 4
	.equ SYS_exit, 1
	.equ SYS_select, 93
	.equ STDOUT_FILENO, 1

.if 0
	.equ FB_DIM_X, 203
	.equ FB_DIM_Y, 48
	.equ FRAMES, 2048
.else
	// symbols supplied by CLI
.endif

// load 'far' address as a +/-4GB offset from PC
.macro adrf Xn, addr:req
	adrp	\Xn, \addr
	add	\Xn, \Xn, :lo12:\addr
.endm

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
	// four Q-form regs hold SoA { pos_x, pos_y, step_x, step_y }
	ldr	q0, blip +  0 // blip{0..3} pos_x
	ldr	q1, blip + 16 // blip{0..3} pos_y
	ldr	q2, blip + 32 // blip{0..3} step_x
	ldr	q3, blip + 48 // blip{0..3} step_y

	mov	w4, FB_DIM_X
	mov	w5, FB_DIM_X - 2
	mov	w6, FB_DIM_Y - 1
	fmov	s4, w4
	dup	v5.4s, w5
	dup	v6.4s, w6

	mov	x9, FRAMES
.Lframe:
	// reset cursor; x16 = SYS_write
	mov	x2, fb_cursor_len
	adr	x1, fb_cursor_cmd
	mov	x0, STDOUT_FILENO
	svc	0

	// access to fb: addr & len as per SYS_write
	ldr	x2, =fb_len
	adrf	x1, fb

	// plot blips in fb
	mov	v7.16b, v0.16b
	mla	v7.4s, v1.4s, v4.s[0]

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

	// output fb; x16 = SYS_write
	mov	x0, STDOUT_FILENO
	svc	0

	// erase blips from fb
	adrf	x1, fb
	mov	w3, 0x2020
	strh	w3, [x1, x4]
	strh	w3, [x1, x5]
	strh	w3, [x1, x6]
	strh	w3, [x1, x7]

	// xnu has no nanosleep
	mov	x16, SYS_select
	adr	x4, timeval
	mov	x3, xzr
	mov	x2, xzr
	mov	x1, xzr
	mov	x0, xzr
	svc	0

	mov	x16, SYS_write
	subs	x9, x9, 1
	bne	.Lframe

	mov	x16, SYS_exit
	mov	x0, xzr
	svc	0

	.align 4
blip:
	.word 0x00000030, 0x00000020, 0x00000010, 0x00000000 // blip{0..3} pos_x
	.word 0x00000010, 0x00000000, 0x00000010, 0x00000000 // blip{0..3} pos_y
	.word 0x00000001, 0x00000001, 0x00000001, 0x00000001 // blip{0..3} step_x
	.word 0xffffffff, 0x00000001, 0xffffffff, 0x00000001 // blip{0..3} step_y

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
