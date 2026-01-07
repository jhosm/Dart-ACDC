import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:path_provider/path_provider.dart';

/// A cache store that encrypts data before persisting to disk.
///
/// Wraps a [FileCacheStore] and uses AES-GCM encryption for content.
/// The encryption key is managed by [FlutterSecureStorage].
///
/// Features:
/// - AES-GCM encryption (256-bit key)
/// - Key storage in platform secure storage (Keychain/KeyStore)
/// - File-based persistence
/// - Automatic key generation
class EncryptedCacheStore implements CacheStore {
  /// Creates an encrypted cache store.
  ///
  /// [storePath]: Path to store cache files. If null, uses application documents directory.
  /// [storage]: Custom secure storage instance (mainly for testing).
  /// [clean]: Whether to clean the store on opening.
  /// Creates an encrypted cache store.
  ///
  /// [storePath]: Path to store cache files. If null, uses application documents directory.
  /// [storage]: Custom secure storage instance (mainly for testing).
  /// [clean]: Whether to clean the store on opening.
  /// [maxSize]: Maximum cache size in bytes (currently unused for file store, standard is 10 MB).
  /// [version]: Cache version string. If changes, cache is cleared.
  /// [onError]: Callback for internal errors.
  EncryptedCacheStore({
    this.storePath,
    FlutterSecureStorage? storage,
    this.cleanStore = false,
    this.maxSize = 10 * 1024 * 1024, // 10 MB
    this.version,
    this.onError,
  }) : _secureStorage = storage ?? const FlutterSecureStorage();

  /// Path to store cache files.
  final String? storePath;

  /// Custom secure storage instance.
  final FlutterSecureStorage _secureStorage;

  /// Whether to clean the store on opening.
  final bool cleanStore;

  /// Maximum cache size (not strictly enforced by FileCacheStore wrapper currently).
  final int maxSize;

  /// Cache version string.
  final String? version;

  /// Error callback.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// The underlying file store.
  FileCacheStore? _fileStore;

  /// The encrypter instance.
  // ignore: use_late_for_private_fields_and_variables
  Encrypter? _encrypter;

  /// Future to track initialization.
  Future<void>? _initFuture;

  static const String _keyStorageKey = 'acdc_cache_encryption_key';
  static const String _versionStorageKey = 'acdc_cache_version';

  /// Ensures that file store and encryption are initialized.
  Future<void> _ensureInitialized() async {
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    _initFuture = _initialize();
    await _initFuture;
  }

