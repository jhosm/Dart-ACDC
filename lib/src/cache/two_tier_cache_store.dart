import 'dart:async';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

/// A two-tier cache store combining in-memory LRU and persistent storage.
///
/// Provides fast in-memory access with persistent backup:
/// - First tier: In-memory LRU cache (MemCacheStore)
/// - Second tier: Persistent storage (encrypted or unencrypted)
///
/// Features:
/// - Fast reads from memory
/// - Automatic promotion from disk to memory on access
/// - LRU eviction from memory tier
/// - Writes go to both tiers
/// - Graceful degradation if persistent storage fails
class TwoTierCacheStore implements CacheStore {
  /// Creates a two-tier cache store.
  ///
  /// [memoryStore]: Fast in-memory cache (first tier)
  /// [persistentStore]: Slower persistent cache (second tier, optional)
  TwoTierCacheStore({
    required this.memoryStore,
    this.persistentStore,
  });

  /// First tier: In-memory cache for fast access.
  final CacheStore memoryStore;

  /// Second tier: Persistent cache for durability (optional).
  ///
  /// If null, acts as memory-only cache.
  final CacheStore? persistentStore;

  @override
  Future<void> clean({
    CachePriority priorityOrBelow = CachePriority.high,
    bool staleOnly = false,
  }) async {
    // Clean both tiers
    await Future.wait([
      memoryStore.clean(priorityOrBelow: priorityOrBelow, staleOnly: staleOnly),
      if (persistentStore != null)
        persistentStore!
            .clean(priorityOrBelow: priorityOrBelow, staleOnly: staleOnly)
            .catchError((_) => null), // Gracefully ignore persistent errors
    ]);
  }

  @override
  Future<void> close() async {
    // Close both tiers
    await Future.wait([
      memoryStore.close(),
      if (persistentStore != null)
        persistentStore!.close().catchError((_) => null),
    ]);
  }

  @override
  Future<void> delete(String key, {bool staleOnly = false}) async {
    // Delete from both tiers
    await Future.wait([
      memoryStore.delete(key, staleOnly: staleOnly),
      if (persistentStore != null)
        persistentStore!
            .delete(key, staleOnly: staleOnly)
            .catchError((_) => null),
    ]);
  }

  @override
  Future<void> deleteFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async {
    // Delete from both tiers
    await Future.wait([
      memoryStore.deleteFromPath(pathPattern, queryParams: queryParams),
      if (persistentStore != null)
        persistentStore!
            .deleteFromPath(pathPattern, queryParams: queryParams)
            .catchError((_) => null),
    ]);
  }

  @override
  Future<bool> exists(String key) async {
    // Check memory first (fast)
    if (await memoryStore.exists(key)) {
      return true;
    }

    // Check persistent store
    if (persistentStore != null) {
      try {
        return await persistentStore!.exists(key);
      } on Exception catch (_) {
        return false;
      }
    }

    return false;
  }

  @override
  Future<CacheResponse?> get(String key) async {
    // Try memory first (fast path)
    var response = await memoryStore.get(key);
    if (response != null) {
      return response;
    }

    // Try persistent store (slower path)
    if (persistentStore != null) {
      try {
        response = await persistentStore!.get(key);
        if (response != null) {
          // Promote to memory cache for faster future access
          await memoryStore.set(response).catchError((_) => null);
          return response;
        }
      } on Exception catch (_) {
        // Gracefully handle persistent storage errors
        return null;
      }
    }

    return null;
  }

  @override
  Future<List<CacheResponse>> getFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async {
    // Get from both tiers and merge
    final results = await Future.wait([
      memoryStore.getFromPath(pathPattern, queryParams: queryParams),
      if (persistentStore != null)
        persistentStore!
            .getFromPath(pathPattern, queryParams: queryParams)
            .catchError((_) => <CacheResponse>[]),
    ]);

    // Merge results, removing duplicates by key
    final seen = <String>{};
    final merged = <CacheResponse>[];

    for (final responses in results) {
      for (final response in responses) {
        if (!seen.contains(response.key)) {
          seen.add(response.key);
          merged.add(response);
        }
      }
    }

    return merged;
  }

  @override
  Future<void> set(CacheResponse response) async {
    // Write to both tiers
    // Memory write is critical, persistent is best-effort
    await memoryStore.set(response);

    if (persistentStore != null) {
      // Fire-and-forget write to persistent store
      // Don't block on persistent storage failures
      unawaited(persistentStore!.set(response).catchError((_) => null));
    }
  }

  @override
  bool pathExists(
    String url,
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) {
    if (!pathPattern.hasMatch(url)) return false;

    var hasMatch = true;

    final uri = Uri.parse(url);
    if (queryParams != null) {
      for (final entry in queryParams.entries) {
        hasMatch &= uri.queryParameters.containsKey(entry.key);
        if (entry.value != null) {
          hasMatch &= uri.queryParameters[entry.key] == entry.value;
        }
        if (!hasMatch) break;
      }
    }

    return hasMatch;
  }
}
