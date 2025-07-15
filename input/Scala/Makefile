# Makefile for Scala Security Scanner

# Directory paths
INPUT_DIR := .
OUTPUT_DIR := ../../output/scala_security_scan

# Python executable
PYTHON := python3

# Scanner script
SCANNER := scala_security_scanner.py

# Find all Scala files
SCALA_FILES := $(wildcard *.scala)
OUTPUT_FILES := $(SCALA_FILES:%.scala=$(OUTPUT_DIR)/%.txt)

.PHONY: all clean scan

all: scan

scan: $(OUTPUT_FILES)

$(OUTPUT_DIR)/%.txt: %.scala
	@echo "Scanning $<..."
	@mkdir -p $(OUTPUT_DIR)
	@chmod +x $(SCANNER)
	@$(PYTHON) $(SCANNER) $< $@

clean:
	@echo "Cleaning up output directory..."
	@rm -rf $(OUTPUT_DIR)
	@echo "Clean complete" 