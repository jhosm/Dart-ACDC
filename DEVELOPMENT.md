# Development Guide

## Local Validation

To ensure your changes pass CI checks before pushing, run validation locally using any of these methods:

### Option 1: Automatic (Git Hook) - Recommended

The pre-push hook automatically runs checks before each `git push`.

**Already installed!** The hook runs:
- ✅ Code formatting check
- ✅ Static analysis
- ✅ Tests

To bypass the hook (not recommended):
```bash
git push --no-verify
```

To disable tests in the hook (if they're too slow):
Edit `.git/hooks/pre-push` and comment out the test section.

### Option 2: Manual with Make

Run checks manually using make commands:

```bash
# Run all CI checks (doesn't fix formatting)
make ci

# Run all checks and auto-fix formatting
make check

# Individual checks
make format   # Format code
make analyze  # Run static analysis
make test     # Run tests
```

View all available commands:
```bash
make help
```

### Option 3: Simple Script

Run the validation script:

```bash
./scripts/check.sh
```

### Option 4: Individual Commands

Run each check manually:

```bash
# Check formatting (no changes)
dart format --output=none --set-exit-if-changed .

# Fix formatting
dart format .

# Run analyzer
dart analyze --fatal-warnings

# Run tests
flutter test
```

## Quick Fixes

### Formatting Issues
```bash
dart format .
```

### Analyzer Warnings
```bash
# See all issues
dart analyze

# Apply automated fixes
dart fix --apply
```

### Test Failures
```bash
# Run specific test file
flutter test test/path/to/test_file.dart

# Run tests with verbose output
flutter test --reporter expanded
```

## IDE Integration

### VS Code

Install the Dart extension, then:
1. Settings → Format On Save ✅
2. Settings → Dart: Line Length → 80
3. The analyzer runs automatically

### IntelliJ/Android Studio

1. Settings → Editor → Code Style → Dart → Set from: Dart Style Guide
2. Enable "Format on Save"
3. The analyzer runs automatically

## CI/CD Pipeline

The GitHub Actions CI runs:
- Code formatting validation
- Static analysis with `--fatal-warnings`
- Tests on Flutter 3.38.x and latest
- Cross-platform tests (Linux, macOS, Windows)
- Package quality checks

See `.github/workflows/ci.yml` for details.
