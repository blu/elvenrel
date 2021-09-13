# Elven Relativism top makefile for Linux/aarch64 and macOS/arm64

UNAME := $(shell uname)
UNAME_M := $(shell uname -m)
TARGET := elvenrel
SOURCE := reloc.c reloc_add_aarch64.c insn.h
CFLAGS += -std=gnu11 -Ofast -DNDEBUG -DPAGE_SIZE=$(shell getconf PAGE_SIZE) -fno-stack-protector -fPIC
CXXFLAGS += -std=c++11 -Ofast -fno-exceptions -fno-rtti -DNDEBUG -DPAGE_SIZE=$(shell getconf PAGE_SIZE) -fno-stack-protector -fPIC

ifeq ($(UNAME), Linux)

ifneq ($(UNAME_M), aarch64)
	$(error unsupported arch)
endif

# Update state for linux/aarch64
SOURCE += stringx.s strlen_linux.s vma.cpp vma.h
LDFLAGS += -lelf
TEST_SUBDIR := test_linux

else ifeq ($(UNAME), Darwin)

ifneq ($(UNAME_M), arm64)
	$(error unsupported arch)
endif

# Update state for macos/arm64
CFLAGS += -I/opt/homebrew/include
LDFLAGS += /opt/homebrew/lib/libelf.a
TEST_SUBDIR := test_macos

else # unsupported os
	$(error unsupposrted os)
endif

OBJ := $(addsuffix .o, $(basename $(filter %.s %.c %.cpp, $(SOURCE))))

$(TARGET): $(OBJ)
	$(CC) $^ $(LDFLAGS) -o $(TARGET)

reloc.o: reloc.c vma.h char_ptr_arr.h

reloc_add_aarch64.o: reloc_add_aarch64.c insn.h

vma.o: vma.cpp vma.h char_ptr_arr.h

all: $(TARGET)
	$(MAKE) -C $(TEST_SUBDIR) all

clean:
	rm -f $(TARGET) $(OBJ)
	$(MAKE) -C $(TEST_SUBDIR) clean
