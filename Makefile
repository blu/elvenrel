SRC := reloc.c reloc_add_aarch64.c insn.h stringx.s strlen_linux.s vma.cpp vma.h
TARGET := elvenrel
CFLAGS += -std=c11 -Ofast -DNDEBUG -DPAGE_SIZE=$(shell getconf PAGE_SIZE) -fno-stack-protector -fPIC
CXXFLAGS += -std=c++11 -Ofast -fno-exceptions -fno-rtti -DNDEBUG -DPAGE_SIZE=$(shell getconf PAGE_SIZE) -fno-stack-protector -fPIC
LDFLAGS += -lelf
ASFLAGS += --strip-local-absolute
# Optional test objects built by target ALL
REL := test_rodata.o test_data.o test_cross1.o test_cross2.o test_bounce.o test_bounce_neon.o

OBJ := $(addsuffix .o, $(basename $(filter %.s %.c %.cpp, $(SRC))))

$(TARGET): $(OBJ)
	$(CC) $^ $(LDFLAGS) -o $(TARGET)

reloc.o: reloc.c vma.h

reloc_add_aarch64.o: reloc_add_aarch64.c insn.h

vma.o: vma.cpp vma.h

test_bounce.o: test_bounce.s
	$(AS) $(ASFLAGS) --defsym FB_DIM_X=$(shell tput cols) --defsym FB_DIM_Y=$(shell tput lines) --defsym FRAMES=1024 -o $@ $^

test_bounce_neon.o: test_bounce_neon.s
	$(AS) $(ASFLAGS) --defsym FB_DIM_X=$(shell tput cols) --defsym FB_DIM_Y=$(shell tput lines) --defsym FRAMES=2048 -o $@ $^

all: $(TARGET) $(REL)

clean:
	rm -f $(TARGET) $(OBJ) $(REL)
