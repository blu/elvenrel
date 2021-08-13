SRC := reloc.c reloc_add_aarch64.c insn.h
TARGET := elvenrel
CFLAGS += -std=c11 -Ofast -DNDEBUG
LDFLAGS += -lelf
REL := test.o

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(LDFLAGS) $(filter %.c, $^) -o $(TARGET)

$(REL): $(REL:%.o=%.s)
	$(AS) $< -o $@ --strip-local-absolute

all: $(TARGET) test.o

clean:
	rm $(TARGET) $(REL)
