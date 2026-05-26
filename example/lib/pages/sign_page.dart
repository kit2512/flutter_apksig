import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_apksig/flutter_apksig.dart';

class SignPage extends StatefulWidget {
  const SignPage({super.key});

  @override
  State<SignPage> createState() => _SignPageState();
}

class _SignPageState extends State<SignPage> {
  final _apksig = FlutterApksig();

  final _inputCtrl = TextEditingController();
  final _outputCtrl = TextEditingController();
  final _ksCtrl = TextEditingController();
  final _ksPassCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  final _keyPassCtrl = TextEditingController();

  bool _loading = false;
  bool _ksPassVisible = false;
  bool _keyPassVisible = false;
  String? _successMsg;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _inputCtrl,
      _outputCtrl,
      _ksCtrl,
      _ksPassCtrl,
      _aliasCtrl,
      _keyPassCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickApk() async {
    // FileType.any — .apk has no registered MIME type on Android,
    // so FileType.custom would show an empty file picker.
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    if (picked != null && picked.files.single.path != null) {
      final path = picked.files.single.path!;
      setState(() {
        _inputCtrl.text = path;
        // Auto-suggest output path: insert "_signed" before extension
        if (_outputCtrl.text.isEmpty) {
          _outputCtrl.text = path.replaceFirst(
            RegExp(r'\.apk$', caseSensitive: false),
            '_signed.apk',
          );
        }
        _successMsg = null;
        _error = null;
      });
    }
  }

  Future<void> _pickKeystore() async {
    // FileType.any is required because .jks/.keystore have no registered
    // MIME type on Android — the system picker hides them with FileType.custom.
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    if (picked != null && picked.files.single.path != null) {
      setState(() => _ksCtrl.text = picked.files.single.path!);
    }
  }

  Future<void> _sign() async {
    setState(() {
      _loading = true;
      _successMsg = null;
      _error = null;
    });

    try {
      await _apksig.signApk(
        ApkSignRequest(
          inputApkPath: _inputCtrl.text.trim(),
          outputApkPath: _outputCtrl.text.trim(),
          keystorePath: _ksCtrl.text.trim(),
          keystorePassword: _ksPassCtrl.text,
          keyAlias: _aliasCtrl.text.trim(),
          keyPassword: _keyPassCtrl.text,
        ),
      );
      setState(() => _successMsg = _outputCtrl.text.trim());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  bool get _canSign =>
      !_loading &&
      _inputCtrl.text.isNotEmpty &&
      _outputCtrl.text.isNotEmpty &&
      _ksCtrl.text.isNotEmpty &&
      _ksPassCtrl.text.isNotEmpty &&
      _aliasCtrl.text.isNotEmpty &&
      _keyPassCtrl.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign APK')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── APK paths ─────────────────────────────────────────────────────
          _sectionLabel(context, 'APK'),
          _FilePicker(
            label: 'Input APK',
            controller: _inputCtrl,
            onPick: _pickApk,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _outputCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Output APK path',
              border: OutlineInputBorder(),
              isDense: true,
              helperText: 'Can equal input path for in-place signing.',
            ),
          ),
          const SizedBox(height: 20),

          // ── Keystore ──────────────────────────────────────────────────────
          _sectionLabel(context, 'Keystore'),
          _FilePicker(
            label: 'Keystore file (.jks / .p12)',
            controller: _ksCtrl,
            onPick: _pickKeystore,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ksPassCtrl,
            obscureText: !_ksPassVisible,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Keystore password',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(
                  _ksPassVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _ksPassVisible = !_ksPassVisible),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _aliasCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Key alias',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyPassCtrl,
            obscureText: !_keyPassVisible,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Key password',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(
                  _keyPassVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _keyPassVisible = !_keyPassVisible),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Sign button ───────────────────────────────────────────────────
          FilledButton.icon(
            onPressed: _canSign ? _sign : null,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.draw_outlined),
            label: const Text('Sign APK'),
          ),
          const SizedBox(height: 24),

          // ── Result ────────────────────────────────────────────────────────
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          if (_successMsg != null)
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Signed successfully!',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _successMsg!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
}

// ── Shared widget ─────────────────────────────────────────────────────────────

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
