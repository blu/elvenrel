# Differentiate between GAS and Apple clang
AS_VENDOR := $(word 1, $(shell $(AS) --version))
ifeq ($(AS_VENDOR), GNU)
	ASFLAGS += --strip-local-absolute
	defsym = --defsym $(1)=$(2)
else
	ASFLAGS += --target=aarch64-linux-gnu
	defsym = -Wa,-defsym,$(1)=$(2)
endif
REL := test_text.o \
       test_rodata.o \
       test_data.o \
       test_bss.o \
       test_cross_0.o \
       test_cross_1.o \
       test_timeval.o \
       stringx.o \
       test_bounce.o \
       test_bounce_neon.o \
       test_bounce_neon_aosoa.o \
       test_bounce_neon_aosoa_bg.o

stringx.o: ../stringx.s
	$(AS) $(ASFLAGS) -o $@ $^

test_bounce.o: test_bounce.s
	$(AS) $(ASFLAGS) $(call defsym,FB_DIM_X,$(shell tput cols)) $(call defsym,FB_DIM_Y,$(shell tput lines)) $(call defsym,FRAMES,1024) -o $@ $^

test_bounce_neon.o: test_bounce_neon.s
	$(AS) $(ASFLAGS) $(call defsym,FB_DIM_X,$(shell tput cols)) $(call defsym,FB_DIM_Y,$(shell tput lines)) $(call defsym,FRAMES,2048) -o $@ $^

test_bounce_neon_aosoa.o: test_bounce_neon_aosoa.s
	$(AS) $(ASFLAGS) $(call defsym,FB_DIM_X,$(shell tput cols)) $(call defsym,FB_DIM_Y,$(shell tput lines)) $(call defsym,FRAMES,1024) -o $@ $^

test_bounce_neon_aosoa_bg.o: test_bounce_neon_aosoa_bg.s
	$(AS) $(ASFLAGS) $(call defsym,FB_DIM_X,$(shell tput cols)) $(call defsym,FB_DIM_Y,$(shell tput lines)) $(call defsym,FRAMES,2048) -o $@ $^

all: $(REL)

clean:
	rm -f $(REL)
