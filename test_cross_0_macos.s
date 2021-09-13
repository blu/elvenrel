	.global buf

	.section .rodata

	.byte len
buf:
	.ascii	"hello from ET_REL\n"
len = . - buf
