# Makefile for PHP Security Scanner

# Directory paths
INPUT_DIR := .
OUTPUT_DIR := ../../output/php_security_scan

# Python executable
PYTHON := python3

# Scanner script
SCANNER := php_security_scanner.py

# Find all PHP files
PHP_FILES := $(wildcard *.php)
OUTPUT_FILES := $(PHP_FILES:%.php=$(OUTPUT_DIR)/%.txt)

.PHONY: all clean scan

all: scan

scan: $(OUTPUT_FILES)

$(OUTPUT_DIR)/%.txt: %.php
	@echo "Scanning $<..."
	@mkdir -p $(OUTPUT_DIR)
	@chmod +x $(SCANNER)
	@$(PYTHON) $(SCANNER) $< $@

clean:
	@echo "Cleaning up output directory..."
	@rm -rf $(OUTPUT_DIR)
	@echo "Clean complete" 