// load 'far' address as a +/-4GB offset from PC
.macro adrf Xn, addr:req
	adrp	\Xn, \addr
	add	\Xn, \Xn, :lo12:\addr
.endm

// load a 32-bit immediate
.macro movl Wn, imm:req
	.if (\imm) & 0xffff
	movz	\Wn, (\imm) & 0xffff
	.if (\imm) & (0xffff << 16)
	movk	\Wn, ((\imm) >> 16) & 0xffff, lsl 16
	.endif
	.elseif (\imm) & (0xffff << 16)
	movz	\Wn, ((\imm) >> 16) & 0xffff, lsl 16
	.else
	mov	\Wn, wzr
	.endif
.endm

.macro __tail_movq Xn, imm:req
	.irp iter,1,2,3
	.if (\imm) & (0xffff << (\iter * 16))
	movk	\Xn, ((\imm) >> (\iter * 16)) & 0xffff, lsl \iter * 16
	.endif
	.endr
.endm

// load a 64-bit immediate
.macro movq Xn, imm:req
	.if (\imm) & 0xffff
	movz	\Xn, (\imm) & 0xffff
	__tail_movq \Xn, "((\imm) & ~0xffff)"
	.elseif (\imm) & (0xffff << 16)
	movz	\Xn, ((\imm) >> 16) & 0xffff, lsl 16
	__tail_movq \Xn, "((\imm) & ~0xffffffff)"
	.elseif (\imm) & (0xffff << 32)
	movz	\Xn, ((\imm) >> 32) & 0xffff, lsl 32
	__tail_movq \Xn, "((\imm) & ~0xffffffffffff)"
	.elseif (\imm) & (0xffff << 48)
	movz	\Xn, ((\imm) >> 48) & 0xffff, lsl 48
	.else
	mov     \Xn, xzr
	.endif
.endm
