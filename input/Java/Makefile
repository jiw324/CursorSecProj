# Java Makefile

# Directories
BUILD_DIR=../../build/Java
OUTPUT_DIR=../../output/Java_security_scan

# Java environment
export JAVA_HOME=/opt/homebrew/Cellar/openjdk/24.0.1/libexec/openjdk.jdk/Contents/Home
export PATH:=$(JAVA_HOME)/bin:$(PATH)

all: $(BUILD_DIR) $(OUTPUT_DIR)
	@echo "Using Java at: $$(which java)"
	@java -version
	mvn clean compile
	python3 java_security_scanner.py . $(OUTPUT_DIR)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

clean:
	mvn clean
	rm -rf $(BUILD_DIR)
	rm -rf $(OUTPUT_DIR)

.PHONY: all clean 