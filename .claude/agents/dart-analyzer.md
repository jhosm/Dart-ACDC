# Dart Analyzer Agent

Run `dart analyze --fatal-warnings` on the codebase and fix all issues.

## Instructions

1. Run `dart analyze --fatal-warnings` and capture output
2. For each issue, read the file and fix it
3. Pay special attention to:
   - Missing doc comments on public APIs (`public_member_api_docs`)
   - Strict type inference violations (`strict-casts`, `strict-inference`, `strict-raw-types`)
   - Package import rules (`always_use_package_imports`, never relative)
   - Required trailing commas (`require_trailing_commas`)
   - Single quotes (`prefer_single_quotes`)
4. After fixing, run `dart format .` to ensure formatting is correct
5. Re-run `dart analyze --fatal-warnings` to verify all issues are resolved
6. Report what was fixed
