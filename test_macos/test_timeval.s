	.global _start

	.equ SYS_write, 4
	.equ SYS_exit, 1
	.equ SYS_select, 93
	.equ SYS_gettimeofday, 116
	.equ STDOUT_FILENO, 1
.ifndef DTIME
	.equ DTIME, 15500
.endif

// load 'far' address as a +/-4GB offset from PC
.macro adrf Xn, addr:req
	adrp	\Xn, \addr
	add	\Xn, \Xn, :lo12:\addr
.endm

// load a 32-bit immediate
.macro movl Wn, imm:req
	movz	\Wn, (\imm) & 0Xffff
	movk	\Wn, ((\imm) >> 16) & 0Xffff, lsl 16
.endm

	.text

// advance timeval by a non-negative dtime in us
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

_start:
	adrf	x17, timeval

	mov	x16, SYS_gettimeofday
	mov	x2, xzr
	mov	x1, xzr
	mov	x0, x17
	svc	0

	// itoa timeval::tv_sec
	ldr	x1, [x17]
	adrf	x0, msg
	bl	string_x64

	// itoa timeval::tv_usec
	ldr	x1, [x17, 8]
	adrf	x0, msg + 17
	bl	string_x64

	// output current time
	mov	x16, SYS_write
	mov	x2, msg_len
	adrf	x1, msg
	mov	x0, STDOUT_FILENO
	svc	0

	// advance time by DTIME us
	mov	w1, DTIME
	mov	x0, x17
	bl	advance_timeval_us

	// itoa timeval::tv_sec
	ldr	x1, [x17]
	adrf	x0, msg
	bl	string_x64

	// itoa timeval::tv_usec
	ldr	x1, [x17, 8]
	adrf	x0, msg + 17
	bl	string_x64

	// output new time
	mov	x16, SYS_write
	mov	x2, msg_len
	adrf	x1, msg
	mov	x0, STDOUT_FILENO
	svc	0

	// xnu has no nano/usleep -- use select with empty fd sets
	mov	x16, SYS_select
	adr	x4, timeval_select
	mov	x3, xzr
	mov	x2, xzr
	mov	x1, xzr
	mov	x0, xzr
	svc	0

	mov	x16, SYS_gettimeofday
	mov	x2, xzr
	mov	x1, xzr
	mov	x0, x17
	svc	0

	// itoa timeval::tv_sec
	ldr	x1, [x17]
	adrf	x0, msg
	bl	string_x64

	// itoa timeval::tv_usec
	ldr	x1, [x17, 8]
	adrf	x0, msg + 17
	bl	string_x64

	// output post-sleep time
	mov	x16, SYS_write
	mov	x2, msg_len
	adrf	x1, msg
	mov	x0, STDOUT_FILENO
	svc	0

	mov	x16, SYS_exit
	mov	x0, xzr
	svc	0

timeval_select:
	.dword 0, DTIME

	.section .bss
timeval:
	.dword 0, 0

	.section .data
msg:
	.ascii "################:################\n"
msg_len = . - msg
