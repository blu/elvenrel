	.arch armv8-a

	.global _start

	.equ SYS_write, 64
	.equ SYS_exit, 93
	.equ SYS_nanosleep, 101
	.equ SYS_gettimeofday, 169
	.equ STDOUT_FILENO, 1
.ifndef DTIME
	.equ DTIME, 15500
.elseif DTIME >= 1000000
	.error "DTIME greater-or-equal to 1e6"
.endif
	.include "macro.inc"

	.text
_start:
	adrf	x17, timeval
	adrf	x19, msg

	mov	x8, SYS_gettimeofday
	mov	x2, xzr
	mov	x1, xzr
	mov	x0, x17
	svc	0

	mov	x8, SYS_nanosleep
	mov	x1, xzr
	adr	x0, timespec_nanosleep
	svc	0

	mov	x8, SYS_gettimeofday
	mov	x2, xzr
	mov	x1, xzr
	add	x0, x17, 16
	svc	0

	// itoa start time (timeval::tv_sec and timeval::tv_usec)
	ldr	x1, [x17]
	mov	x0, x19
	bl	string_x64

	ldr	w1, [x17, 8]
	add	x0, x19, 17
	bl	string_x32

	// advance start time by DTIME us
	movl	w1, DTIME
	mov	x0, x17
	bl	advance_timeval_us

	// itoa target time
	ldr	x1, [x17]
	add	x0, x19, 26
	bl	string_x64

	ldr	w1, [x17, 8]
	add	x0, x19, 43
	bl	string_x32

	// itoa post-sleep time
	ldr	x1, [x17, 16]
	add	x0, x19, 52
	bl	string_x64

	ldr	w1, [x17, 24]
	add	x0, x19, 69
	bl	string_x32

	// output start, target and post-sleep times
	mov	x8, SYS_write
	mov	x2, msg_len
	mov	x1, x19
	mov	x0, STDOUT_FILENO
	svc	0

	mov	x8, SYS_exit
	mov	x0, xzr
	svc	0

timespec_nanosleep:
	.dword 0, DTIME * 1000

	.section .bss
	.align 4
timeval:
	.dword 0, 0
	.dword 0, 0

	.section .data
msg:
	.ascii "################:########\n"
	.ascii "################:########\n"
	.ascii "################:########\n"
msg_len = . - msg
