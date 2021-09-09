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

// load 'far' address as a +/-4GB offset from PC
.macro adrf Xn, addr:req
	adrp	\Xn, \addr
	add	\Xn, \Xn, :lo12:\addr
.endm

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
	adrf	x1, fb
	adrf	x2, fb_end
	and	x4, x2, -32
	and	x3, x2, -16
.Lclear_fb:
	cmp	x1, x4
	beq	.Lclear_fb_tail_0
	stp	q0, q0, [x1], 32
	b	.Lclear_fb
.Lclear_fb_tail_0:
	cmp	x1, x3
	beq	.Lclear_fb_tail_1
	str	q0, [x1], 16
.Lclear_fb_tail_1:
	cmp	x1, x2
	beq	.Lfb_done
	str	b0, [x1], 1
	b	.Lclear_fb_tail_1

.Lfb_done:
	// four Q-form regs hold SoA { pos_x, pos_y, step_x, step_y }
	ldr	q0, =0x00000000000000100000002000000030 // blip{0..3} pos_x
	ldr	q1, =0x00000000000000100000000000000010 // blip{0..3} pos_y
	ldr	q2, =0x00000001000000010000000100000001 // blip{0..3} step_x
	ldr	q3, =0x00000001ffffffff00000001ffffffff // blip{0..3} step_y

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

	// output fb; x8 = SYS_write
	mov	x0, STDOUT_FILENO
	svc	0

	// erase blips from fb
	mov	w3, 0x2020
	strh	w3, [x1, x4]
	strh	w3, [x1, x5]
	strh	w3, [x1, x6]
	strh	w3, [x1, x7]

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

timespec:
	.dword 0, 15500000

	.section .bss
	.align 6
fb:
	.fill FB_DIM_Y * FB_DIM_X
fb_end:
fb_len = . - fb
