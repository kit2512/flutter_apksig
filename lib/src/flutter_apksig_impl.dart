import 'messages.g.dart';

/// Main entry-point for the flutter_apksig plugin.
///
/// Instantiate once and reuse; the underlying Pigeon channel is stateless.
class FlutterApksig {
  FlutterApksig() : _api = ApksigHostApi();

  final ApksigHostApi _api;

  // ---------------------------------------------------------------------------
  // Core API
  // ---------------------------------------------------------------------------

  /// Verifies the signatures of the APK at [apkPath].
  ///
  /// [minSdkVersion] and [maxSdkVersion] optionally bound the range of Android
  /// API levels the verification should target.  When `null`, the defaults
  /// derived from the APK's `AndroidManifest.xml` are used.
  ///
  /// Returns an [ApkVerifyResult] whose [ApkVerifyResult.verified] field
  /// indicates overall validity.  Even when `false`, the result contains
  /// per-signer details, errors, and warnings.
  ///
  /// Throws a [PlatformException] if the APK file cannot be read or is
  /// structurally malformed.
  Future<ApkVerifyResult> verifyApk(
    String apkPath, {
    int? minSdkVersion,
    int? maxSdkVersion,
  }) {
    return _api.verifyApk(apkPath, minSdkVersion, maxSdkVersion);
  }

  /// Signs the APK at [request.inputApkPath] and writes the result to
  /// [request.outputApkPath].
  ///
  /// [request.outputApkPath] may equal [request.inputApkPath] for in-place
  /// signing (the native side will use a temporary file and then rename).
  ///
  /// Throws a [PlatformException] on any error (I/O failure, bad keystore
  /// credentials, unsupported key type, etc.).
  Future<void> signApk(ApkSignRequest request) {
    return _api.signApk(request);
  }

  // ---------------------------------------------------------------------------
  // Certificate / SHA fingerprint helpers
  // ---------------------------------------------------------------------------

  /// Verifies the APK at [apkPath] **and** checks that at least one of its
  /// signing certificates matches [expectedSha256].
  ///
  /// [expectedSha256] is the SHA-256 fingerprint of the expected signing
  /// certificate.  Both colon-separated (`AA:BB:CC:…`) and plain hex
  /// (`AABBCC…`) formats are accepted, and comparison is case-insensitive.
  ///
  /// Returns a [CertificateVerifyResult] that tells you:
  /// - whether the APK's signatures are cryptographically valid
  /// - whether the certificate fingerprint matches the expected value
  /// - the full [ApkVerifyResult] for further inspection
  ///
  /// Example — confirm an APK was signed by your release key:
  /// ```dart
  /// const releaseSha256 = 'AB:CD:EF:…';
  ///
  /// final result = await apksig.verifyApkCertificate(
  ///   '/sdcard/Download/app.apk',
  ///   expectedSha256: releaseSha256,
  /// );
  ///
  /// if (result.verified && result.certificateMatch) {
  ///   print('APK is authentic!');
  /// } else if (!result.verified) {
  ///   print('Invalid signature: ${result.verifyResult.errors}');
  /// } else {
  ///   print('Signed by an unexpected certificate!');
  ///   print('Found: ${result.matchedFingerprints}');
  /// }
  /// ```
  Future<CertificateVerifyResult> verifyApkCertificate(
    String apkPath, {
    required String expectedSha256,
    int? minSdkVersion,
    int? maxSdkVersion,
  }) async {
    final result = await verifyApk(
      apkPath,
      minSdkVersion: minSdkVersion,
      maxSdkVersion: maxSdkVersion,
    );

    final expected = _normalizeFingerprint(expectedSha256);

    // Collect all certificate fingerprints across all signers.
    final allFingerprints = result.signers
        .whereType<ApkSignerInfo>()
        .expand((s) => s.certificates.whereType<CertificateInfo>())
        .map((c) => c.sha256Fingerprint)
        .toList();

    final match = allFingerprints.any(
      (fp) => _normalizeFingerprint(fp) == expected,
    );

    return CertificateVerifyResult(
      verified: result.verified,
      certificateMatch: match,
      matchedFingerprints: allFingerprints,
      verifyResult: result,
    );
  }

  /// Returns the SHA-256 fingerprints of all signing certificates in the APK
  /// at [apkPath], in colon-separated uppercase form (e.g. `"AA:BB:CC:…"`).
  ///
  /// Useful when you want to pin a new certificate or display certificate info
  /// without caring about the full [ApkVerifyResult].
  ///
  /// Throws a [PlatformException] if the APK cannot be read.
  Future<List<String>> getApkCertificateFingerprints(
    String apkPath, {
    int? minSdkVersion,
    int? maxSdkVersion,
  }) async {
    final result = await verifyApk(
      apkPath,
      minSdkVersion: minSdkVersion,
      maxSdkVersion: maxSdkVersion,
    );

    return result.signers
        .whereType<ApkSignerInfo>()
        .expand((s) => s.certificates.whereType<CertificateInfo>())
        .map((c) => c.sha256Fingerprint)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Strips colons and converts to uppercase so fingerprints in any common
  /// format can be compared equality.
  static String _normalizeFingerprint(String fp) =>
      fp.replaceAll(':', '').toUpperCase();
}

// ---------------------------------------------------------------------------
// Result type for verifyApkCertificate
// ---------------------------------------------------------------------------

/// The result of [FlutterApksig.verifyApkCertificate].
class CertificateVerifyResult {
  const CertificateVerifyResult({
    required this.verified,
    required this.certificateMatch,
    required this.matchedFingerprints,
    required this.verifyResult,
  });

  /// Whether the APK's cryptographic signatures are valid.
  final bool verified;

  /// Whether at least one signing certificate matched [expectedSha256].
  final bool certificateMatch;

  /// SHA-256 fingerprints of **all** signing certificates found in the APK
  /// (colon-separated, uppercase).  Useful for debugging a mismatch.
  final List<String> matchedFingerprints;

  /// The full verification result for detailed inspection.
  final ApkVerifyResult verifyResult;

  /// `true` only when both the signature is valid **and** the certificate
  /// matches.  This is the value to gate security-critical decisions on.
  bool get isAuthentic => verified && certificateMatch;

  @override
  String toString() =>
      'CertificateVerifyResult('
      'verified: $verified, '
      'certificateMatch: $certificateMatch, '
      'fingerprints: $matchedFingerprints)';
}
