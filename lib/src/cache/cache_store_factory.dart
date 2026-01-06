import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/cache/encrypted_cache_store.dart';
import 'package:dart_acdc/src/cache/two_tier_cache_store.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';

/// Factory for creating appropriate cache stores based on configuration.
///
/// This factory handles platform-specific cache store creation:
/// - On Web: Uses in-memory cache only (encrypted storage not supported)
/// - On Native: Uses encrypted persistent storage with optional memory tier
///
/// This separation allows cache interceptor logic to remain platform-agnostic.
class CacheStoreFactory {
  /// Builds the appropriate cache store based on configuration.
  ///
  /// Returns:
  /// - MemCacheStore: Always on Web (encrypted storage not supported)
  /// - TwoTierCacheStore: On native platforms when inMemory=true (combines in-memory and encrypted persistent cache)
  /// - EncryptedCacheStore: On native platforms when inMemory=false (encrypted persistent cache only)
  ///
  /// May propagate [StateError] from [EncryptedCacheStore]'s constructor if encryption initialization fails on native platforms.
  static CacheStore build(CacheConfig config) {
    // Web support: EncryptedCacheStore uses dart:io/File which is not supported on Web.
    // Fallback to in-memory cache for Web.
    if (kIsWeb) {
      return MemCacheStore(
        maxSize: config.inMemoryMaxSize,
      );
    }

    // Build persistent store (always encrypted)
    final persistentStore = EncryptedCacheStore(
      maxSize: config.maxSize,
      version: config.version,
      onError: config.onError,
      storePath: config.storePath,
    );

    // Build two-tier cache if inMemory is enabled
    if (config.inMemory) {
      final memoryStore = MemCacheStore(
        maxSize: config.inMemoryMaxSize,
      );

      // Two-tier: memory + encrypted persistent
      return TwoTierCacheStore(
        memoryStore: memoryStore,
        persistentStore: persistentStore,
      );
    }

    // Persistent-only cache (always encrypted)
    return persistentStore;
  }
}
