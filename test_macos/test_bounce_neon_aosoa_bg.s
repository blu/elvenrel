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
	.equ GRID_DISTANCE_X, 8
	.equ GRID_DISTANCE_Y, 8

.if 0
	.equ GRID_STEP_X_0, 1
	.equ GRID_STEP_X_1, 0
	.equ GRID_STEP_X_2, 1
	.equ GRID_STEP_X_3, 0

	.equ GRID_STEP_Y_0, 0
	.equ GRID_STEP_Y_1, 1
	.equ GRID_STEP_Y_2, 0
	.equ GRID_STEP_Y_3, 1
.else
	.equ GRID_STEP_X_0, 1
	.equ GRID_STEP_X_1, 1
	.equ GRID_STEP_X_2, 1
	.equ GRID_STEP_X_3, 1

	.equ GRID_STEP_Y_0, 0
	.equ GRID_STEP_Y_1, 0
	.equ GRID_STEP_Y_2, 0
	.equ GRID_STEP_Y_3, 0
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
	mov	w4, FB_DIM_X
	mov	w5, FB_DIM_X - 2
	mov	w6, FB_DIM_Y - 1
	fmov	s4, w4
	dup	v5.4s, w5
	dup	v6.4s, w6

	// generate a grid of axes-traversing particles
	ldr	q3, grid_pos_0123
	ldr	q7, grid_step_0123
	ldr	q8, grid_step_0123 + 16
	ldr	q11, =0x10000000200000003

	adr	x10, grid_pos_xxx0
	adr	x11, grid_pos_1234
	adr	x12, grid_step_xxx0
	adr	x13, grid_step_1234

	adrf	x7, grid
	adrf	x8, grid_end
	mov	w9, wzr
.Lgen_grid:
	// how many x-coords exceed end-of-line - 2?
	cmhi	v2.4s, v3.4s, v5.4s
	addv	s1, v2.4s
	fmov	w0, s1
	dup	v0.4s, w9
	add	v0.4s, v0.4s, v11.4s
	cbz	w0, .Lgen_grid_next

	// produce a transitional end-of-one/start-of-another
	// pack inbetween subsequent lines
	mvn	w1, w0
	ldr	q1, [x10, x1, LSL 4]
	bic	v3.16b, v3.16b, v2.16b
	orr	v3.16b, v3.16b, v1.16b

	add	x2, x12, x1, LSL 5
	ldp	q9, q10, [x2]
	bic	v7.16b, v7.16b, v2.16b
	orr	v7.16b, v7.16b, v9.16b
	bic	v8.16b, v8.16b, v2.16b
	orr	v8.16b, v8.16b, v10.16b

	dup	v0.4s, w9
	mov	v12.16b, v11.16b
	add	w9, w9, GRID_DISTANCE_Y
	// clamp pos_y at bottom-of-fb; affects only padding particles
	cmp	w9, w6
	blo	.Lgen_grid_pos_y
	mov	w9, FB_DIM_Y - 1
	bic	v7.16b, v7.16b, v2.16b
	bic	v8.16b, v8.16b, v2.16b
	bic	v12.16b, v12.16b, v2.16b
.Lgen_grid_pos_y:
	dup	v1.4s, w9

	bic	v0.16b, v0.16b, v2.16b
	and	v1.16b, v1.16b, v2.16b
	orr	v0.16b, v0.16b, v1.16b
	add	v0.4s, v0.4s, v12.4s

	// if the fist pack is entirely from the new line
	// then move over to that
	cmn	w0, 4
	beq	.Lgen_grid_next

	// first pack is actually transitional
	// pos_x, pos_y, step_x, step_y
	stp	q3, q0, [x7], 32
	stp	q7, q8, [x7], 32

	cmp	x7, x8
	beq	.Lgen_grid_done

	// prepare next pack entirely from the new line
	ldr	q3, [x11, x1, LSL 4]
	dup	v0.4s, w9
	add	v0.4s, v0.4s, v11.4s

	add	x2, x13, x1, LSL 5
	ldp	q7, q8, [x2]

.Lgen_grid_next:
	// pos_x, pos_y, step_x, step_y
	stp	q3, q0, [x7], 32
	stp	q7, q8, [x7], 32

	mov	w0, GRID_DISTANCE_X * 4
	dup	v2.4s, w0

	add	v3.4s, v3.4s, v2.4s

	cmp	x7, x8
	bne	.Lgen_grid

.Lgen_grid_done:
	mov	x16, SYS_write
	mov	x9, FRAMES
	movi	v11.4s, 1
	add	v11.4s, v11.4s, v5.4s
