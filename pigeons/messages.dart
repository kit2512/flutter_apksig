// Copyright 2024 The flutter_apksig authors. All rights reserved.
// Use of this source code is governed by an Apache 2.0 license.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/example/flutter_apksig/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.example.flutter_apksig'),
  ),
)
// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------
/// Info about a single X.509 certificate in an APK signer's chain.
class CertificateInfo {
  CertificateInfo({
    required this.subjectDn,
    required this.issuerDn,
    required this.serialNumber,
    required this.sha256Fingerprint,
    required this.validFromMs,
    required this.validUntilMs,
  });

  /// Subject distinguished name (e.g. "CN=Android Debug, O=Android, C=US").
  String subjectDn;

  /// Issuer distinguished name.
  String issuerDn;

  /// Certificate serial number (decimal string).
  String serialNumber;

  /// SHA-256 fingerprint of the DER-encoded certificate (hex, upper-case,
  /// colon-separated, e.g. "AA:BB:CC:…").
  String sha256Fingerprint;

  /// Certificate validity start: milliseconds since Unix epoch.
  int validFromMs;

  /// Certificate validity end: milliseconds since Unix epoch.
  int validUntilMs;
}

/// Info about one signer in an APK's signature block.
class ApkSignerInfo {
  ApkSignerInfo({
    required this.certificates,
    required this.hasV1Signature,
    required this.hasV2Signature,
    required this.hasV3Signature,
    required this.hasV4Signature,
    required this.errors,
    required this.warnings,
  });

  /// Certificate chain for this signer (index 0 is the signing certificate).
  List<CertificateInfo?> certificates;

  bool hasV1Signature;
  bool hasV2Signature;
  bool hasV3Signature;
  bool hasV4Signature;

  /// Human-readable error messages for this signer.
  List<String?> errors;

  /// Human-readable warning messages for this signer.
  List<String?> warnings;
}

/// The result of verifying an APK's signatures.
class ApkVerifyResult {
  ApkVerifyResult({
    required this.verified,
    required this.signers,
    required this.errors,
    required this.warnings,
  });

  /// Whether the APK's signatures are valid.
  bool verified;

  /// Per-signer information.
  List<ApkSignerInfo?> signers;

  /// Top-level verification errors (not tied to a specific signer).
  List<String?> errors;

  /// Top-level warnings.
  List<String?> warnings;
}

/// Parameters for signing an APK with a Java keystore (.jks / .p12).
class ApkSignRequest {
  ApkSignRequest({
    required this.inputApkPath,
    required this.outputApkPath,
    required this.keystorePath,
    required this.keystorePassword,
    required this.keyAlias,
    required this.keyPassword,
    this.v1SigningEnabled,
    this.v2SigningEnabled,
    this.v3SigningEnabled,
    this.v4SigningEnabled,
    this.minSdkVersion,
  });

  /// Absolute path to the unsigned (or previously signed) input APK.
  String inputApkPath;

  /// Absolute path where the signed APK should be written.
  /// May be the same as [inputApkPath] (in-place signing).
  String outputApkPath;

  /// Absolute path to the keystore file (.jks or .p12).
  String keystorePath;

  /// Password for the keystore.
  String keystorePassword;

  /// Alias of the key entry inside the keystore.
  String keyAlias;

  /// Password for the private key (may be the same as [keystorePassword]).
  String keyPassword;

  /// Enable JAR signing (v1). Defaults to the apksig library default when null.
  bool? v1SigningEnabled;

  /// Enable APK Signature Scheme v2. Defaults to the library default when null.
  bool? v2SigningEnabled;

  /// Enable APK Signature Scheme v3. Defaults to the library default when null.
  bool? v3SigningEnabled;

  /// Enable APK Signature Scheme v4. Defaults to the library default when null.
  bool? v4SigningEnabled;

  /// Minimum Android SDK version the signed APK must support.
  /// Influences which signature schemes are applied.
  int? minSdkVersion;
}

// ---------------------------------------------------------------------------
// Host API  (implemented on Android, called from Dart)
// ---------------------------------------------------------------------------

@HostApi()
abstract class ApksigHostApi {
  /// Verifies the signatures of the APK at [apkPath].
  ///
  /// [minSdkVersion] and [maxSdkVersion] bound the range of Android API
  /// levels the verification should target; pass null to use the defaults
  /// derived from the APK's manifest.
  @async
  ApkVerifyResult verifyApk(
    String apkPath,
    int? minSdkVersion,
    int? maxSdkVersion,
  );

  /// Signs [request.inputApkPath] and writes the result to
  /// [request.outputApkPath].
  ///
  /// Throws a [PlatformException] on any signing error (I/O, bad keystore,
  /// invalid key, etc.).
  @async
  void signApk(ApkSignRequest request);
}