  Future<void> _initialize() async {
    try {
      // 1. Initialize path
      final path = storePath ?? (await getApplicationDocumentsDirectory()).path;
      final cacheDir = Directory('$path/acdc_cache');
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }
      _fileStore = FileCacheStore(cacheDir.path);

      if (cleanStore) {
        await _fileStore!.clean();
      }

      // 2. Check version
      final storedVersion = await _secureStorage.read(key: _versionStorageKey);
      if (version != null && storedVersion != version) {
        // Version mismatch - clear cache
        await _fileStore!.clean();
        await _secureStorage.write(key: _versionStorageKey, value: version);
      } else if (version != null && storedVersion == null) {
        await _secureStorage.write(key: _versionStorageKey, value: version);
      }

      // 3. Initialize encryption key
      final keyBytes = await _getOrGenerateKey(_secureStorage);
      _encrypter = Encrypter(AES(Key(keyBytes), mode: AESMode.gcm));
    } catch (e, stack) {
      onError?.call(e, stack);
      // If initialization fails, we might want to rethrow or handle it
      // For now, let it propagate so calls fail
      rethrow;
    }
  }

  /// Gets existing key or generates a new one.
  static Future<Uint8List> _getOrGenerateKey(
    FlutterSecureStorage storage,
  ) async {
    var base64Key = await storage.read(key: _keyStorageKey);

    if (base64Key == null) {
      final key = Key.fromSecureRandom(32); // 256 bits
      base64Key = base64Url.encode(key.bytes);
      await storage.write(key: _keyStorageKey, value: base64Key);
      return key.bytes;
    }

    return base64Url.decode(base64Key);
  }

  @override
  Future<void> clean({
    CachePriority priorityOrBelow = CachePriority.high,
    bool staleOnly = false,
  }) async {
    await _ensureInitialized();
    return _fileStore!.clean(
      priorityOrBelow: priorityOrBelow,
      staleOnly: staleOnly,
    );
  }

  @override
  Future<void> close() async => _fileStore?.close();

  @override
  Future<void> delete(String key, {bool staleOnly = false}) async {
    await _ensureInitialized();
    return _fileStore!.delete(key, staleOnly: staleOnly);
  }

  @override
  Future<void> deleteFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async {
    await _ensureInitialized();
    return _fileStore!.deleteFromPath(pathPattern, queryParams: queryParams);
  }

  @override
  Future<bool> exists(String key) async {
    await _ensureInitialized();
    return _fileStore!.exists(key);
  }

  @override
  Future<CacheResponse?> get(String key) async {
    await _ensureInitialized();
    final response = await _fileStore!.get(key);
    if (response == null || response.content == null) {
      return response;
    }

    try {
      // Decrypt content
      final encryptedBytes = Uint8List.fromList(response.content!);
      // AES-GCM format: IV + Ciphertext + AuthTag
      // encrypt package handles this structure for GCM mode?
      // Actually, Encrypted.fromBase64 expects just the bytes if we manage IV manually
      // But AES-GCM needs IV (nonce).
      // Let's assume content was stored as: IV (12 bytes) + Encrypted Data

      // IMPORTANT: The encrypt package's AES-GCM implementation details:
      // When using `encrypter.encrypt(bytes)`, it returns an `Encrypted` object.
      // We should store IV + bytes.

      // Let's check how we store it in `set`.
      // We are storing deserialized bytes.

      final parts = _deserializeContent(encryptedBytes);
      final iv = IV(parts.iv);
      final encrypted = Encrypted(parts.ciphertext);

      final decrypted = _encrypter!.decryptBytes(encrypted, iv: iv);

      return response.copyWith(content: decrypted);
    } on Exception {
      // Decryption failed - treat as cache miss and delete corrupted entry
      await delete(key);
      return null;
    }
  }

  @override
  Future<List<CacheResponse>> getFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async {
    await _ensureInitialized();
    final responses = await _fileStore!.getFromPath(
      pathPattern,
      queryParams: queryParams,
    );

    final decryptedResponses = <CacheResponse>[];
    for (final response in responses) {
      if (response.content == null) {
        decryptedResponses.add(response);
        continue;
      }

      try {
        final encryptedBytes = Uint8List.fromList(response.content!);
        final parts = _deserializeContent(encryptedBytes);
        final iv = IV(parts.iv);
        final encrypted = Encrypted(parts.ciphertext);

        final decrypted = _encrypter!.decryptBytes(encrypted, iv: iv);
        decryptedResponses.add(response.copyWith(content: decrypted));
      } on Exception {
        // Skip corrupted entries
        await delete(response.key);
      }
    }

    return decryptedResponses;
  }

  @override
  Future<void> set(CacheResponse response) async {
    await _ensureInitialized();
    if (response.content == null) {
      return _fileStore!.set(response);
    }

    // Encrypt content
    final iv = IV.fromSecureRandom(12); // GCM standard IV size
    final encrypted = _encrypter!.encryptBytes(response.content!, iv: iv);

    // Store IV + Encrypted Data
    final serialized = _serializeContent(iv.bytes, encrypted.bytes);

    return _fileStore!.set(response.copyWith(content: serialized));
  }

  @override
  bool pathExists(
    String url,
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) {
    if (!pathPattern.hasMatch(url)) return false;

    if (queryParams != null && queryParams.isNotEmpty) {
      final uri = Uri.parse(url);
      for (final entry in queryParams.entries) {
        if (!uri.queryParameters.containsKey(entry.key)) return false;
        if (entry.value != null &&
            uri.queryParameters[entry.key] != entry.value) {
          return false;
        }
      }
    }

    return true;
  }

  // -- Helpers for byte manipulation --

  /// Combines IV and ciphertext into a single byte array.
  /// Format: [IV Length (1 byte)] [IV bytes] [Ciphertext bytes]
  Uint8List _serializeContent(Uint8List iv, Uint8List ciphertext) {
    final bb = BytesBuilder()
      ..addByte(iv.length)
      ..add(iv)
      ..add(ciphertext);
    return bb.toBytes();
  }

  /// Extracts IV and ciphertext from a byte array.
  ({Uint8List iv, Uint8List ciphertext}) _deserializeContent(Uint8List bytes) {
    final ivLength = bytes[0];
    final iv = bytes.sublist(1, 1 + ivLength);
    final ciphertext = bytes.sublist(1 + ivLength);
    return (iv: iv, ciphertext: ciphertext);
  }
}
