import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class TranscriptResultWidget extends StatelessWidget {
  final String transcript;
  final VoidCallback onNewExtraction;
  final File? savedFile;

  const TranscriptResultWidget({
    super.key,
    required this.transcript,
    required this.onNewExtraction,
    this.savedFile,
  });

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: transcript));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Texte copié dans le presse-papier'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareFile() async {
    if (savedFile == null) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(savedFile!.path)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.subtitles, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Sous-titres extraits',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${transcript.length} caractères',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      transcript,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copyToClipboard(context),
                icon: const Icon(Icons.copy),
                label: const Text('Copier'),
              ),
            ),
            if (savedFile != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareFile,
                  icon: const Icon(Icons.share),
                  label: const Text('Partager'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onNewExtraction,
          icon: const Icon(Icons.refresh),
          label: const Text('Nouvelle extraction'),
        ),
      ],
    );
  }
}
