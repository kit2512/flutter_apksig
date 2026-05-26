import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_apksig/flutter_apksig.dart';
// Import the generated file directly to access ApksigHostApi.pigeonChannelCodec.
// ignore: implementation_imports
import 'package:flutter_apksig/src/messages.g.dart' show ApksigHostApi;

// ---------------------------------------------------------------------------
// Channel mock helpers
// ---------------------------------------------------------------------------

const _codec = ApksigHostApi.pigeonChannelCodec;
const _verifyChannel =
    'dev.flutter.pigeon.flutter_apksig.ApksigHostApi.verifyApk';
const _signChannel = 'dev.flutter.pigeon.flutter_apksig.ApksigHostApi.signApk';

/// Registers a success reply on [channelName].
void _mockSuccess(String channelName, Object? reply) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(channelName, (ByteData? _) async {
        return _codec.encodeMessage(<Object?>[reply]);
      });
}

/// Registers an error reply (3-element list) on [channelName].
void _mockError(String channelName, String code, String message) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(channelName, (ByteData? _) async {
        return _codec.encodeMessage(<Object?>[code, message, null]);
      });
}

void _clear(String channelName) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(channelName, null);
}

// ---------------------------------------------------------------------------
// Fixture builders
// ---------------------------------------------------------------------------

CertificateInfo _cert({
  String subjectDn = 'CN=Test, O=Test Org, C=US',
  String issuerDn = 'CN=Test, O=Test Org, C=US',
  String serialNumber = '123456',
  String sha256Fingerprint =
      'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:'
      'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99',
  int validFromMs = 0,
  int validUntilMs = 9999999999999,
}) => CertificateInfo(
  subjectDn: subjectDn,
  issuerDn: issuerDn,
  serialNumber: serialNumber,
  sha256Fingerprint: sha256Fingerprint,
  validFromMs: validFromMs,
  validUntilMs: validUntilMs,
);

ApkSignerInfo _signer({
  List<CertificateInfo?> certs = const [],
  bool v1 = false,
  bool v2 = true,
  bool v3 = true,
  bool v4 = false,
  List<String?> errors = const [],
  List<String?> warnings = const [],
}) => ApkSignerInfo(
  certificates: certs,
  hasV1Signature: v1,
  hasV2Signature: v2,
  hasV3Signature: v3,
  hasV4Signature: v4,
  errors: errors,
  warnings: warnings,
);

ApkVerifyResult _verifyResult({
  bool verified = true,
  List<ApkSignerInfo?> signers = const [],
  List<String?> errors = const [],
  List<String?> warnings = const [],
}) => ApkVerifyResult(
  verified: verified,
  signers: signers,
  errors: errors,
  warnings: warnings,
);

