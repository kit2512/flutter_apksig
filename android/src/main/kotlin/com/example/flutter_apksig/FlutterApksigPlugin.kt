package com.example.flutter_apksig

import com.android.apksig.ApkSigner
import com.android.apksig.ApkVerifier
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.io.File
import java.io.FileInputStream
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.cert.X509Certificate
import java.util.concurrent.Executors

/**
 * Flutter plugin that exposes [ApkVerifier] and [ApkSigner] from the
 * apksig-android library to Dart via Pigeon-generated message channels.
 */
class FlutterApksigPlugin : FlutterPlugin, ApksigHostApi {

    // Single-threaded executor so all blocking I/O runs off the main thread.
    private val executor = Executors.newSingleThreadExecutor()

    // -------------------------------------------------------------------------
    // FlutterPlugin lifecycle
    // -------------------------------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ApksigHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ApksigHostApi.setUp(binding.binaryMessenger, null)
    }

    // -------------------------------------------------------------------------
    // ApksigHostApi  –  verifyApk
    // -------------------------------------------------------------------------

    override fun verifyApk(
        apkPath: String,
        minSdkVersion: Long?,
        maxSdkVersion: Long?,
        callback: (Result<ApkVerifyResult>) -> Unit,
    ) {
        executor.execute {
            try {
                val builder = ApkVerifier.Builder(File(apkPath))
                minSdkVersion?.let { builder.setMinCheckedPlatformVersion(it.toInt()) }
                maxSdkVersion?.let { builder.setMaxCheckedPlatformVersion(it.toInt()) }

                val result = builder.build().verify()

                val signers = buildSignerInfoList(result)

                callback(
                    Result.success(
                        ApkVerifyResult(
                            verified = result.isVerified,
                            signers = signers,
                            errors = result.errors.map { it.toString() },
                            warnings = result.warnings.map { it.toString() },
                        ),
                    ),
                )
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    // -------------------------------------------------------------------------
    // ApksigHostApi  –  signApk
    // -------------------------------------------------------------------------

    override fun signApk(request: ApkSignRequest, callback: (Result<Unit>) -> Unit) {
        executor.execute {
            try {
                // --- Load keystore ---
                // Android does not ship a JKS provider. Keystores created by
                // Android Studio are PKCS12 internally (Java 9+ default), even
                // when saved with a .jks extension. We try PKCS12 first, then
                // BKS (Bouncy Castle), and surface a helpful error if both fail.
                val ksFile = File(request.keystorePath)
                val ks = loadKeystore(ksFile, request.keystorePassword)

                val privKey =
                    ks.getKey(request.keyAlias, request.keyPassword.toCharArray()) as? PrivateKey
                        ?: throw IllegalArgumentException(
                            "Key '${request.keyAlias}' not found in keystore or is not a private key.",
                        )

                val certs = (ks.getCertificateChain(request.keyAlias) ?: emptyArray())
                    .map { it as X509Certificate }

                if (certs.isEmpty()) {
                    throw IllegalArgumentException(
                        "No certificates found for alias '${request.keyAlias}'.",
                    )
                }

                // --- Build signer config ---
                val signerConfig =
                    ApkSigner.SignerConfig.Builder(request.keyAlias, privKey, certs).build()

                val inputFile = File(request.inputApkPath)
                val outputFile = File(request.outputApkPath)

                // Handle in-place signing: write to temp, then rename.
                val inPlace = inputFile.canonicalPath == outputFile.canonicalPath
                val tmpFile =
                    if (inPlace) {
                        File.createTempFile("apksig_", ".apk", outputFile.parentFile)
                    } else {
                        outputFile
                    }

                // --- Build and execute signer ---
                val signerBuilder =
                    ApkSigner.Builder(listOf(signerConfig))
                        .setInputApk(inputFile)
                        .setOutputApk(tmpFile)

                request.v1SigningEnabled?.let { signerBuilder.setV1SigningEnabled(it) }
                request.v2SigningEnabled?.let { signerBuilder.setV2SigningEnabled(it) }
                request.v3SigningEnabled?.let { signerBuilder.setV3SigningEnabled(it) }
                request.v4SigningEnabled?.let { signerBuilder.setV4SigningEnabled(it) }
                request.minSdkVersion?.let { signerBuilder.setMinSdkVersion(it.toInt()) }

                signerBuilder.build().sign()

                // Finalize in-place case.
                if (inPlace) {
                    if (!inputFile.delete()) {
                        tmpFile.delete()
                        throw RuntimeException("Could not replace input APK at $inputFile")
                    }
                    if (!tmpFile.renameTo(outputFile)) {
                        throw RuntimeException(
                            "Signing succeeded but could not rename temp file to $outputFile",
                        )
                    }
                }

                callback(Result.success(Unit))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /**
     * Builds [ApkSignerInfo] objects from a [ApkVerifier.Result].
     *
     * The highest verified scheme is used as the authoritative certificate
     * source (v3.1 > v3 > v2 > v1).  Each distinct signer entry becomes one
     * [ApkSignerInfo] in the returned list.
     */
    private fun buildSignerInfoList(result: ApkVerifier.Result): List<ApkSignerInfo> {
        val hasV1 = result.isVerifiedUsingV1Scheme
        val hasV2 = result.isVerifiedUsingV2Scheme
        val hasV3 = result.isVerifiedUsingV3Scheme
        val hasV4 = result.isVerifiedUsingV4Scheme

        // Collect (certChain, errors, warnings) from the highest scheme available.
        data class RawSigner(
            val certs: List<X509Certificate>,
            val errors: List<String>,
            val warnings: List<String>,
        )

        val rawSigners: List<RawSigner> = when {
            result.isVerifiedUsingV31Scheme ->
                result.v31SchemeSigners.map { s ->
                    RawSigner(
                        certs = s.certificates,
                        errors = s.errors.map { it.toString() },
                        warnings = s.warnings.map { it.toString() },
                    )
                }

            hasV3 ->
                result.v3SchemeSigners.map { s ->
                    RawSigner(
                        certs = s.certificates,
                        errors = s.errors.map { it.toString() },
                        warnings = s.warnings.map { it.toString() },
                    )
                }

            hasV2 ->
                result.v2SchemeSigners.map { s ->
                    RawSigner(
                        certs = s.certificates,
                        errors = s.errors.map { it.toString() },
                        warnings = s.warnings.map { it.toString() },
                    )
                }

            hasV1 ->
                result.v1SchemeSigners.mapNotNull { s ->
                    val cert = s.certificate ?: return@mapNotNull null
                    RawSigner(
                        certs = listOf(cert),
                        errors = s.errors.map { it.toString() },
                        warnings = s.warnings.map { it.toString() },
                    )
                }

            else -> emptyList()
        }

        return rawSigners.map { raw ->
            ApkSignerInfo(
                certificates = raw.certs.map { certToInfo(it) },
                hasV1Signature = hasV1,
                hasV2Signature = hasV2,
                hasV3Signature = hasV3,
                hasV4Signature = hasV4,
                errors = raw.errors,
                warnings = raw.warnings,
            )
        }
    }

    /**
     * Loads a [KeyStore] by probing supported formats in order:
     *  1. PKCS12 — covers .p12, .pfx, and all .jks files created by
     *              Android Studio (which switched to PKCS12 as the default
     *              in Java 9 / AGP 4.x).
     *  2. BKS    — Bouncy Castle keystore, occasionally used on Android.
     *
     * The legacy Sun JKS format is NOT available on Android. If you have an
     * old-style JKS keystore, convert it first:
     *
     *   keytool -importkeystore \
     *     -srckeystore old.jks  -srcstoretype JKS \
     *     -destkeystore new.p12 -deststoretype PKCS12 \
     *     -srcalias <alias> -destalias <alias>
     */
    private fun loadKeystore(file: File, password: String): KeyStore {
        val bytes = file.readBytes()
        val pass = password.toCharArray()
        val errors = mutableListOf<String>()

        for (type in listOf("PKCS12", "BKS")) {
            try {
                val ks = KeyStore.getInstance(type)
                ks.load(bytes.inputStream(), pass)
                return ks
            } catch (e: Exception) {
                errors += "$type: ${e.message}"
            }
        }

        throw IllegalArgumentException(
            "Could not load keystore '${file.name}'. " +
                "Android supports PKCS12 (.p12) and BKS formats. " +
                "Legacy JKS keystores must be converted to PKCS12 first " +
                "(see plugin README). Details: ${errors.joinToString("; ")}",
        )
    }

    /** Converts an [X509Certificate] to a [CertificateInfo] message. */
    private fun certToInfo(cert: X509Certificate): CertificateInfo {
        val digest = MessageDigest.getInstance("SHA-256")
        val fingerprint =
            digest.digest(cert.encoded).joinToString(separator = ":") { "%02X".format(it) }

        return CertificateInfo(
            subjectDn = cert.subjectX500Principal.name,
            issuerDn = cert.issuerX500Principal.name,
            serialNumber = cert.serialNumber.toString(),
            sha256Fingerprint = fingerprint,
            validFromMs = cert.notBefore.time,
            validUntilMs = cert.notAfter.time,
        )
    }
}
