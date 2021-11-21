# Differentiate between GAS and Apple clang
AS_VENDOR := $(word 1, $(shell $(AS) --version))
ifeq ($(AS_VENDOR), GNU)
	ASFLAGS += --strip-local-absolute
	defsym = --defsym $(1)=$(2)
else
	ASFLAGS += --target=aarch64-linux-gnu
	defsym = -Wa,-defsym,$(1)=$(2)
endif
REL := test_bounce_data_aosoa_alt_0.o \
       test_bounce_data_aosoa_alt_1.o \
       test_bounce_data_aosoa_alt_2.o \
       test_bounce_data_aosoa_alt_3.o \
       memset.o

test_bounce_data_aosoa_alt_3.o: test_bounce_data_aosoa_alt_3.s
	$(AS) $(ASFLAGS) $(call defsym,FB_DIM_X,$(shell tput cols)) -o $@ $^

all: $(REL)

clean:
	rm -f $(REL)
