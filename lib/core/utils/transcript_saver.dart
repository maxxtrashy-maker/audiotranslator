import 'dart:io';
import 'package:path_provider/path_provider.dart';

class TranscriptSaver {
  /// Saves [text] to a .txt file named after [label] inside the Elokens/ folder.
  /// Returns the created [File].
  static Future<File> save({
    required String text,
    required String label,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final elokensDir = Directory('${docsDir.path}/Elokens');
    if (!await elokensDir.exists()) {
      await elokensDir.create(recursive: true);
    }

    final sanitised = label
        .replaceAll(RegExp(r'[^\w\s\-]', unicode: true), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();

    final fileName = sanitised.isEmpty ? 'transcript' : sanitised;
    final file = File('${elokensDir.path}/$fileName.txt');
    await file.writeAsString(text, flush: true);
    return file;
  }
}
