import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_apksig/flutter_apksig.dart';

class VerifyCertificatePage extends StatefulWidget {
  const VerifyCertificatePage({super.key});

  @override
  State<VerifyCertificatePage> createState() => _VerifyCertificatePageState();
}

class _VerifyCertificatePageState extends State<VerifyCertificatePage> {
  final _apksig = FlutterApksig();
  final _apkCtrl = TextEditingController();
  final _sha256Ctrl = TextEditingController();

  bool _loading = false;
  CertificateVerifyResult? _result;
  // Keep a snapshot of what was submitted so the result section can show it.
  String? _submittedApkPath;
  String? _submittedSha256;
  String? _error;

  @override
  void dispose() {
    _apkCtrl.dispose();
    _sha256Ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickApk() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    if (picked != null && picked.files.single.path != null) {
      setState(() {
        _apkCtrl.text = picked.files.single.path!;
        _result = null;
        _error = null;
      });
    }
  }

  Future<void> _verify() async {
    final path = _apkCtrl.text.trim();
    final sha256 = _sha256Ctrl.text.trim();
    if (path.isEmpty || sha256.isEmpty) return;

    setState(() {
      _loading = true;
      _result = null;
      _error = null;
      _submittedApkPath = path;
      _submittedSha256 = sha256;
    });

    try {
      final result = await _apksig.verifyApkCertificate(
        path,
        expectedSha256: sha256,
      );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canVerify =
        !_loading && _apkCtrl.text.isNotEmpty && _sha256Ctrl.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Certificate Check')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Inputs ────────────────────────────────────────────────────────
          _FilePicker(
            label: 'APK File',
            controller: _apkCtrl,
            onPick: _pickApk,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _sha256Ctrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Expected SHA-256',
              hintText: 'AA:BB:CC:DD:… or AABBCCDD…',
              border: const OutlineInputBorder(),
              isDense: true,
              helperText:
                  'The certificate fingerprint from your keystore. '
                  'Colon-separated or plain hex, any case.',
              helperMaxLines: 2,
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste_outlined),
                tooltip: 'Paste from clipboard',
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    _sha256Ctrl.text = data!.text!.trim();
                    setState(() {});
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: canVerify ? _verify : null,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.fingerprint),
            label: const Text('Verify Certificate'),
          ),
          const SizedBox(height: 28),

