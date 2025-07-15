# Tools
PYTHON = python3
SCANNER = ./c_security_scanner.py

# Directories
OUTPUT_DIR = ../../output/c_security_scan

# Targets
.PHONY: all clean scan

all: scan

$(OUTPUT_DIR):
	@mkdir -p $(OUTPUT_DIR)

scan: $(OUTPUT_DIR)
	@echo "Running C security scanner..."
	@chmod +x $(SCANNER)
	@for file in *.c; do \
		if [ -f "$$file" ]; then \
			basename=$$(basename $$file .c); \
			$(SCANNER) $$file $(OUTPUT_DIR)/$$basename\_security_report.txt; \
			echo "Scanned $$file"; \
		fi \
	done
	@echo "C security scanning complete. Reports saved in $(OUTPUT_DIR)/"

clean:
	rm -rf $(OUTPUT_DIR)
	@echo "Cleaned output directory" 