const _kFingerprint =
    'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:'
    'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── CertificateVerifyResult unit tests (no platform channel needed) ─────

  group('CertificateVerifyResult', () {
    test(
      'isAuthentic is true only when both verified and certificateMatch',
      () {
        expect(
          CertificateVerifyResult(
            verified: true,
            certificateMatch: true,
            matchedFingerprints: [],
            verifyResult: _verifyResult(),
          ).isAuthentic,
          isTrue,
        );
        expect(
          CertificateVerifyResult(
            verified: true,
            certificateMatch: false,
            matchedFingerprints: [],
            verifyResult: _verifyResult(),
          ).isAuthentic,
          isFalse,
        );
        expect(
          CertificateVerifyResult(
            verified: false,
            certificateMatch: true,
            matchedFingerprints: [],
            verifyResult: _verifyResult(verified: false),
          ).isAuthentic,
          isFalse,
        );
        expect(
          CertificateVerifyResult(
            verified: false,
            certificateMatch: false,
            matchedFingerprints: [],
            verifyResult: _verifyResult(verified: false),
          ).isAuthentic,
          isFalse,
        );
      },
    );

    test('toString contains key fields', () {
      final result = CertificateVerifyResult(
        verified: true,
        certificateMatch: true,
        matchedFingerprints: ['AA:BB'],
        verifyResult: _verifyResult(),
      );
      expect(result.toString(), contains('verified: true'));
      expect(result.toString(), contains('certificateMatch: true'));
      expect(result.toString(), contains('AA:BB'));
    });
  });

  // ── Plugin tests (platform channel mocked) ───────────────────────────────

  group('FlutterApksig', () {
    late FlutterApksig plugin;
    setUp(() => plugin = FlutterApksig());

    // ── verifyApk ────────────────────────────────────────────────────────────

    group('verifyApk', () {
      test(
        'returns verified result with signer and certificate details',
        () async {
          _mockSuccess(
            _verifyChannel,
            _verifyResult(
              signers: [
                _signer(certs: [_cert()]),
              ],
            ),
          );
          addTearDown(() => _clear(_verifyChannel));

          final result = await plugin.verifyApk('/fake/app.apk');

          expect(result.verified, isTrue);
          expect(result.signers, hasLength(1));

          final signer = result.signers.first!;
          expect(signer.hasV2Signature, isTrue);
          expect(signer.hasV3Signature, isTrue);
          expect(signer.hasV1Signature, isFalse);
          expect(signer.hasV4Signature, isFalse);

          final cert = signer.certificates.first!;
          expect(cert.subjectDn, contains('CN=Test'));
          expect(cert.sha256Fingerprint, equals(_kFingerprint));
        },
      );

      test('returns unverified result and exposes errors', () async {
        _mockSuccess(
          _verifyChannel,
          _verifyResult(
            verified: false,
            errors: ['JAR_SIG_NO_MANIFEST', 'V2_SIG_MALFORMED_SIGNER'],
          ),
        );
        addTearDown(() => _clear(_verifyChannel));

        final result = await plugin.verifyApk('/fake/unsigned.apk');

        expect(result.verified, isFalse);
        expect(
          result.errors,
          containsAll(['JAR_SIG_NO_MANIFEST', 'V2_SIG_MALFORMED_SIGNER']),
        );
        expect(result.signers, isEmpty);
      });

      test('returns warnings on the result', () async {
        _mockSuccess(
          _verifyChannel,
          _verifyResult(
            signers: [
              _signer(certs: [_cert()], warnings: ['CERT_EXPIRED']),
            ],
            warnings: ['APK_SIG_SCHEME_V2_WARNING'],
          ),
        );
        addTearDown(() => _clear(_verifyChannel));

        final result = await plugin.verifyApk('/fake/app.apk');

        expect(result.warnings, contains('APK_SIG_SCHEME_V2_WARNING'));
        expect(result.signers.first!.warnings, contains('CERT_EXPIRED'));
      });

      test('passes minSdkVersion and maxSdkVersion to the channel', () async {
        int? capturedMin;
        int? capturedMax;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(_verifyChannel, (ByteData? message) async {
              final args = _codec.decodeMessage(message) as List<Object?>;
              capturedMin = args[1] as int?;
              capturedMax = args[2] as int?;
              return _codec.encodeMessage(<Object?>[_verifyResult()]);
            });
        addTearDown(() => _clear(_verifyChannel));

        await plugin.verifyApk(
          '/fake/app.apk',
          minSdkVersion: 24,
          maxSdkVersion: 34,
        );

        expect(capturedMin, 24);
        expect(capturedMax, 34);
      });

      test('throws PlatformException on channel error', () async {
        _mockError(_verifyChannel, 'IO_ERROR', 'File not found');
        addTearDown(() => _clear(_verifyChannel));

        await expectLater(
          () => plugin.verifyApk('/nonexistent.apk'),
          throwsA(
            isA<PlatformException>().having((e) => e.code, 'code', 'IO_ERROR'),
          ),
        );
      });
    });

    // ── signApk ──────────────────────────────────────────────────────────────

    group('signApk', () {
      ApkSignRequest buildReq({
        String input = '/fake/unsigned.apk',
        String output = '/fake/signed.apk',
      }) => ApkSignRequest(
        inputApkPath: input,
        outputApkPath: output,
        keystorePath: '/fake/keystore.jks',
        keystorePassword: 'ksPassword',
        keyAlias: 'myKey',
        keyPassword: 'keyPassword',
      );

      test('completes successfully on void reply', () async {
        _mockSuccess(_signChannel, null);
        addTearDown(() => _clear(_signChannel));

        await expectLater(plugin.signApk(buildReq()), completes);
      });

      test('passes all request fields to the channel', () async {
        ApkSignRequest? captured;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(_signChannel, (ByteData? message) async {
              final args = _codec.decodeMessage(message) as List<Object?>;
              captured = args[0] as ApkSignRequest;
              return _codec.encodeMessage(<Object?>[null]);
            });
        addTearDown(() => _clear(_signChannel));

        await plugin.signApk(
          buildReq(input: '/data/unsigned.apk', output: '/data/signed.apk'),
        );

        expect(captured!.inputApkPath, '/data/unsigned.apk');
        expect(captured!.outputApkPath, '/data/signed.apk');
        expect(captured!.keystorePath, '/fake/keystore.jks');
        expect(captured!.keyAlias, 'myKey');
      });

      test('supports optional signing scheme flags', () async {
        ApkSignRequest? captured;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(_signChannel, (ByteData? message) async {
              final args = _codec.decodeMessage(message) as List<Object?>;
              captured = args[0] as ApkSignRequest;
              return _codec.encodeMessage(<Object?>[null]);
            });
        addTearDown(() => _clear(_signChannel));

        await plugin.signApk(
          ApkSignRequest(
            inputApkPath: '/in.apk',
            outputApkPath: '/out.apk',
            keystorePath: '/ks.jks',
            keystorePassword: 'pass',
            keyAlias: 'key',
            keyPassword: 'pass',
            v1SigningEnabled: false,
            v2SigningEnabled: true,
            v3SigningEnabled: true,
            v4SigningEnabled: false,
            minSdkVersion: 24,
          ),
        );

        expect(captured!.v1SigningEnabled, isFalse);
        expect(captured!.v2SigningEnabled, isTrue);
        expect(captured!.v3SigningEnabled, isTrue);
        expect(captured!.v4SigningEnabled, isFalse);
        expect(captured!.minSdkVersion, 24);
      });

      test('throws PlatformException on keystore error', () async {
        _mockError(_signChannel, 'INVALID_KEYSTORE', 'Wrong password');
        addTearDown(() => _clear(_signChannel));

        await expectLater(
          () => plugin.signApk(buildReq()),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'INVALID_KEYSTORE',
            ),
          ),
        );
      });
    });

    // ── verifyApkCertificate ─────────────────────────────────────────────────

    group('verifyApkCertificate', () {
      void mockVerify(ApkVerifyResult result) =>
          _mockSuccess(_verifyChannel, result);

      test(
        'isAuthentic when signature valid and fingerprint matches',
        () async {
          mockVerify(
            _verifyResult(
              signers: [
                _signer(certs: [_cert(sha256Fingerprint: _kFingerprint)]),
              ],
            ),
          );
          addTearDown(() => _clear(_verifyChannel));

          final result = await plugin.verifyApkCertificate(
            '/fake/app.apk',
            expectedSha256: _kFingerprint,
          );

          expect(result.verified, isTrue);
          expect(result.certificateMatch, isTrue);
          expect(result.isAuthentic, isTrue);
        },
      );

      test(
        'certificateMatch is false when signed by a different key',
        () async {
          mockVerify(
            _verifyResult(
              signers: [
                _signer(
                  certs: [
                    _cert(
                      sha256Fingerprint:
                          'AA:BB:CC:DD:EE:FF:00:11:'
                          '22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:'
                          '22:33:44:55:66:77:88:FF',
                    ),
                  ],
                ),
              ],
            ),
          );
          addTearDown(() => _clear(_verifyChannel));

          final result = await plugin.verifyApkCertificate(
            '/fake/app.apk',
            expectedSha256: _kFingerprint, // different fingerprint
          );

          expect(result.verified, isTrue);
          expect(result.certificateMatch, isFalse);
          expect(result.isAuthentic, isFalse);
        },
      );

      test('isAuthentic is false when APK verification fails', () async {
        mockVerify(
          _verifyResult(verified: false, errors: ['JAR_SIG_NO_MANIFEST']),
        );
        addTearDown(() => _clear(_verifyChannel));

        final result = await plugin.verifyApkCertificate(
          '/fake/tampered.apk',
          expectedSha256: _kFingerprint,
        );

        expect(result.verified, isFalse);
        expect(result.isAuthentic, isFalse);
        expect(result.verifyResult.errors, contains('JAR_SIG_NO_MANIFEST'));
      });

      test('fingerprint comparison is case-insensitive', () async {
        mockVerify(
          _verifyResult(
            signers: [
              _signer(certs: [_cert(sha256Fingerprint: _kFingerprint)]),
            ],
          ),
        );
        addTearDown(() => _clear(_verifyChannel));

        final result = await plugin.verifyApkCertificate(
          '/fake/app.apk',
          expectedSha256: _kFingerprint.toLowerCase(),
        );

        expect(result.certificateMatch, isTrue);
      });

      test('fingerprint comparison ignores colons', () async {
        mockVerify(
          _verifyResult(
            signers: [
              _signer(certs: [_cert(sha256Fingerprint: _kFingerprint)]),
            ],
          ),
        );
        addTearDown(() => _clear(_verifyChannel));

        // Same bytes as _kFingerprint but with no colons.
        final plainHex = _kFingerprint.replaceAll(':', '');

        final result = await plugin.verifyApkCertificate(
          '/fake/app.apk',
          expectedSha256: plainHex,
        );

        expect(result.certificateMatch, isTrue);
      });

      test(
        'matchedFingerprints lists all found certificate fingerprints',
        () async {
          const fp1 =
              'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:'
              'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:01';
          const fp2 =
              'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:'
              'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:02';

          mockVerify(
            _verifyResult(
              signers: [
                _signer(
                  certs: [
                    _cert(sha256Fingerprint: fp1),
                    _cert(sha256Fingerprint: fp2),
                  ],
                ),
              ],
            ),
          );
          addTearDown(() => _clear(_verifyChannel));

          final result = await plugin.verifyApkCertificate(
            '/fake/app.apk',
            expectedSha256: fp1,
          );

          expect(result.matchedFingerprints, containsAll([fp1, fp2]));
          expect(result.certificateMatch, isTrue);
        },
      );

      test('returns full verifyResult for further inspection', () async {
        final fakeVerify = _verifyResult(
          signers: [
            _signer(certs: [_cert()]),
          ],
          warnings: ['WEAK_KEY'],
        );
        mockVerify(fakeVerify);
        addTearDown(() => _clear(_verifyChannel));

        final result = await plugin.verifyApkCertificate(
          '/fake/app.apk',
          expectedSha256: _kFingerprint,
        );

        expect(result.verifyResult.warnings, contains('WEAK_KEY'));
      });

      test('throws PlatformException on channel error', () async {
        _mockError(_verifyChannel, 'IO_ERROR', 'File not found');
        addTearDown(() => _clear(_verifyChannel));

        await expectLater(
          () => plugin.verifyApkCertificate(
            '/nonexistent.apk',
            expectedSha256: _kFingerprint,
          ),
          throwsA(isA<PlatformException>()),
        );
      });
    });

    // ── getApkCertificateFingerprints ────────────────────────────────────────

    group('getApkCertificateFingerprints', () {
      test('returns all fingerprints from all signers', () async {
        const fp1 =
            'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:'
            'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:01';
        const fp2 =
            'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:'
            'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:02';

        _mockSuccess(
          _verifyChannel,
          _verifyResult(
            signers: [
              _signer(certs: [_cert(sha256Fingerprint: fp1)]),
              _signer(certs: [_cert(sha256Fingerprint: fp2)]),
            ],
          ),
        );
        addTearDown(() => _clear(_verifyChannel));

        final fps = await plugin.getApkCertificateFingerprints('/fake/app.apk');

        expect(fps, hasLength(2));
        expect(fps, containsAll([fp1, fp2]));
      });

      test('returns empty list for an unsigned APK', () async {
        _mockSuccess(
          _verifyChannel,
          _verifyResult(verified: false, signers: []),
        );
        addTearDown(() => _clear(_verifyChannel));

        final fps = await plugin.getApkCertificateFingerprints(
          '/fake/unsigned.apk',
        );

        expect(fps, isEmpty);
      });

      test('throws PlatformException on channel error', () async {
        _mockError(_verifyChannel, 'FORMAT_ERROR', 'Malformed APK');
        addTearDown(() => _clear(_verifyChannel));

        await expectLater(
          () => plugin.getApkCertificateFingerprints('/fake/bad.apk'),
          throwsA(isA<PlatformException>()),
        );
      });
    });
  });
}
