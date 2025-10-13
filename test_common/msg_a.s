	.global	msg

	.section .rodata

	.byte	len
msg:
	.ascii	"message A\n"
len = . - msg
