import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_apksig/flutter_apksig.dart';

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final _apksig = FlutterApksig();
  final _apkCtrl = TextEditingController();

  bool _loading = false;
  ApkVerifyResult? _result;
  String? _error;

  @override
  void dispose() {
    _apkCtrl.dispose();
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
    if (path.isEmpty) return;

    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });

    try {
      final result = await _apksig.verifyApk(path);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify APK')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── APK picker ────────────────────────────────────────────────────
          _FilePicker(
            label: 'APK File',
            controller: _apkCtrl,
            onPick: _pickApk,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading || _apkCtrl.text.isEmpty ? null : _verify,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.verified_outlined),
            label: const Text('Verify'),
          ),
          const SizedBox(height: 24),

          // ── Result ────────────────────────────────────────────────────────
          if (_error != null) _ErrorCard(_error!),
          if (_result != null) _VerifyResultCard(result: _result!),
        ],
      ),
    );
  }
}

// ── Result card ──────────────────────────────────────────────────────────────

class _VerifyResultCard extends StatelessWidget {
  const _VerifyResultCard({required this.result});
  final ApkVerifyResult result;

  @override
  Widget build(BuildContext context) {
    final signers = result.signers.whereType<ApkSignerInfo>().toList();
    final first = signers.firstOrNull;
    final schemes = first == null
        ? <String>[]
        : [
            if (first.hasV1Signature) 'v1',
            if (first.hasV2Signature) 'v2',
            if (first.hasV3Signature) 'v3',
            if (first.hasV4Signature) 'v4',
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status row
        Row(
          children: [
            Icon(
              result.verified ? Icons.check_circle : Icons.cancel,
              color: result.verified ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.verified ? 'Verified' : 'Not verified',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (schemes.isNotEmpty)
                  Text(
                    'Schemes: ${schemes.join(' + ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),

        // Top-level errors / warnings
        if (result.errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          _IssueList(
            title: 'Errors',
            items: result.errors.whereType<String>().toList(),
            color: Colors.red,
          ),
        ],
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          _IssueList(
            title: 'Warnings',
            items: result.warnings.whereType<String>().toList(),
            color: Colors.orange,
          ),
        ],

        // Per-signer certificates
        if (signers.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Signers', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final signer in signers) _SignerCard(signer: signer),
        ],
      ],
    );
  }
}

class _SignerCard extends StatelessWidget {
  const _SignerCard({required this.signer});
  final ApkSignerInfo signer;

  @override
  Widget build(BuildContext context) {
    final certs = signer.certificates.whereType<CertificateInfo>().toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final cert in certs) ...[
              _InfoRow('Subject', cert.subjectDn),
              _InfoRow('Issuer', cert.issuerDn),
              _InfoRow('Serial', cert.serialNumber),
              _InfoRow('SHA-256', cert.sha256Fingerprint, mono: true),
              _InfoRow(
                'Valid from',
                DateTime.fromMillisecondsSinceEpoch(
                  cert.validFromMs,
                ).toLocal().toString().split('.')[0],
              ),
              _InfoRow(
                'Valid until',
                DateTime.fromMillisecondsSinceEpoch(
                  cert.validUntilMs,
                ).toLocal().toString().split('.')[0],
              ),
            ],
            if (signer.errors.isNotEmpty) ...[
              const SizedBox(height: 6),
              _IssueList(
                title: 'Errors',
                items: signer.errors.whereType<String>().toList(),
                color: Colors.red,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _FilePicker extends StatelessWidget {
  const _FilePicker({
    required this.label,
    required this.controller,
    required this.onPick,
  });
  final String label;
  final TextEditingController controller;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            readOnly: true,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.mono = false});
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueList extends StatelessWidget {
  const _IssueList({
    required this.title,
    required this.items,
    required this.color,
  });
  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 12,
          ),
        ),
        for (final item in items)
          Text('• $item', style: TextStyle(color: color, fontSize: 12)),
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
