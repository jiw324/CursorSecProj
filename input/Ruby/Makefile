# Makefile for Ruby Security Scanner

# Directory paths
INPUT_DIR := .
OUTPUT_DIR := ../../output/ruby_security_scan

# Python executable
PYTHON := python3

# Scanner script
SCANNER := ruby_security_scanner.py

# Find all Ruby files
RB_FILES := $(wildcard *.rb)
OUTPUT_FILES := $(RB_FILES:%.rb=$(OUTPUT_DIR)/%.txt)

.PHONY: all clean scan

all: scan

scan: $(OUTPUT_FILES)

$(OUTPUT_DIR)/%.txt: %.rb
	@echo "Scanning $<..."
	@mkdir -p $(OUTPUT_DIR)
	@chmod +x $(SCANNER)
	@$(PYTHON) $(SCANNER) $< $@

clean:
	@echo "Cleaning up output directory..."
	@rm -rf $(OUTPUT_DIR)
	@echo "Clean complete" 