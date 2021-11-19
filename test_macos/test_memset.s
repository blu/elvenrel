	.global _start

	.equ SYS_write, 4
	.equ SYS_exit, 1
	.equ STDOUT_FILENO, 1

	.equ COLUMNS, 64
	.equ LINES, 48

// load 'far' address as a +/-4GB offset from PC
.macro adrf Xn, addr:req
	adrp	\Xn, \addr
	add	\Xn, \Xn, :lo12:\addr
.endm

_start:
	adrf	x4, fb
	add	x5, x4, (COLUMNS + 1) * LINES
	mov	x6, 1
once:
	movi	v0.16b, '.'
	mov	x0, x4
	mov	x1, x6
	bl	memset

	add	x6, x6, 1
	add	x4, x4, COLUMNS + 1
	cmp	x4, x5
	bne	once

	mov	x16, SYS_write
	mov	x2, fb_len
	adr	x1, fb
	mov	x0, STDOUT_FILENO
	svc	0

	mov	x16, SYS_exit
	mov	x0, xzr
	svc	0

	.data
fb:
	.rept LINES
	.fill COLUMNS, 1, '='
	.byte '\n'
	.endr
fb_len = . - fb
