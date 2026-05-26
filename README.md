# flutter_apksig

A Flutter plugin for verifying and signing Android APK files, powered by the
[apksig-android](https://github.com/MuntashirAkon/apksig-android) library — an
Android port of AOSP's `apksig` tool.

Supports **JAR signing (v1)**, **APK Signature Scheme v2**, **v3**, and **v4**.

---

## Features

- ✅ Verify APK signatures (v1 / v2 / v3 / v3.1 / v4)
- ✅ Sign APKs with a Java keystore (`.jks` / `.p12`)
- ✅ Compare a certificate SHA-256 fingerprint to confirm APK authenticity
- ✅ Retrieve per-signer certificate details (subject, issuer, SHA-256, validity)
- ✅ In-place signing (input path == output path)
- ✅ Runs all I/O on a background thread — never blocks the UI

**Platform support**

| Platform | Support |
|----------|---------|
| Android  | ✅      |
| iOS      | ❌ (Android-only library) |

---

## Installation

```yaml
dependencies:
  flutter_apksig: ^0.0.1
```

```bash
flutter pub get
```

---

## Usage

```dart
import 'package:flutter_apksig/flutter_apksig.dart';

final apksig = FlutterApksig();
```

### Verify an APK

```dart
final result = await apksig.verifyApk(
  '/sdcard/Download/app.apk',
  // Optional: bound the Android SDK range to verify against
  // minSdkVersion: 24,
  // maxSdkVersion: 34,
);

if (result.verified) {
  for (final signer in result.signers.whereType<ApkSignerInfo>()) {
    final cert = signer.certificates.firstOrNull;
    print('Subject : ${cert?.subjectDn}');
    print('SHA-256 : ${cert?.sha256Fingerprint}');
    print('Schemes : '
        '${signer.hasV1Signature ? 'v1 ' : ''}'
        '${signer.hasV2Signature ? 'v2 ' : ''}'
        '${signer.hasV3Signature ? 'v3 ' : ''}'
        '${signer.hasV4Signature ? 'v4' : ''}');
  }
} else {
  for (final e in result.errors.whereType<String>()) {
    print('Error: $e');
  }
}
```

### Verify a certificate fingerprint

Confirm an APK was signed with a specific key by comparing its embedded
certificate against a known SHA-256 fingerprint (e.g. the one from your
release keystore).

```dart
final result = await apksig.verifyApkCertificate(
  '/sdcard/Download/app.apk',
  expectedSha256: 'AA:BB:CC:…', // colon-separated or plain hex, any case
);

if (result.isAuthentic) {
  print('Authentic — signed with the expected key.');
} else if (!result.verified) {
  print('Invalid signatures: ${result.verifyResult.errors}');
} else {
  print('Wrong certificate. Found: ${result.matchedFingerprints}');
}
```

To retrieve the fingerprint from an already-signed APK (useful for pinning):

```dart
final fingerprints = await apksig.getApkCertificateFingerprints(
  '/sdcard/Download/app.apk',
);
print(fingerprints); // ['AA:BB:CC:…']
```

Or get it directly from the keystore with `keytool`:

```bash
keytool -list -v \
  -keystore release.jks \
  -alias myKey \
  -storepass <keystorePassword>
# Look for the SHA256: line in the output.
```

### Sign an APK

```dart
await apksig.signApk(
  ApkSignRequest(
    inputApkPath:     '/sdcard/Download/unsigned.apk',
    outputApkPath:    '/sdcard/Download/signed.apk',
    keystorePath:     '/sdcard/Download/release.jks',
    keystorePassword: 'keystorePassword',
    keyAlias:         'myKey',
    keyPassword:      'keyPassword',
    // Optional — library defaults are used when omitted:
    // v1SigningEnabled: true,
    // v2SigningEnabled: true,
    // v3SigningEnabled: true,
    // v4SigningEnabled: false,
    // minSdkVersion: 24,
  ),
);
```

> **In-place signing** — `outputApkPath` may equal `inputApkPath`. The plugin
> writes to a temporary file and atomically renames it on success, so the
> original is never corrupted.

### Keystore formats

Android does **not** include a JKS (Java KeyStore) provider at runtime, so
`.jks` files created with older versions of Java must be converted to **PKCS12**
before use. Android Studio keystores are already PKCS12 internally (the `.jks`
extension is kept for historical reasons), so they work without conversion.

| Format | Extension | Support |
|--------|-----------|---------|
| PKCS12 | `.p12`, `.pfx`, `.jks` (Android Studio) | ✅ |
| BKS (Bouncy Castle) | `.bks` | ✅ |
| JKS (legacy Sun) | `.jks` (old Java) | ❌ — convert first |

To check whether your `.jks` is PKCS12 or legacy JKS:

```bash
keytool -list -keystore release.jks -storepass <password>
# Output will say "Keystore type: PKCS12" or "Keystore type: JKS"
```

To convert a legacy JKS keystore to PKCS12:

```bash
keytool -importkeystore \
  -srckeystore  old.jks  -srcstoretype  JKS \
  -destkeystore new.p12  -deststoretype PKCS12 \
  -srcalias  <alias>     -destalias  <alias>
```

### Error handling

All methods throw a `PlatformException` on failure (I/O error, bad keystore
credentials, malformed APK, etc.):

```dart
try {
  await apksig.signApk(request);
} on PlatformException catch (e) {
  print('${e.code}: ${e.message}');
}
```

---

## Android permissions

Verifying an APK requires no special permissions. Signing requires read access
to the keystore and write access to the output path. For files on external
storage, declare `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` (API ≤ 28)
or use the [`permission_handler`](https://pub.dev/packages/permission_handler)
package.

---

## How it works

```
Flutter (Dart)                      Android (Kotlin)
─────────────────────               ──────────────────────────────
FlutterApksig.verifyApk()           FlutterApksigPlugin
FlutterApksig.signApk()      ──►    (implements ApksigHostApi)
FlutterApksig.verifyApk            │
  Certificate()                    │  apksig-android (bundled JAR)
                                   ├─ ApkVerifier
                                   └─ ApkSigner
```

Platform channel code is generated with [Pigeon](https://pub.dev/packages/pigeon)
from [`pigeons/messages.dart`](pigeons/messages.dart). All APK I/O runs on a
background thread — the UI is never blocked.

---

## License

```
Copyright 2024 flutter_apksig authors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0
```

The bundled `apksig-android` library is also Apache 2.0 —
see [apksig-android/LICENSE](../apksig-android/LICENSE).
