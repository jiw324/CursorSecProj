# Go Makefile

# Directories
BUILD_DIR=../../build/Go
OUTPUT_DIR=../../output/Go_security_scan

# Source files
SOURCES=$(wildcard *.go)
TARGETS=$(SOURCES:%.go=$(BUILD_DIR)/%)

# Go environment
export GOBIN=$(shell go env GOPATH)/bin
export PATH:=$(GOBIN):$(PATH)

# Create directories if they don't exist
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

# Ensure required tools are installed
install-tools:
	@echo "Installing/updating Go tools..."
	@go install github.com/securego/gosec/v2/cmd/gosec@latest
	@go install honnef.co/go/tools/cmd/staticcheck@latest
	@echo "Verifying tools..."
	@which gosec
	@which staticcheck

# Build each Go file separately
$(BUILD_DIR)/%: %.go | $(BUILD_DIR)
	go build -o $@ $<

all: install-tools $(BUILD_DIR) $(OUTPUT_DIR) $(TARGETS)
	python3 go_security_scanner.py . $(OUTPUT_DIR)

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(OUTPUT_DIR)
	go clean

.PHONY: all clean install-tools 