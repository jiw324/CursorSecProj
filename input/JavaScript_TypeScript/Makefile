# Tools
PYTHON = python3
SCANNER = ./js_ts_security_scanner.py

# Directories
OUTPUT_DIR = ../../output/js_ts_security_scan

# Targets
.PHONY: all clean scan-js scan-ts scan

all: scan

$(OUTPUT_DIR):
	@mkdir -p $(OUTPUT_DIR)

scan-js: $(OUTPUT_DIR)
	@echo "Running JavaScript security scanner..."
	@chmod +x $(SCANNER)
	@for file in *.js; do \
		if [ -f "$$file" ]; then \
			basename=$$(basename $$file .js); \
			$(SCANNER) $$file $(OUTPUT_DIR)/$$basename\_security_report.txt; \
			echo "Scanned $$file"; \
		fi \
	done
	@echo "JavaScript security scanning complete."

scan-ts: $(OUTPUT_DIR)
	@echo "Running TypeScript security scanner..."
	@chmod +x $(SCANNER)
	@for file in *.ts; do \
		if [ -f "$$file" ]; then \
			basename=$$(basename $$file .ts); \
			$(SCANNER) $$file $(OUTPUT_DIR)/$$basename\_security_report.txt; \
			echo "Scanned $$file"; \
		fi \
	done
	@echo "TypeScript security scanning complete."

scan: scan-js scan-ts
	@echo "All JavaScript and TypeScript security scans complete. Reports saved in $(OUTPUT_DIR)/"

clean:
	rm -rf $(OUTPUT_DIR)
	@echo "Cleaned output directory" 