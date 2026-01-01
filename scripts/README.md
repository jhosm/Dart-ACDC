# Development Scripts

## Coverage Script

### Usage

Run tests with coverage reporting:

```bash
./scripts/coverage.sh
```

This script will:
1. Run all unit tests with coverage collection
2. Format coverage data to LCOV format
3. Display a coverage summary
4. Check that coverage meets the 80% threshold
5. Generate detailed coverage report at `coverage/lcov.info`

### Coverage Report

The LCOV format coverage report can be viewed:
- Directly in the terminal (summary)
- Using an IDE plugin (VSCode: Coverage Gutters)
- Using online LCOV viewers
- By generating HTML reports with `genhtml` (requires lcov tool)

### Requirements

- Dart SDK 3.0+
- `coverage` package (automatically installed globally on first run)

### Example Output

```
Running tests with coverage...
[Test output...]

Formatting coverage data to LCOV...

Coverage Summary:
================
Lines covered: 156 / 170
Coverage: 91.76%

✅ Coverage target met (>= 80%)

Detailed coverage report: coverage/lcov.info
```
