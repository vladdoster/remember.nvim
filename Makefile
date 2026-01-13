.PHONY: test test-install test-coverage clean help

# Add local luarocks bin to PATH
export PATH := $(HOME)/.luarocks/bin:$(PATH)

# Default target
help:
	@echo "Available targets:"
	@echo "  test-install   - Install busted testing framework via luarocks"
	@echo "  test           - Run unit tests with busted"
	@echo "  test-coverage  - Run unit tests with coverage report"
	@echo "  clean          - Remove test artifacts"
	@echo "  help           - Show this help message"

# Install testing dependencies
test-install:
	@echo "Installing busted testing framework..."
	@luarocks install busted --local || echo "Note: Install luarocks first if not available"
	@echo "Installing luacov for coverage..."
	@luarocks install luacov --local || echo "Note: Install luarocks first if not available"

# Run tests
test:
	@echo "Running tests..."
	@busted tests/

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	@rm -f luacov.*.out
	@busted tests/ --coverage
	@if command -v luarocks > /dev/null 2>&1; then \
		eval $$(luarocks path) && luacov; \
	else \
		echo "Error: luarocks not found. Please install luarocks first."; \
		exit 1; \
	fi
	@echo ""
	@echo "Coverage report generated in luacov.report.out"
	@grep -A 5 "^Summary$$" luacov.report.out || true

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	@rm -f luacov.*.out
	@rm -f *.log
