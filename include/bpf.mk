BPF_DEPENDS := @HAS_BPF_TOOLCHAIN

ifneq ($(CONFIG_BPF_TOOLCHAIN_HOST),)
  BPF_TOOLCHAIN_HOST_PATH:=$(call qstrip,$(CONFIG_BPF_TOOLCHAIN_HOST_PATH))
  ifneq ($(BPF_TOOLCHAIN_HOST_PATH),)
    BPF_PATH:=$(BPF_TOOLCHAIN_HOST_PATH)/bin:$(PATH)
  else
    BPF_PATH:=$(BPF_PATH)
  endif
  CLANG:=$(firstword $(shell PATH='$(BPF_PATH)' which clang clang-13 clang-12 clang-11))
  LLVM_VER:=$(subst clang,,$(notdir $(CLANG)))
else
  CLANG:=$(STAGING_DIR_HOST)/bin/clang
  LLVM_VER:=
endif

LLVM_PATH:=$(dir $(CLANG))
LLVM_LLC:=$(LLVM_PATH)/llc$(LLVM_VER)
LLVM_DIS:=$(LLVM_PATH)/llvm-dis$(LLVM_VER)
LLVM_OPT:=$(LLVM_PATH)/opt$(LLVM_VER)
LLVM_STRIP:=$(LLVM_PATH)/llvm-strip$(LLVM_VER)

BPF_KARCH:=mips
BPF_ARCH:=mips$(if $(CONFIG_BIG_ENDIAN),,el)

BPF_HEADERS_DIR:=$(STAGING_DIR)/bpf-headers

BPF_KERNEL_INCLUDE := \
	-nostdinc -isystem $(TOOLCHAIN_DIR)/include \
	-I$(BPF_HEADERS_DIR)/arch/$(BPF_KARCH)/include \
	-I$(BPF_HEADERS_DIR)/arch/$(BPF_KARCH)/include/asm/mach-generic \
	-I$(BPF_HEADERS_DIR)/arch/$(BPF_KARCH)/include/generated \
	-I$(BPF_HEADERS_DIR)/include \
	-I$(BPF_HEADERS_DIR)/arch/$(BPF_KARCH)/include/uapi \
	-I$(BPF_HEADERS_DIR)/arch/$(BPF_KARCH)/include/generated/uapi \
	-I$(BPF_HEADERS_DIR)/include/uapi \
	-I$(BPF_HEADERS_DIR)/include/generated/uapi \
	-I$(BPF_HEADERS_DIR)/tools/lib \
	-I$(BPF_HEADERS_DIR)/tools/testing/selftests \
	-I$(BPF_HEADERS_DIR)/samples/bpf \
	-include linux/kconfig.h -include asm_goto_workaround.h

BPF_CFLAGS := \
	$(BPF_KERNEL_INCLUDE) -I$(PKG_BUILD_DIR) \
	-D__KERNEL__ -D__BPF_TRACING__ \
	-D__TARGET_ARCH_${BPF_KARCH} \
	-m$(if $(CONFIG_BIG_ENDIAN),big,little)-endian \
	-fno-stack-protector -Wall \
	-Wno-unused-value -Wno-pointer-sign \
	-Wno-compare-distinct-pointer-types \
	-Wno-gnu-variable-sized-type-not-at-end \
	-Wno-address-of-packed-member -Wno-tautological-compare \
	-Wno-unknown-warning-option \
	-fno-asynchronous-unwind-tables \
	-Wno-uninitialized -Wno-unused-variable \
	-Wno-unused-label \
	-O2 -emit-llvm -Xclang -disable-llvm-passes

define CompileBPF
	$(CLANG) -g -target $(BPF_ARCH)-linux-gnu $(BPF_CFLAGS) $(2) \
		-c $(1) -o $(patsubst %.c,%.bc,$(1))
	$(LLVM_OPT) -O2 -mtriple=bpf-pc-linux < $(patsubst %.c,%.bc,$(1)) > $(patsubst %.c,%.opt,$(1))
	$(LLVM_DIS) < $(patsubst %.c,%.opt,$(1)) > $(patsubst %.c,%.S,$(1))
	$(LLVM_LLC) -march=bpf -filetype=obj -o $(patsubst %.c,%.o,$(1)) < $(patsubst %.c,%.S,$(1))
	$(LLVM_STRIP) --strip-debug $(patsubst %.c,%.o,$(1))
endef

