	.global	msg

	.section .rodata

	.byte	len
msg:
	.ascii	"message B\n"
len = . - msg
