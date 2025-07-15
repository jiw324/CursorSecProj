# Makefile for Python Security Scanner

# Directory paths
INPUT_DIR := .
OUTPUT_DIR := ../../output/python_security_scan

# Python executable
PYTHON := python3

# Scanner script
SCANNER := python_security_scanner.py

# Find all Python files
PY_FILES := $(wildcard *.py)
OUTPUT_FILES := $(PY_FILES:%.py=$(OUTPUT_DIR)/%.txt)

.PHONY: all clean scan

all: scan

scan: $(OUTPUT_FILES)

$(OUTPUT_DIR)/%.txt: %.py
	@echo "Scanning $<..."
	@mkdir -p $(OUTPUT_DIR)
	@chmod +x $(SCANNER)
	@$(PYTHON) $(SCANNER) $< $@

clean:
	@echo "Cleaning up output directory..."
	@rm -rf $(OUTPUT_DIR)
	@echo "Clean complete" 