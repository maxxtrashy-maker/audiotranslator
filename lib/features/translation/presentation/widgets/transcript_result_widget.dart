import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class TranscriptResultWidget extends StatelessWidget {
  final String transcript;
  final String? translatedText;
  final VoidCallback onNewExtraction;
  final List<File> savedFiles;

  const TranscriptResultWidget({
    super.key,
    required this.transcript,
    this.translatedText,
    required this.onNewExtraction,
    this.savedFiles = const [],
  });

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Texte copié dans le presse-papier'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareFiles() async {
    if (savedFiles.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(files: savedFiles.map((f) => XFile(f.path)).toList()),
    );
  }

  Widget _buildTextCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String text,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${text.length} caractères',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copyToClipboard(context, text),
                  tooltip: 'Copier',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Translated text (primary — shown first if available)
        if (translatedText != null)
          _buildTextCard(
            context,
            title: 'Traduction française',
            icon: Icons.translate,
            text: translatedText!,
          ),

        if (translatedText != null) const SizedBox(height: 8),

        // Original transcript
        _buildTextCard(
          context,
          title: 'Sous-titres originaux',
          icon: Icons.subtitles,
          text: transcript,
        ),

        const SizedBox(height: 10),
        Row(
          children: [
            if (savedFiles.isNotEmpty)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareFiles,
                  icon: const Icon(Icons.share),
                  label: const Text('Partager'),
                ),
              ),
            if (savedFiles.isNotEmpty) const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onNewExtraction,
                icon: const Icon(Icons.refresh),
                label: const Text('Nouvelle extraction'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
