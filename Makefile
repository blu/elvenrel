SRC := reloc.c reloc_add_aarch64.c insn.h stringx.s strlen_linux.s vma.cpp vma.h
TARGET := elvenrel
CFLAGS += -std=c11 -Ofast -DNDEBUG -DPAGE_SIZE=$(shell getconf PAGE_SIZE)
CXXFLAGS += -std=c++11 -Ofast -fno-exceptions -fno-rtti -DNDEBUG -DPAGE_SIZE=$(shell getconf PAGE_SIZE)
LDFLAGS += -lelf
ASFLAGS += --strip-local-absolute
# Optional test objects built by target ALL
REL := test_rodata.o test_data.o test_cross1.o test_cross2.o

OBJ := $(addsuffix .o, $(basename $(filter %.s %.c %.cpp, $(SRC))))

$(TARGET): $(OBJ)
	$(CC) $^ $(LDFLAGS) -o $(TARGET)

reloc.o: reloc.c vma.h

reloc_add_aarch64.o: reloc_add_aarch64.c insn.h

vma.o: vma.cpp vma.h

all: $(TARGET) $(REL)

clean:
	rm -f $(TARGET) $(OBJ) $(REL)
