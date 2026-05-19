# bitfield.nvim — C component Makefile
#
# Usage:
#   make: build ./bitfield-parse binary
#   make clean: remove build artefacts
#   make install: copy binary next to this Makefile (already the default dest)
#
# Override LLVM_PATH if libclang is installed in a non-standard location:
#   LLVM_PATH=/usr/lib/llvm-17 make
 
CC := gcc
CFLAGS := -O2 -Wall -Wextra -std=c11
 
# libclang
ifdef LLVM_PATH
    LLVM_INC := $(LLVM_PATH)/include
    LLVM_LIB := $(LLVM_PATH)/lib
    CLANG_INC := -I$(LLVM_INC)
    CLANG_LIB := -L$(LLVM_LIB) -lclang
else
    # Try llvm-config first, fall back to system defaults
    LLVM_CONFIG := $(shell command -v llvm-config 2>/dev/null)
    ifdef LLVM_CONFIG
        CLANG_INC := $(shell $(LLVM_CONFIG) --cflags)
        CLANG_LIB := -L$(shell $(LLVM_CONFIG) --libdir) -lclang
    else
        CLANG_INC :=
        CLANG_LIB := -lclang
    endif
endif

TARGET := bitfield-parse
SRC := parser.c
 
.PHONY: all clean install
 
all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(CLANG_INC) -o $@ $< $(CLANG_LIB)

compile_commands:
	bear -- make clean all
	
clean:
	rm -f $(TARGET) *.o
 
install: all
	@echo "$(TARGET) ready at $(CURDIR)/$(TARGET)"
 