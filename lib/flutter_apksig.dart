/// Flutter plugin for verifying and signing Android APK files using the
/// apksig-android library (an Android port of AOSP's apksig tool).
///
/// ## Usage
///
/// ```dart
/// import 'package:flutter_apksig/flutter_apksig.dart';
///
/// final apksig = FlutterApksig();
///
/// // Verify an APK
/// final result = await apksig.verifyApk('/path/to/app.apk');
/// if (result.verified) {
///   print('APK is valid!');
///   for (final signer in result.signers) {
///     print('  Signer: ${signer.certificates.first?.subjectDn}');
///   }
/// }
///
/// // Sign an APK
/// await apksig.signApk(ApkSignRequest(
///   inputApkPath: '/path/to/unsigned.apk',
///   outputApkPath: '/path/to/signed.apk',
///   keystorePath: '/path/to/keystore.jks',
///   keystorePassword: 'keystorePassword',
///   keyAlias: 'myKey',
///   keyPassword: 'keyPassword',
/// ));
/// ```
library;

export 'src/messages.g.dart'
    show ApkSignRequest, ApkVerifyResult, ApkSignerInfo, CertificateInfo;

export 'src/flutter_apksig_impl.dart'
    show FlutterApksig, CertificateVerifyResult;
