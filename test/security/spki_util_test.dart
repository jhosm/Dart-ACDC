import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dart_acdc/src/security/spki_util.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'spki_util_test.mocks.dart';

@GenerateMocks([X509Certificate])
void main() {
  group('SpkiUtil', () {
    test('extracts SPKI hash correctly from valid DER', () {
      // Construct a minimal valid X.509 structure
      // Certificate (Seq)
      //   TBSCertificate (Seq)
      //     Version, Serial, SigAlg, Issuer, Validity, Subject (skipped)
      //     SubjectPublicKeyInfo (Value to hash!)

      final spkiContent = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
      final spkiSeq = _encodeSequence(spkiContent); // Tag 0x30 + len + content

      // Items before SPKI:
      // [0] Version (A0 ..)
      final version = Uint8List.fromList([0xA0, 0x03, 0x02, 0x01, 0x00]);
      // Serial (02 ..)
      final serial = Uint8List.fromList([0x02, 0x01, 0x01]);
      // SigAlg (30 ..)
      final sigAlg = _encodeSequence([0x01]);
      // Issuer (30 ..)
      final issuer = _encodeSequence([0x02]);
      // Validity (30 ..)
      final validity = _encodeSequence([0x03]);
      // Subject (30 ..)
      final subject = _encodeSequence([0x04]);

      final tbsContent = <int>[
        ...version,
        ...serial,
        ...sigAlg,
        ...issuer,
        ...validity,
        ...subject,
        ...spkiSeq, // The target
      ];

      final tbsSeq = _encodeSequence(Uint8List.fromList(tbsContent));
      final certSeq = _encodeSequence(tbsSeq); // Wrapped in Cert

      final mockCert = MockX509Certificate();
      when(mockCert.der).thenReturn(certSeq);

      final hash = SpkiUtil.extractSpkiHash(mockCert);

      // Expected: SHA256 of spkiSeq (NOT just content, the full sequence bytes)
      final expectedDigest = sha256.convert(spkiSeq);
      final expectedString = 'SHA256:${base64.encode(expectedDigest.bytes)}';

      expect(hash, equals(expectedString));
    });

    test('throws FormatException if derivation fails (malformed)', () {
      // Malformed structure (empty)
      final mockCert = MockX509Certificate();
      when(mockCert.der).thenReturn(Uint8List(0));

      expect(
        () => SpkiUtil.extractSpkiHash(mockCert),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

// Helper to encode simple ASN.1 Sequence (Tag 0x30)
Uint8List _encodeSequence(List<int> content) {
  final len = content.length;
  // Simplified length encoding for test (assuming < 127 for now)
  // If we need long form, we add logic.
  if (len > 127) {
    throw UnimplementedError('Test helper only supports short length');
  }
  return Uint8List.fromList([
    0x30, // Tag Sequence
    len,
    ...content
  ]);
}
