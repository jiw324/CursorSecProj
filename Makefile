# Directories
C_DIR = input/C
OUTPUT_DIR = output
C_SCAN_DIR = $(OUTPUT_DIR)/c_security_scan

# Tools
PYTHON = python3
C_SCANNER = ./c_security_scanner.py

# Targets
.PHONY: all clean scan-c setup

all: scan-c

setup:
	@mkdir -p $(C_SCAN_DIR)

scan-c: setup
	@echo "Running C security scanner..."
	@for file in $(C_DIR)/*.c; do \
		basename=$$(basename $$file .c); \
		$(C_SCANNER) $$file $(C_SCAN_DIR)/$$basename\_security_report.txt; \
		echo "Scanned $$file"; \
	done
	@echo "C security scanning complete. Reports saved in $(C_SCAN_DIR)/"

clean:
	rm -rf $(OUTPUT_DIR)
	@echo "Cleaned output directory" 