# Root Makefile for Security Scanners

# Directories containing language-specific scanners
LANG_DIRS := input/C input/CPP input/Go input/Java input/JavaScript_TypeScript input/PHP input/Python input/Ruby input/Rust input/Scala

.PHONY: all clean $(LANG_DIRS)

all: $(LANG_DIRS)

# Run each language-specific scanner
$(LANG_DIRS):
	@echo "\nRunning security scanner for $(@F)..."
	@if [ -f $@/Makefile ]; then \
		$(MAKE) -C $@ scan || echo "Warning: Scanner for $(@F) failed"; \
	else \
		echo "No Makefile found for $(@F)"; \
	fi

# Clean all output directories
clean:
	@echo "Cleaning all output directories..."
	@for dir in $(LANG_DIRS); do \
		if [ -f $$dir/Makefile ]; then \
			echo "Cleaning $$dir..."; \
			$(MAKE) -C $$dir clean || echo "Warning: Clean failed for $$dir"; \
		fi \
	done
	@echo "Clean complete"

# Show status of scanners
status:
	@echo "\nScanner Status:"
	@for dir in $(LANG_DIRS); do \
		if [ -f $$dir/Makefile ]; then \
			echo "✓ $$dir: Scanner available"; \
		else \
			echo "✗ $$dir: No scanner found"; \
		fi \
	done 