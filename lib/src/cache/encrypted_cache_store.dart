import 'dart:convert';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A cache store that encrypts data using platform secure storage.
///
/// Uses [FlutterSecureStorage] to encrypt and persist cache entries.
/// Implements LRU eviction when size limits are exceeded.
///
/// Features:
/// - Platform-level encryption (Keychain on iOS, KeyStore on Android)
/// - Automatic LRU eviction based on maxSize
/// - Graceful degradation on encryption failures
class EncryptedCacheStore implements CacheStore {
  /// Creates an encrypted cache store.
  ///
  /// [maxSize]: Maximum cache size in bytes (default: 10 MB)
  /// [storage]: Custom secure storage instance (mainly for testing)
  /// [version]: Cache version string (invalidation trigger)
  /// [onError]: Callback for internal errors
  EncryptedCacheStore({
    this.maxSize = 10 * 1024 * 1024, // 10 MB
    FlutterSecureStorage? storage,
    this.version,
    this.onError,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Maximum cache size in bytes.
  final int maxSize;

  /// Cache version string.
  final String? version;

  /// Error callback.
  final void Function(Object error, StackTrace stackTrace)? onError;

  static const String _keyPrefix = 'acdc_cache_';
  static const String _metadataKey = 'acdc_cache_metadata';
  static const String _versionKey = 'acdc_cache_version';

  /// Metadata for tracking cache entries (for LRU eviction).
  final Map<String, _CacheMetadata> _metadata = {};
  bool _metadataLoaded = false;

  @override
  Future<void> clean({
    CachePriority priorityOrBelow = CachePriority.high,
    bool staleOnly = false,
  }) async {
    try {
      await _loadMetadata();

      final now = DateTime.now();
      final keysToDelete = <String>[];

      for (final entry in _metadata.entries) {
        final shouldDelete = !staleOnly ||
            (entry.value.expiryDate != null &&
                entry.value.expiryDate!.isBefore(now));

        if (shouldDelete) {
          keysToDelete.add(entry.key);
        }
      }

      for (final key in keysToDelete) {
        await _deleteEntry(key);
      }

      await _saveMetadata();
    } on Exception catch (e, stack) {
      onError?.call(e, stack);
      // Silently fail on clean errors
    }
  }

  @override
  Future<void> close() async {
    // No resources to release
  }

  @override
  Future<void> delete(String key, {bool staleOnly = false}) async {
    try {
      await _loadMetadata();

      if (!_metadata.containsKey(key)) {
        return;
      }

      if (staleOnly) {
        final meta = _metadata[key];
        final now = DateTime.now();
        if (meta?.expiryDate == null || meta!.expiryDate!.isAfter(now)) {
          return;
        }
      }

      await _deleteEntry(key);
      await _saveMetadata();
    } on Exception catch (e, stack) {
      onError?.call(e, stack);
      // Silently fail on delete errors
    }
  }

  @override
  Future<void> deleteFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async {
    try {
      await _loadMetadata();

      final keysToDelete = <String>[];
      for (final key in _metadata.keys) {
        // Read the cached response to get its URL
        final response = await get(key);
        if (response != null &&
            pathExists(response.url, pathPattern, queryParams: queryParams)) {
          keysToDelete.add(key);
        }
      }

      for (final key in keysToDelete) {
        await _deleteEntry(key);
      }

      await _saveMetadata();
    } on Exception catch (e, stack) {
      onError?.call(e, stack);
      // Silently fail on delete errors
    }
  }

  @override
  Future<bool> exists(String key) async {
    try {
      await _loadMetadata();
      return _metadata.containsKey(key);
    } on Exception catch (e, stack) {
      onError?.call(e, stack);
      return false;
    }
  }

  @override
  Future<CacheResponse?> get(String key) async {
    try {
      await _loadMetadata();

      if (!_metadata.containsKey(key)) {
        return null;
      }

      // Update last accessed time (LRU)
      _metadata[key] = _metadata[key]!.copyWith(
        lastAccessed: DateTime.now(),
      );

      // Read encrypted data from secure storage
      final storageKey = _getStorageKey(key);
      final data = await _storage.read(key: storageKey);

      if (data == null) {
        // Entry exists in metadata but not in storage - clean up
        _metadata.remove(key);
        await _saveMetadata();
        return null;
      }

      // Deserialize cache response
      final json = jsonDecode(data) as Map<String, dynamic>;
      final response = _deserializeCacheResponse(json);

      await _saveMetadata();

      return response;
    } on Exception catch (e, stack) {
      // Return null on any error (encryption failure, deserialization, etc.)
      onError?.call(e, stack);
      return null;
    }
  }

  @override
  Future<List<CacheResponse>> getFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async {
    try {
      await _loadMetadata();

      final responses = <CacheResponse>[];
      for (final key in _metadata.keys) {
        final response = await get(key);
        if (response != null &&
            pathExists(response.url, pathPattern, queryParams: queryParams)) {
          responses.add(response);
        }
      }

      return responses;
    } on Exception catch (e, stack) {
      onError?.call(e, stack);
      return [];
    }
  }

  @override
  Future<void> set(CacheResponse response) async {
    try {
      await _loadMetadata();

      final key = response.key;
      final json = _serializeCacheResponse(response);
      final data = jsonEncode(json);
      final size = utf8.encode(data).length;

      // Evict entries if needed to make room
      await _evictIfNeeded(size);

      // Store encrypted data in secure storage
      final storageKey = _getStorageKey(key);
      await _storage.write(key: storageKey, value: data);

      // Update metadata
      _metadata[key] = _CacheMetadata(
        size: size,
        lastAccessed: DateTime.now(),
        expiryDate: response.maxStale,
      );

      await _saveMetadata();
    } on Exception catch (e, stack) {
      onError?.call(e, stack);
      // Silently fail on encryption errors
      // This allows graceful degradation when encryption is unavailable
    }
  }

  /// Calculates current total cache size.
  int get currentSize =>
      _metadata.values.fold(0, (sum, meta) => sum + meta.size);

  /// Evicts least recently used entries until there's enough space.
  Future<void> _evictIfNeeded(int requiredSpace) async {
    if (currentSize + requiredSpace <= maxSize) {
      return;
    }

    // Sort by last accessed (oldest first)
    final entries = _metadata.entries.toList()
      ..sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));

    // Evict until we have enough space
    for (final entry in entries) {
      if (currentSize + requiredSpace <= maxSize) {
        break;
      }

      await _deleteEntry(entry.key);
    }
  }

