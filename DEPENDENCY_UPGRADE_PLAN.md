# Dependency Upgrade Plan - v0.2.0

## Decision
**Date:** 2026-01-06
**Status:** Approved - Upgrade to latest versions immediately

## Summary
Upgrade all major dependencies to their latest versions, including migrating away from discontinued packages.

## Outdated Dependencies Analysis

### Critical Issues
1. **dio_cache_interceptor_file_store** - DISCONTINUED
   - Current: 1.2.3
   - Status: Discontinued (replaced by http_cache_file_store)
   - Action: Migrate to http_cache_file_store

### Direct Dependencies
1. **dio_cache_interceptor**: 3.5.1 → 4.0.5
   - Type: Major version upgrade (breaking changes)
   - Breaking changes:
     - Replaced `hitCacheOnErrorExcept` with `hitCacheOnErrorCodes` and `hitCacheOnNetworkFailure`
     - Stores now save response status codes (auto-migration)
     - Stores are fully agnostic and don't rely on dio_cache_interceptor package
     - Minimum Dart SDK raised to 3.0.0
   - References: [dio_cache_interceptor changelog](https://pub.dev/packages/dio_cache_interceptor/changelog)

2. **flutter_secure_storage**: 9.2.4 → 10.0.0
   - Type: Major version upgrade (breaking changes)
   - Breaking changes:
     - Android: Minimum SDK 19 → 23
     - Android: Deprecated `encryptedSharedPreferences`, migrated to Google Tink Crypto
     - iOS: Minimum version 9 → 12
     - macOS: Minimum version 10.14
     - Minimum Dart SDK: 3.3.0, Flutter: 3.19.0
     - Default ciphers changed
     - Automatic migration for existing data
   - References: [flutter_secure_storage changelog](https://pub.dev/packages/flutter_secure_storage/changelog)

### Dev Dependencies
3. **flutter_lints**: 3.0.2 → 6.0.0
   - Type: Major version upgrade
   - Impact: Linting rules may be stricter
   - Risk: Low (dev dependency, may require code style fixes)

4. **test**: 1.26.3 → 1.28.0
   - Type: Minor version upgrade
   - Risk: Low (minor version, should be compatible)

## Migration Tasks

### Phase 1: File Store Migration
- [ ] Replace `dio_cache_interceptor_file_store` with `http_cache_file_store`
- [ ] Update imports in `lib/src/cache/encrypted_cache_store.dart`
- [ ] Update imports in `test/cache/encrypted_cache_store_test.dart`
- [ ] Verify API compatibility
- [ ] Test cache functionality

### Phase 2: dio_cache_interceptor Upgrade
- [ ] Update pubspec.yaml: `dio_cache_interceptor: ^4.0.5`
- [ ] Search for usage of `hitCacheOnErrorExcept` and replace with new API
- [ ] Review cache configuration code
- [ ] Update tests for API changes
- [ ] Verify cache store compatibility with 4.x

### Phase 3: flutter_secure_storage Upgrade
- [ ] Update pubspec.yaml: `flutter_secure_storage: ^10.0.0`
- [ ] Review usage of secure storage (currently in EncryptedCacheStore)
- [ ] Test on all platforms (Android, iOS, macOS, Web, Windows, Linux)
- [ ] Verify automatic migration works correctly
- [ ] Test encryption key storage and retrieval

### Phase 4: Dev Dependencies
- [ ] Update pubspec.yaml: `flutter_lints: ^6.0.0`
- [ ] Update pubspec.yaml: `test: ^1.28.0`
- [ ] Run `dart fix --apply` to auto-fix lint issues
- [ ] Fix any remaining lint warnings manually
- [ ] Ensure all tests pass

### Phase 5: Testing
- [ ] Run full test suite: `flutter test`
- [ ] Test on multiple platforms
- [ ] Test cache encryption/decryption
- [ ] Test token storage
- [ ] Test example app
- [ ] Run `dart pub publish --dry-run`

### Phase 6: Documentation
- [ ] Update CHANGELOG.md with breaking changes
- [ ] Update version to 0.2.0 in pubspec.yaml
- [ ] Update README if needed
- [ ] Create migration guide for users

## Risks & Mitigation

| Risk | Mitigation |
|------|-----------|
| Breaking changes affect users | Document all changes in CHANGELOG.md and migration guide |
| Cache data incompatibility | Test migration path, document cache clearing if needed |
| Platform-specific issues | Test on all supported platforms |
| Test failures | Fix issues before release |

## Dependencies to Update

```yaml
dependencies:
  dio_cache_interceptor: ^4.0.5  # was ^3.5.0
  # Remove: dio_cache_interceptor_file_store: ^1.2.3
  http_cache_file_store: ^1.1.0  # New dependency (replacement)
  flutter_secure_storage: ^10.0.0  # was ^9.0.0

dev_dependencies:
  flutter_lints: ^6.0.0  # was ^3.0.1
  test: ^1.28.0  # was ^1.24.9
```

## Timeline
- Immediate: Start migration work
- Target: Complete before next release (v0.2.0)

## References
- [dio_cache_interceptor changelog](https://pub.dev/packages/dio_cache_interceptor/changelog)
- [flutter_secure_storage changelog](https://pub.dev/packages/flutter_secure_storage/changelog)
- [http_cache_file_store package](https://pub.dev/packages/http_cache_file_store)
- [dio_cache_interceptor_file_store (discontinued)](https://pub.dev/packages/dio_cache_interceptor_file_store)
