# Linux x86-64 build. Targets are linked without libc and without a shell.

NASM      ?= nasm
LD        ?= ld
# NASM 2.16.03 warns on every cross-object call. Ubuntu 24.04 ships an older
# NASM that rejects the warning name, so the suppression is probed first.
NASM_RELOC := $(shell src=$$(mktemp); out=$$(mktemp); printf 'bits 64\nnop\n' > $$src; if $(NASM) -f elf64 -w+all -w+error -w-reloc-rel-dword -o $$out $$src >/dev/null 2>&1; then echo -w-reloc-rel-dword; fi; rm -f $$src $$out)
NASMFLAGS := -f elf64 -g -F dwarf -I include/ -w+all -w+error $(NASM_RELOC)
LDFLAGS   := -z noexecstack
BUILD     ?= build

INCLUDES := include/constants.inc include/syscalls.inc include/macros.inc

FUZZER_OBJS := \
	$(BUILD)/src/main.o \
	$(BUILD)/src/core/engine.o \
	$(BUILD)/src/core/executor.o \
	$(BUILD)/src/core/signals.o \
	$(BUILD)/src/core/coverage.o \
	$(BUILD)/src/core/queue.o \
	$(BUILD)/src/core/privilege.o \
	$(BUILD)/src/core/namespace.o \
	$(BUILD)/src/mutators/bitflip.o \
	$(BUILD)/src/mutators/byteflip.o \
	$(BUILD)/src/mutators/arithmetic.o \
	$(BUILD)/src/mutators/schedule.o \
	$(BUILD)/src/corpus/loader.o \
	$(BUILD)/src/corpus/directory.o \
	$(BUILD)/src/corpus/minimize.o \
	$(BUILD)/src/reporting/crash.o \
	$(BUILD)/src/reporting/path.o \
	$(BUILD)/src/utils/syscalls.o \
	$(BUILD)/src/utils/memory.o \
	$(BUILD)/src/utils/prng.o

.PHONY: all tools test lint security clean

all: $(BUILD)/asm-fuzzer

tools: \
	$(BUILD)/asm-fuzzer \
	$(BUILD)/demo-target \
	$(BUILD)/spin-target \
	$(BUILD)/stall-target \
	$(BUILD)/block-read-target \
	$(BUILD)/multi-target \
	$(BUILD)/shrink-target \
	$(BUILD)/path-target \
	$(BUILD)/flood-target \
	$(BUILD)/priv-target \
	$(BUILD)/ns-target \
	$(BUILD)/test-mutators \
	$(BUILD)/test-memory \
	$(BUILD)/test-signals \
	$(BUILD)/test-schedule \
	$(BUILD)/test-privilege \
	$(BUILD)/test-queue

$(BUILD)/asm-fuzzer: $(FUZZER_OBJS)
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $(FUZZER_OBJS)

$(BUILD)/demo-target: $(BUILD)/tests/targets/demo_target.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $<

$(BUILD)/spin-target: $(BUILD)/tests/targets/spin_target.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $<

$(BUILD)/stall-target: $(BUILD)/tests/targets/stall_target.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $<

$(BUILD)/block-read-target: $(BUILD)/tests/targets/block_read_target.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $<

$(BUILD)/multi-target: $(BUILD)/tests/targets/multi_target.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $<

$(BUILD)/shrink-target: $(BUILD)/tests/targets/shrink_target.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $<

$(BUILD)/path-target: $(BUILD)/tests/targets/path_target.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $<

$(BUILD)/flood-target: $(BUILD)/tests/targets/flood_target.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $<

$(BUILD)/test-queue: \
	$(BUILD)/tests/unit/test_queue.o \
	$(BUILD)/src/core/queue.o \
	$(BUILD)/src/core/coverage.o \
	$(BUILD)/src/utils/memory.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $^

$(BUILD)/priv-target: $(BUILD)/tests/targets/priv_target.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $<

$(BUILD)/ns-target: $(BUILD)/tests/targets/ns_target.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $<

$(BUILD)/test-privilege: $(BUILD)/tests/unit/test_privilege.o $(BUILD)/src/core/privilege.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $^

$(BUILD)/test-schedule: \
	$(BUILD)/tests/unit/test_schedule.o \
	$(BUILD)/src/mutators/schedule.o \
	$(BUILD)/src/mutators/bitflip.o \
	$(BUILD)/src/mutators/byteflip.o \
	$(BUILD)/src/mutators/arithmetic.o \
	$(BUILD)/src/utils/prng.o
	mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) -o $@ $^

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
