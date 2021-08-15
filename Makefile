SRC := reloc.c reloc_add_aarch64.c insn.h
TARGET := elvenrel
CFLAGS += -std=c11 -Ofast -DNDEBUG
LDFLAGS += -lelf
ASFLAGS += --strip-local-absolute
REL := test.o test_data.o test_cross1.o test_cross2.o

$(TARGET): $(SRC)
	$(CC) $(filter %.c, $^) $(CFLAGS) $(LDFLAGS) -o $(TARGET)

%.o: %.s
	$(AS) $< -o $@ $(ASFLAGS)

all: $(TARGET) $(REL)

clean:
	rm -f $(TARGET) $(REL)
