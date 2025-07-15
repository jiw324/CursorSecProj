# Makefile for Rust Security Scanner

# Directory paths
INPUT_DIR := .
OUTPUT_DIR := ../../output/rust_security_scan

# Python executable
PYTHON := python3

# Scanner script
SCANNER := rust_security_scanner.py

# Find all Rust files
RS_FILES := $(wildcard *.rs)
OUTPUT_FILES := $(RS_FILES:%.rs=$(OUTPUT_DIR)/%.txt)

.PHONY: all clean scan

all: scan

scan: $(OUTPUT_FILES)

$(OUTPUT_DIR)/%.txt: %.rs
	@echo "Scanning $<..."
	@mkdir -p $(OUTPUT_DIR)
	@chmod +x $(SCANNER)
	@$(PYTHON) $(SCANNER) $< $@

clean:
	@echo "Cleaning up output directory..."
	@rm -rf $(OUTPUT_DIR)
	@echo "Clean complete" 