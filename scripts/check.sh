#!/bin/bash
# Quick validation script - run before committing

set -e  # Exit on first error

echo "🔍 Running local validation checks..."
echo ""

# Format check
echo "📝 Checking formatting..."
dart format --output=none --set-exit-if-changed .
echo "✅ Formatting OK"
echo ""

# Analyze
echo "🔬 Running analyzer..."
dart analyze --fatal-warnings
echo "✅ Analysis OK"
echo ""

# Tests
echo "🧪 Running tests..."
flutter test --reporter compact
echo "✅ Tests OK"
echo ""

echo "✨ All checks passed! Safe to commit/push."