.Lframe:
	// reset cursor; x16 = SYS_write
	mov	x2, fb_cursor_len
	adr	x1, fb_cursor_cmd
	mov	x0, STDOUT_FILENO
	svc	0

	// access to fb: addr & len as per SYS_write
	ldr	w2, =fb_len
	adrf	x1, fb

	// plot grid in fb
	adrf	x10, grid
	adrf	x11, grid_end
	mov	x12, x11
.Lgrid_plot:
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

	mov	w3, 'o'
	strb	w3, [x1, x4]
	strb	w3, [x1, x5]
	strb	w3, [x1, x6]
	strb	w3, [x1, x7]

	// update positions
	add	v0.4s, v0.4s, v2.4s
	add	v1.4s, v1.4s, v3.4s

	// check bounds & update steps accordingly
	cmeq	v7.4s, v0.4s, v11.4s
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
	bne	.Lgrid_plot

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

	// output fb; x16 = SYS_write
	mov	x0, STDOUT_FILENO
	svc	0

	// erase grid from fb
	adrf	x1, fb
	adrf	x10, grid_end
	adrf	x11, grid_erase_end
.Lgrid_erase:
	ldp	w4, w5, [x10], 8
	ldp	w6, w7, [x10], 8

	mov	w3, 0x20
	strb	w3, [x1, x4]
	strb	w3, [x1, x5]
	strb	w3, [x1, x6]
	strb	w3, [x1, x7]

	cmp	x10, x11
	bne	.Lgrid_erase

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
grid_pos_xxx0:
	.word	0,                   0,                   0,                   GRID_DISTANCE_X * 0
grid_pos_xx01:
	.word	0,                   0,                   GRID_DISTANCE_X * 0, GRID_DISTANCE_X * 1
grid_pos_x012:
	.word	0,                   GRID_DISTANCE_X * 0, GRID_DISTANCE_X * 1, GRID_DISTANCE_X * 2
grid_pos_0123:
	.word	GRID_DISTANCE_X * 0, GRID_DISTANCE_X * 1, GRID_DISTANCE_X * 2, GRID_DISTANCE_X * 3
grid_pos_1234:
	.word	GRID_DISTANCE_X * 1, GRID_DISTANCE_X * 2, GRID_DISTANCE_X * 3, GRID_DISTANCE_X * 4
grid_pos_2345:
	.word	GRID_DISTANCE_X * 2, GRID_DISTANCE_X * 3, GRID_DISTANCE_X * 4, GRID_DISTANCE_X * 5
grid_pos_3456:
	.word	GRID_DISTANCE_X * 3, GRID_DISTANCE_X * 4, GRID_DISTANCE_X * 5, GRID_DISTANCE_X * 6

grid_step_xxx0:
	.word	0,             0,             0,             GRID_STEP_X_0
	.word	0,             0,             0,             GRID_STEP_Y_0
grid_step_xx01:
	.word	0,             0,             GRID_STEP_X_0, GRID_STEP_X_1
	.word	0,             0,             GRID_STEP_Y_0, GRID_STEP_Y_1
grid_step_x012:
	.word	0,             GRID_STEP_X_0, GRID_STEP_X_1, GRID_STEP_X_2
	.word	0,             GRID_STEP_Y_0, GRID_STEP_Y_1, GRID_STEP_Y_2
grid_step_0123:
	.word	GRID_STEP_X_0, GRID_STEP_X_1, GRID_STEP_X_2, GRID_STEP_X_3
	.word	GRID_STEP_Y_0, GRID_STEP_Y_1, GRID_STEP_Y_2, GRID_STEP_Y_3
grid_step_1234:
	.word	GRID_STEP_X_1, GRID_STEP_X_2, GRID_STEP_X_3, GRID_STEP_X_0
	.word	GRID_STEP_Y_1, GRID_STEP_Y_2, GRID_STEP_Y_3, GRID_STEP_Y_0
grid_step_2345:
	.word	GRID_STEP_X_2, GRID_STEP_X_3, GRID_STEP_X_0, GRID_STEP_X_1
	.word	GRID_STEP_Y_2, GRID_STEP_Y_3, GRID_STEP_Y_0, GRID_STEP_Y_1
grid_step_3456:
	.word	GRID_STEP_X_3, GRID_STEP_X_0, GRID_STEP_X_1, GRID_STEP_X_2
	.word	GRID_STEP_Y_3, GRID_STEP_Y_0, GRID_STEP_Y_1, GRID_STEP_Y_2

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
fb_len = . - fb

	.align 6
grid:
	.fill (((FB_DIM_X + GRID_DISTANCE_X - 2) / GRID_DISTANCE_X) * ((FB_DIM_Y + GRID_DISTANCE_Y - 2 - 3) / GRID_DISTANCE_Y) + 3) / 4 * 64
grid_end:
	.fill (grid_end - grid) / 16, 4
grid_erase_end:
