#!/bin/bash
# Script to run tests with coverage and generate reports

set -e

echo "Running tests with coverage..."
dart test --coverage=coverage

echo ""
echo "Formatting coverage data to LCOV..."
export PATH="$PATH:$HOME/.pub-cache/bin"
dart pub global run coverage:format_coverage \
  --lcov \
  --in=coverage \
  --out=coverage/lcov.info \
  --packages=.dart_tool/package_config.json \
  --report-on=lib

echo ""
echo "Generating HTML coverage report..."
genhtml coverage/lcov.info -o coverage/html

echo ""
echo "Coverage Summary:"
echo "================"

# Parse LCOV file and calculate coverage
total_lines=0
hit_lines=0

while IFS= read -r line; do
  if [[ $line == LF:* ]]; then
    total_lines=$((total_lines + ${line#LF:}))
  elif [[ $line == LH:* ]]; then
    hit_lines=$((hit_lines + ${line#LH:}))
  fi
done < coverage/lcov.info

if [ $total_lines -gt 0 ]; then
  coverage=$(awk "BEGIN {printf \"%.2f\", ($hit_lines / $total_lines) * 100}")
  echo "Lines covered: $hit_lines / $total_lines"
  echo "Coverage: ${coverage}%"
  echo ""

  if (( $(echo "$coverage >= 80" | bc -l) )); then
    echo "✅ Coverage target met (>= 80%)"
  else
    echo "❌ Coverage below target (< 80%)"
    exit 1
  fi
else
  echo "No coverage data found"
  exit 1
fi

echo ""
echo "Detailed coverage report: coverage/lcov.info"