          // ── Result ────────────────────────────────────────────────────────
          if (_error != null) _ErrorCard(_error!),
          if (_result != null)
            _ResultSection(
              result: _result!,
              submittedApkPath: _submittedApkPath!,
              submittedSha256: _submittedSha256!,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result section
// ─────────────────────────────────────────────────────────────────────────────

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.result,
    required this.submittedApkPath,
    required this.submittedSha256,
  });

  final CertificateVerifyResult result;
  final String submittedApkPath;
  final String submittedSha256;

  @override
  Widget build(BuildContext context) {
    final vr = result.verifyResult;
    final signers = vr.signers.whereType<ApkSignerInfo>().toList();
    final first = signers.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Status banner ─────────────────────────────────────────────────
        _StatusBanner(result: result),
        const SizedBox(height: 20),

        // 2. Request summary ───────────────────────────────────────────────
        _SectionTitle('Request'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _DetailRow(
                  label: 'APK',
                  value: submittedApkPath.split('/').last,
                  fullValue: submittedApkPath,
                  mono: true,
                ),
                const Divider(height: 16),
                _DetailRow(
                  label: 'Expected SHA-256',
                  value: submittedSha256,
                  mono: true,
                  copyable: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 3. Signature schemes ─────────────────────────────────────────────
        _SectionTitle('Signature Schemes'),
        const SizedBox(height: 8),
        if (first == null)
          const Text(
            'No signers found — APK may be unsigned.',
            style: TextStyle(color: Colors.grey),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SchemeBadge(label: 'v1 JAR', active: first.hasV1Signature),
              _SchemeBadge(label: 'v2', active: first.hasV2Signature),
              _SchemeBadge(label: 'v3', active: first.hasV3Signature),
              _SchemeBadge(label: 'v4', active: first.hasV4Signature),
            ],
          ),
        const SizedBox(height: 20),

        // 4. Certificate comparison ────────────────────────────────────────
        _SectionTitle('Certificate Fingerprints'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Expected row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Expected'),
                    Expanded(
                      child: Text(
                        submittedSha256,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                // Found rows
                if (result.matchedFingerprints.isEmpty)
                  const Text(
                    'None found in APK.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  )
                else
                  for (int i = 0; i < result.matchedFingerprints.length; i++)
                    _FingerprintRow(
                      index: i,
                      fingerprint: result.matchedFingerprints[i],
                      normalize: _normalize,
                      expectedNormalized: _normalize(submittedSha256),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 5. Signer details ────────────────────────────────────────────────
        if (signers.isNotEmpty) ...[
          _SectionTitle('Signer Details  (${signers.length})'),
          const SizedBox(height: 8),
          for (int i = 0; i < signers.length; i++)
            _SignerDetailCard(
              index: i,
              signer: signers[i],
              expectedNormalized: _normalize(submittedSha256),
            ),
          const SizedBox(height: 4),
        ],

        // 6. Verification errors / warnings ───────────────────────────────
        if (vr.errors.isNotEmpty) ...[
          _SectionTitle('Errors'),
          const SizedBox(height: 6),
          for (final e in vr.errors.whereType<String>())
            _IssueRow(e, color: Colors.red),
          const SizedBox(height: 12),
        ],
        if (vr.warnings.isNotEmpty) ...[
          _SectionTitle('Warnings'),
          const SizedBox(height: 6),
          for (final w in vr.warnings.whereType<String>())
            _IssueRow(w, color: Colors.orange),
        ],
      ],
    );
  }

  static String _normalize(String fp) => fp.replaceAll(':', '').toUpperCase();
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.result});
  final CertificateVerifyResult result;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;

    if (result.isAuthentic) {
      color = Colors.green;
      icon = Icons.verified;
      title = 'Authentic';
      subtitle = 'Signature is valid and the certificate matches.';
    } else if (!result.verified) {
      color = Colors.red;
      icon = Icons.cancel;
      title = 'Verification Failed';
      subtitle = 'The APK\'s signatures are not cryptographically valid.';
    } else {
      color = Colors.orange;
      icon = Icons.warning_amber_rounded;
      title = 'Certificate Mismatch';
      subtitle =
          'Signatures are valid but the signing key does not match the expected certificate.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignerDetailCard extends StatelessWidget {
  const _SignerDetailCard({
    required this.index,
    required this.signer,
    required this.expectedNormalized,
  });

  final int index;
  final ApkSignerInfo signer;
  final String expectedNormalized;

  static String _normalize(String fp) => fp.replaceAll(':', '').toUpperCase();

  @override
  Widget build(BuildContext context) {
    final certs = signer.certificates.whereType<CertificateInfo>().toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Signer header
            Row(
              children: [
                Text(
                  'Signer ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                // Scheme chips
                for (final s in [
                  if (signer.hasV1Signature) 'v1',
                  if (signer.hasV2Signature) 'v2',
                  if (signer.hasV3Signature) 'v3',
                  if (signer.hasV4Signature) 'v4',
                ])
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _SchemeBadge(label: s, active: true, small: true),
                  ),
              ],
            ),

            if (certs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No certificates.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              )
            else
              for (int ci = 0; ci < certs.length; ci++) ...[
                const SizedBox(height: 10),
                if (certs.length > 1)
                  Text(
                    'Certificate ${ci + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                const SizedBox(height: 6),
                _CertRows(
                  cert: certs[ci],
                  expectedNormalized: expectedNormalized,
                  normalize: _normalize,
                ),
              ],

            // Per-signer errors / warnings
            if (signer.errors.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final e in signer.errors.whereType<String>())
                _IssueRow(e, color: Colors.red),
            ],
            if (signer.warnings.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final w in signer.warnings.whereType<String>())
                _IssueRow(w, color: Colors.orange),
            ],
          ],
        ),
      ),
    );
  }
}

