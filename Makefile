# Linux x86-64 build. Targets are linked without libc and without a shell.

NASM      ?= nasm
LD        ?= ld
# reloc-rel-dword flags every call into another object. That relocation is the
# normal ELF64 pc-relative call, so it stays visible without failing the build.
NASMFLAGS := -f elf64 -g -F dwarf -I include/ -w+all -w+error -w-reloc-rel-dword
LDFLAGS   := -z noexecstack
BUILD     ?= build

INCLUDES := include/constants.inc include/syscalls.inc include/macros.inc

FUZZER_OBJS := \
	$(BUILD)/src/main.o \
	$(BUILD)/src/core/engine.o \
	$(BUILD)/src/core/executor.o \
	$(BUILD)/src/core/signals.o \
	$(BUILD)/src/mutators/bitflip.o \
	$(BUILD)/src/mutators/byteflip.o \
	$(BUILD)/src/mutators/arithmetic.o \
	$(BUILD)/src/corpus/loader.o \
	$(BUILD)/src/reporting/crash.o \
	$(BUILD)/src/utils/syscalls.o \
	$(BUILD)/src/utils/memory.o

.PHONY: all tools test lint security clean

all: $(BUILD)/asm-fuzzer

tools: \
	$(BUILD)/asm-fuzzer \
	$(BUILD)/demo-target \
	$(BUILD)/test-mutators \
	$(BUILD)/test-memory \
	$(BUILD)/test-signals

$(BUILD)/asm-fuzzer: $(FUZZER_OBJS)
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $(FUZZER_OBJS)

$(BUILD)/demo-target: $(BUILD)/tests/targets/demo_target.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $<

$(BUILD)/test-mutators: \
	$(BUILD)/tests/unit/test_mutators.o \
	$(BUILD)/src/mutators/bitflip.o \
	$(BUILD)/src/mutators/byteflip.o \
	$(BUILD)/src/mutators/arithmetic.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $^

$(BUILD)/test-memory: $(BUILD)/tests/unit/test_memory.o $(BUILD)/src/utils/memory.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $^

$(BUILD)/test-signals: $(BUILD)/tests/unit/test_signals.o $(BUILD)/src/core/signals.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $^

$(BUILD)/%.o: %.asm $(INCLUDES)
	mkdir -p $(dir $@)
	$(NASM) $(NASMFLAGS) -o $@ $<

test:
	BUILD="$(BUILD)" bash scripts/test.sh

lint:
	bash scripts/lint.sh

security:
	bash scripts/security.sh

clean:
	rm -rf $(BUILD)
