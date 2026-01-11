import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utilities for handling X.509 Certificates and SPKI extraction.
class SpkiUtil {
  /// Extracts the SHA-256 hash of the Subject Public Key Info (SPKI) from an X.509 certificate.
  ///
  /// Returns the hash formatted as 'SHA256:<base64-string>'.
  static String extractSpkiHash(X509Certificate certificate) {
    try {
      final spkiBytes = _extractSpki(certificate.der);
      if (spkiBytes == null) {
        // Fallback or error? If we can't extract, we can't pin.
        // For now, let's assume if parsing fails we return a placeholder or throw.
        throw const FormatException('Failed to extract SPKI from certificate');
      }
      final digest = sha256.convert(spkiBytes);
      return 'SHA256:${base64.encode(digest.bytes)}';
    } catch (e) {
      // If parsing fails, we cannot verify against SPKI pins.
      // We explicitly rethrow so the verification logic knows it failed to process.
      throw const FormatException('Failed to calculate SPKI hash');
    }
  }

  /// Extracts the SubjectPublicKeyInfo bytes (Tag + Length + Value) from the DER encoded certificate.
  ///
  /// Structure of X.509 (simplified):
  /// Certificate ::= SEQUENCE {
  ///   tbsCertificate       TBSCertificate,
  ///   ...
  /// }
  ///
  /// TBSCertificate ::= SEQUENCE {
  ///   version         [0]  EXPLICIT Version DEFAULT v1,
  ///   serialNumber         CertificateSerialNumber,
  ///   signature            AlgorithmIdentifier,
  ///   issuer               Name,
  ///   validity             Validity,
  ///   subject              Name,
  ///   subjectPublicKeyInfo SubjectPublicKeyInfo,
  ///   ...
  /// }
  static Uint8List? _extractSpki(Uint8List der) {
    // Minimal ASN.1 parser to walk the structure
    var parser = _DerParser(der);

    // 1. Unwrap outer Certificate SEQUENCE
    if (!parser.enterSequence()) return null; // Enter Certificate

    // 2. Unwrap TBSCertificate SEQUENCE (first element)
    // Note: tbsCertificate is the first element in Certificate sequence.
    // We need to parse THIS sequence to find SPKI inside it.
    // However, if we simply "enter" it, we are consuming it.
    // Instead of entering, let's just get the *bytes* of the TBS Cert first?
    // Actually method `enterSequence` moves into it.

    if (!parser.enterSequence()) return null; // Enter TBSCertificate

    // 3. Skip Fields to reach SPKI

    // a) Version: [0] EXPLICIT ... OPTIONAL.
    // Tag 0xA0 (Context 0 | Constructed) usually.
    if (parser.peekTag() == 0xA0) {
      parser.skip(); // Skip Version
    }

    // b) SerialNumber: INTEGER
    if (!parser.skipExpected(0x02)) return null;

    // c) Signature: SEQUENCE (AlgorithmIdentifier)
    if (!parser.skipExpected(0x30)) return null;

    // d) Issuer: SEQUENCE (Name)
    if (!parser.skipExpected(0x30)) return null;

    // e) Validity: SEQUENCE
    if (!parser.skipExpected(0x30)) return null;

    // f) Subject: SEQUENCE (Name)
    if (!parser.skipExpected(0x30)) return null;

    // g) SubjectPublicKeyInfo: SEQUENCE
    // This is what we want! We want the RAW bytes of this sequence.
    return parser.readRawBytesIfTag(0x30);
  }
}

class _DerParser {
  final Uint8List _data;
  int _offset = 0;

  _DerParser(this._data);

  bool get isDone => _offset >= _data.length;

  int peekTag() {
    if (isDone) return -1;
    return _data[_offset];
  }

  /// Tries to enter a constructed sequence/tag.
  /// Updates offset to point to the *contents* of the sequence.
  /// Returns true if successful (and matches tag 0x30 by default).
  bool enterSequence() {
    return _enterConstructed(0x30);
  }

  bool _enterConstructed(int tag) {
    if (isDone || _data[_offset] != tag) return false;
    _offset++; // Consume tag
    _readLength(); // Consume length, we ignore valid range check for simplicity here, just move offset
    return true;
  }

  void skip() {
    if (isDone) return;
    _offset++; // Tag
    final len = _readLength();
    _offset += len;
  }

  bool skipExpected(int tag) {
    if (isDone || _data[_offset] != tag) return false;
    skip();
    return true;
  }

  Uint8List? readRawBytesIfTag(int tag) {
    if (isDone || _data[_offset] != tag) return null;
    final start = _offset;
    _offset++; // Tag
    final len = _readLength();
    _offset += len;
    // Return the slice from start (msg tag) to current offset
    return _data.sublist(start, _offset);
  }

  /// Reads ASN.1 length.
  int _readLength() {
    if (isDone) return 0;
    int length = _data[_offset++];
    if ((length & 0x80) != 0) {
      // Long form
      int numOctets = length & 0x7F;
      length = 0;
      for (int i = 0; i < numOctets; i++) {
        if (isDone) break; // Error
        length = (length << 8) | _data[_offset++];
      }
    }
    return length;
  }
}
