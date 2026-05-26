## 0.0.1

* Initial release.
* Verify APK signatures (JAR v1, APK Signature Scheme v2, v3, v3.1, v4).
* Sign APKs with a Java keystore (`.jks` / `.p12`).
* Certificate fingerprint verification — compare APK signing certificate
  SHA-256 against an expected value.
* `getApkCertificateFingerprints` helper for pinning or inspecting certificates.
* All APK I/O runs on a background thread.
* Platform channel generated with Pigeon for type-safe communication.
