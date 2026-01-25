.PHONY: help check format analyze test ci install-hooks

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

check: format analyze test ## Run all checks (format, analyze, test)

format: ## Check and apply code formatting
	@echo "📝 Formatting code..."
	@dart format .

analyze: ## Run static analysis
	@echo "🔬 Running static analysis..."
	@dart analyze --fatal-warnings

test: ## Run all tests
	@echo "🧪 Running tests..."
	@flutter test

ci: ## Run all CI checks locally (without fixing formatting)
	@echo "🔍 Running CI validation locally..."
	@echo ""
	@echo "📝 Checking code formatting..."
	@dart format --output=none --set-exit-if-changed .
	@echo "✅ Formatting check passed"
	@echo ""
	@echo "🔬 Running static analysis..."
	@dart analyze --fatal-warnings
	@echo "✅ Static analysis passed"
	@echo ""
	@echo "🧪 Running tests..."
	@flutter test
	@echo "✅ Tests passed"
	@echo ""
	@echo "✨ All CI checks passed!"

install-hooks: ## Install git hooks
	@echo "Installing git hooks..."
	@cp -f hooks/pre-push .git/hooks/pre-push
	@chmod +x .git/hooks/pre-push
	@echo "✅ Git hooks installed!"
