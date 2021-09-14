ASFLAGS += --strip-local-absolute
REL := test_text.o \
       test_rodata.o \
       test_data.o \
       test_bss.o \
       test_cross_0.o \
       test_cross_1.o \
       test_bounce.o \
       test_bounce_neon.o \
       test_bounce_neon_aosoa.o \
       test_bounce_neon_aosoa_bg.o \
       test_bounce_data_aosoa_alt_0.o \
       test_bounce_data_aosoa_alt_1.o \
       test_bounce_data_aosoa_alt_2.o \
       test_bounce_data_aosoa_alt_3.o

test_bounce.o: test_bounce.s
	$(AS) $(ASFLAGS) --defsym FB_DIM_X=$(shell tput cols) --defsym FB_DIM_Y=$(shell tput lines) --defsym FRAMES=1024 -o $@ $^

test_bounce_neon.o: test_bounce_neon.s
	$(AS) $(ASFLAGS) --defsym FB_DIM_X=$(shell tput cols) --defsym FB_DIM_Y=$(shell tput lines) --defsym FRAMES=2048 -o $@ $^

test_bounce_neon_aosoa.o: test_bounce_neon_aosoa.s
	$(AS) $(ASFLAGS) --defsym FB_DIM_X=$(shell tput cols) --defsym FB_DIM_Y=$(shell tput lines) --defsym FRAMES=1024 -o $@ $^

test_bounce_neon_aosoa_bg.o: test_bounce_neon_aosoa_bg.s
	$(AS) $(ASFLAGS) --defsym FB_DIM_X=$(shell tput cols) --defsym FB_DIM_Y=$(shell tput lines) --defsym FRAMES=2048 -o $@ $^

test_bounce_data_aosoa_alt_3.o: test_bounce_data_aosoa_alt_3.s
	$(AS) $(ASFLAGS) --defsym FB_DIM_X=$(shell tput cols) -o $@ $^

all: $(REL)

clean:
	rm -f $(REL)
