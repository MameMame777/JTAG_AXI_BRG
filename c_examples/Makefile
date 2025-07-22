# Makefile for Digilent USB-JTAG Custom Control Program
# Author: FPGA Engineer
# Date: 2025-07-23
# Description: Build system for C program using Digilent Adept library

# Compiler settings
CC = gcc
CFLAGS = -Wall -Wextra -O2 -std=c99

# Target executable
TARGET = digilent_jtag_control

# Source files
SOURCES = digilent_jtag_control.c

# Object files
OBJECTS = $(SOURCES:.c=.o)

# Digilent Adept library paths (adjust based on installation)
ifeq ($(OS),Windows_NT)
    # Windows paths
    ADEPT_PATH = C:/Program Files/Digilent/Adept
    INCLUDES = -I"$(ADEPT_PATH)/Include"
    LIBS = -L"$(ADEPT_PATH)/Lib" -ldjtg -ldmgr
    TARGET := $(TARGET).exe
else
    # Linux paths
    ADEPT_PATH = /usr/local/lib/digilent/adept
    INCLUDES = -I/usr/local/include/digilent
    LIBS = -L$(ADEPT_PATH) -ldjtg -ldmgr -lpthread
endif

# Build rules
all: $(TARGET)

$(TARGET): $(OBJECTS)
	@echo "Linking $(TARGET)..."
	$(CC) $(OBJECTS) $(LIBS) -o $(TARGET)
	@echo "Build completed: $(TARGET)"

%.o: %.c
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
ifeq ($(OS),Windows_NT)
	del /f $(OBJECTS) $(TARGET) 2>nul || true
else
	rm -f $(OBJECTS) $(TARGET)
endif
	@echo "Clean completed"

# Install Digilent Adept Runtime (informational)
install-adept:
	@echo "To install Digilent Adept Runtime:"
	@echo "1. Download from: https://reference.digilentinc.com/software/adept/start"
	@echo "2. Install the Adept Runtime package for your OS"
	@echo "3. Verify installation by running 'dadutil enum' command"

# Test connectivity
test:
	@echo "Testing USB-JTAG connectivity..."
	./$(TARGET) test

# Example usage
examples:
	@echo "Example usage:"
	@echo "  make run-test     - Run LED pattern test"
	@echo "  make run-write    - Write LED pattern"
	@echo "  make run-read     - Read LED register"

run-test: $(TARGET)
	./$(TARGET) test

run-write: $(TARGET)
	./$(TARGET) write 0xF

run-read: $(TARGET)
	./$(TARGET) read

# Help
help:
	@echo "Digilent USB-JTAG Control Program Build System"
	@echo "=============================================="
	@echo ""
	@echo "Targets:"
	@echo "  all           - Build the program (default)"
	@echo "  clean         - Clean build artifacts"
	@echo "  install-adept - Show Adept Runtime installation instructions"
	@echo "  test          - Test USB-JTAG connectivity"
	@echo "  examples      - Show usage examples"
	@echo "  help          - Show this help message"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - Digilent Adept Runtime installed"
	@echo "  - USB-JTAG device connected"
	@echo "  - FPGA programmed with JTAG-AXI bridge"

# Debug build
debug: CFLAGS += -g -DDEBUG
debug: $(TARGET)
	@echo "Debug build completed"

# Check Adept installation
check-adept:
	@echo "Checking Digilent Adept installation..."
ifeq ($(OS),Windows_NT)
	@if exist "$(ADEPT_PATH)" (echo "✓ Adept path found: $(ADEPT_PATH)") else (echo "✗ Adept not found, please install Adept Runtime")
else
	@if [ -d "$(ADEPT_PATH)" ]; then echo "✓ Adept path found: $(ADEPT_PATH)"; else echo "✗ Adept not found, please install Adept Runtime"; fi
endif

.PHONY: all clean install-adept test examples run-test run-write run-read help debug check-adept
