# Tools
PYTHON = python3
SCANNER = ./java_security_scanner.py

# Directories
OUTPUT_DIR = ../../output/java_security_scan
SOURCE_DIR = src/main/java/com/example

# Targets
.PHONY: all clean scan

all: scan

$(OUTPUT_DIR):
	@mkdir -p $(OUTPUT_DIR)

scan: $(OUTPUT_DIR)
	@echo "Running Java security scanner..."
	@chmod +x $(SCANNER)
	@cd $(SOURCE_DIR) && \
	for file in *.java; do \
		if [ -f "$$file" ]; then \
			basename=$$(basename $$file .java); \
			$(PYTHON) ../../../../../$(SCANNER) $$file ../../../../../$(OUTPUT_DIR)/$$basename\_security_report.txt; \
			echo "Scanned $$file"; \
		fi \
	done
	@echo "Java security scanning complete. Reports saved in $(OUTPUT_DIR)/"

clean:
	rm -rf $(OUTPUT_DIR)
	@echo "Cleaned output directory" 