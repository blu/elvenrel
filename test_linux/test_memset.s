	.global _start

	.equ SYS_write, 64
	.equ SYS_exit, 93
	.equ STDOUT_FILENO, 1

	.equ COLUMNS, 64
	.equ LINES, 48

_start:
	adrp	x4, fb
	add	x4, x4, :lo12:fb
	add	x5, x4, (COLUMNS + 1) * LINES
	mov	x6, 1
	mov	x7, 1
loop:
	movi	v0.16b, '.'
	mov	x0, x4
	mov	x1, x6
	bl	memset

	cmp	x7, LINES / (COLUMNS - LINES)
	csel	x7, xzr, x7, EQ
	add	x7, x7, 1
	add	x6, x6, 1
	cinc	x4, x4, EQ
	add	x4, x4, COLUMNS + 1
	cmp	x4, x5
	blo	loop

	mov	x8, SYS_write
	mov	x2, fb_len
	adr	x1, fb
	mov	x0, STDOUT_FILENO
	svc	0

	mov	x8, SYS_exit
	mov	x0, xzr
	svc	0

	.data
fb:
	.rept LINES
	.fill COLUMNS, 1, '='
	.byte '\n'
	.endr
fb_len = . - fb