class _CertRows extends StatelessWidget {
  const _CertRows({
    required this.cert,
    required this.expectedNormalized,
    required this.normalize,
  });

  final CertificateInfo cert;
  final String expectedNormalized;
  final String Function(String) normalize;

  @override
  Widget build(BuildContext context) {
    final fpNorm = normalize(cert.sha256Fingerprint);
    final matches = fpNorm == expectedNormalized;

    final validFrom = DateTime.fromMillisecondsSinceEpoch(
      cert.validFromMs,
    ).toLocal();
    final validUntil = DateTime.fromMillisecondsSinceEpoch(
      cert.validUntilMs,
    ).toLocal();
    final now = DateTime.now();
    final expired = now.isAfter(validUntil);
    final notYetValid = now.isBefore(validFrom);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRow(label: 'Subject', value: cert.subjectDn),
        _DetailRow(label: 'Issuer', value: cert.issuerDn),
        _DetailRow(label: 'Serial', value: cert.serialNumber, mono: true),
        // SHA-256 row with match indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Label('SHA-256'),
              Expanded(
                child: Text(
                  cert.sha256Fingerprint,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                matches ? Icons.check_circle : Icons.highlight_off,
                size: 18,
                color: matches ? Colors.green : Colors.red,
              ),
            ],
          ),
        ),
        _DetailRow(
          label: 'Valid from',
          value: _formatDate(validFrom),
          valueColor: notYetValid ? Colors.orange : null,
        ),
        _DetailRow(
          label: 'Valid until',
          value: '${_formatDate(validUntil)}${expired ? '  ⚠ EXPIRED' : ''}',
          valueColor: expired ? Colors.red : null,
        ),
      ],
    );
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}-${_p(dt.month)}-${_p(dt.day)} '
      '${_p(dt.hour)}:${_p(dt.minute)}:${_p(dt.second)}';

  static String _p(int v) => v.toString().padLeft(2, '0');
}

class _FingerprintRow extends StatelessWidget {
  const _FingerprintRow({
    required this.index,
    required this.fingerprint,
    required this.normalize,
    required this.expectedNormalized,
  });

  final int index;
  final String fingerprint;
  final String Function(String) normalize;
  final String expectedNormalized;

  @override
  Widget build(BuildContext context) {
    final matches = normalize(fingerprint) == expectedNormalized;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('Found ${index + 1}'),
          Expanded(
            child: Text(
              fingerprint,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            matches ? Icons.check_circle : Icons.highlight_off,
            size: 18,
            color: matches ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }
}

class _SchemeBadge extends StatelessWidget {
  const _SchemeBadge({
    required this.label,
    required this.active,
    this.small = false,
  });

  final String label;
  final bool active;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.indigo : Colors.grey.shade300;
    final textColor = active ? Colors.white : Colors.grey.shade500;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 88,
    child: Text(
      '$text:',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.fullValue,
    this.mono = false,
    this.copyable = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? fullValue;
  final bool mono;
  final bool copyable;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(label),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: mono ? 'monospace' : null,
                color: valueColor,
              ),
            ),
          ),
          if (copyable)
            InkWell(
              onTap: () =>
                  Clipboard.setData(ClipboardData(text: fullValue ?? value)),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.copy_outlined, size: 14, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: TextStyle(color: color, fontSize: 12)),
        ),
      ],
    ),
  );
}

// ── File picker row ───────────────────────────────────────────────────────────

class _FilePicker extends StatelessWidget {
  const _FilePicker({
    required this.label,
    required this.controller,
    required this.onPick,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onPick;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            readOnly: true,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onPick,
          icon: const Icon(Icons.folder_open_outlined),
          tooltip: 'Pick file',
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
