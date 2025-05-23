	.global _start

	.equ SYS_write, 64
	.equ SYS_exit, 93
	.equ STDOUT_FILENO, 1

	.equ COLUMNS, 64
	.equ LINES, 48

	.include "macro.inc"
_start:
	adrf	x4, fb
	add	x5, x4, (COLUMNS + 1) * LINES
	mov	x6, 1
	mov	x7, 1
.Lloop:
	mov	x0, x4
	movq	x1, 0x2e2e2e2e2e2e2e2e
	mov	x2, x6
	bl	memset_woa

	cmp	x7, LINES / (COLUMNS - LINES)
	csel	x7, xzr, x7, EQ
	add	x7, x7, 1
	add	x6, x6, 1
	cinc	x4, x4, EQ
	add	x4, x4, COLUMNS + 1
	cmp	x4, x5
	blo	.Lloop

	mov	x8, SYS_write
	mov	x2, fb_len
	adrf	x1, fb
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