  /// Deletes a cache entry and updates metadata.
  Future<void> _deleteEntry(String key) async {
    try {
      final storageKey = _getStorageKey(key);
      await _storage.delete(key: storageKey);
      _metadata.remove(key);
    } on Exception catch (e, stack) {
      onError?.call(e, stack);
      // Ignore delete errors
    }
  }

  /// Loads metadata from secure storage.
  ///
  /// Also checks for version mismatch and invalidates cache if version changed.
  Future<void> _loadMetadata() async {
    if (_metadataLoaded) {
      return;
    }

    try {
      // Check version first
      final storedVersion = await _storage.read(key: _versionKey);

      // If version mismatch, clear everything
      if (version != null && storedVersion != version) {
        await _storage.deleteAll();
        await _storage.write(key: _versionKey, value: version);
        _metadata.clear();
        _metadataLoaded = true;
        return;
      }

      // Also write version if not present (first run with versioning)
      if (version != null && storedVersion == null) {
        await _storage.write(key: _versionKey, value: version);
      }

      final data = await _storage.read(key: _metadataKey);
      if (data != null) {
        final json = jsonDecode(data) as Map<String, dynamic>;
        _metadata.clear();
        for (final entry in json.entries) {
          _metadata[entry.key] = _CacheMetadata.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
      _metadataLoaded = true;
    } on Exception catch (e, stack) {
      // If metadata loading fails, start fresh but report error
      onError?.call(e, stack);
      _metadata.clear();
      _metadataLoaded = true;
    }
  }

  /// Saves metadata to secure storage.
  Future<void> _saveMetadata() async {
    try {
      final json = <String, dynamic>{};
      for (final entry in _metadata.entries) {
        json[entry.key] = entry.value.toJson();
      }
      final data = jsonEncode(json);
      await _storage.write(key: _metadataKey, value: data);
    } on Exception catch (e, stack) {
      onError?.call(e, stack);
      // Ignore metadata save errors
    }
  }

  /// Gets the storage key for a cache key.
  String _getStorageKey(String key) => '$_keyPrefix$key';

  /// Serializes a CacheResponse to JSON.
  Map<String, dynamic> _serializeCacheResponse(CacheResponse response) => {
        'key': response.key,
        'url': response.url,
        'cacheControl': {
          'maxAge': response.cacheControl.maxAge,
          'privacy': response.cacheControl.privacy,
          'noCache': response.cacheControl.noCache,
          'noStore': response.cacheControl.noStore,
          'mustRevalidate': response.cacheControl.mustRevalidate,
          'maxStale': response.cacheControl.maxStale,
          'minFresh': response.cacheControl.minFresh,
          'other': response.cacheControl.other,
        },
        'content': response.content,
        'date': response.date?.toIso8601String(),
        'eTag': response.eTag,
        'expires': response.expires?.toIso8601String(),
        'headers': response.headers,
        'lastModified': response.lastModified,
        'maxStale': response.maxStale?.toIso8601String(),
        'priority': response.priority.index,
        'requestDate': response.requestDate.toIso8601String(),
        'responseDate': response.responseDate.toIso8601String(),
      };

  /// Deserializes a CacheResponse from JSON.
  CacheResponse _deserializeCacheResponse(Map<String, dynamic> json) {
    final cacheControlJson = json['cacheControl'] as Map<String, dynamic>;
    final otherList = cacheControlJson['other'] as List<dynamic>?;
    return CacheResponse(
      key: json['key'] as String,
      url: json['url'] as String,
      cacheControl: CacheControl(
        maxAge: cacheControlJson['maxAge'] as int,
        privacy: cacheControlJson['privacy'] as String?,
        noCache: cacheControlJson['noCache'] as bool,
        noStore: cacheControlJson['noStore'] as bool,
        mustRevalidate: cacheControlJson['mustRevalidate'] as bool,
        maxStale: cacheControlJson['maxStale'] as int,
        minFresh: cacheControlJson['minFresh'] as int,
        other: otherList?.cast<String>() ?? [],
      ),
      content: (json['content'] as List<dynamic>?)?.cast<int>(),
      date:
          json['date'] != null ? DateTime.parse(json['date'] as String) : null,
      eTag: json['eTag'] as String?,
      expires: json['expires'] != null
          ? DateTime.parse(json['expires'] as String)
          : null,
      headers: (json['headers'] as List<dynamic>?)?.cast<int>(),
      lastModified: json['lastModified'] as String?,
      maxStale: json['maxStale'] != null
          ? DateTime.parse(json['maxStale'] as String)
          : null,
      priority: CachePriority.values[json['priority'] as int],
      requestDate: DateTime.parse(json['requestDate'] as String),
      responseDate: DateTime.parse(json['responseDate'] as String),
    );
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

/// Metadata for tracking cache entries.
class _CacheMetadata {
  const _CacheMetadata({
    required this.size,
    required this.lastAccessed,
    this.expiryDate,
  });
  factory _CacheMetadata.fromJson(Map<String, dynamic> json) => _CacheMetadata(
        size: json['size'] as int,
        lastAccessed: DateTime.parse(json['lastAccessed'] as String),
        expiryDate: json['expiryDate'] != null
            ? DateTime.parse(json['expiryDate'] as String)
            : null,
      );

  final int size;
  final DateTime lastAccessed;
  final DateTime? expiryDate;

  _CacheMetadata copyWith({
    int? size,
    DateTime? lastAccessed,
    DateTime? expiryDate,
  }) =>
      _CacheMetadata(
        size: size ?? this.size,
        lastAccessed: lastAccessed ?? this.lastAccessed,
        expiryDate: expiryDate ?? this.expiryDate,
      );

  Map<String, dynamic> toJson() => {
        'size': size,
        'lastAccessed': lastAccessed.toIso8601String(),
        if (expiryDate != null) 'expiryDate': expiryDate!.toIso8601String(),
      };
}
