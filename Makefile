SRC := reloc.c reloc_add_aarch64.c insn.h
TARGET := elvenrel
CFLAGS += -std=c11 -Ofast -DNDEBUG
LDFLAGS += -lelf
REL := test.o

$(TARGET): $(SRC)
	$(CC) $(filter %.c, $^) $(CFLAGS) $(LDFLAGS) -o $(TARGET)

$(REL): $(REL:%.o=%.s)
	$(AS) $< -o $@ --strip-local-absolute

all: $(TARGET) $(REL)

clean:
	rm $(TARGET) $(REL)
