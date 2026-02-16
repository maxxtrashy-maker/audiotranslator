import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../../core/errors/failures.dart';

abstract class GeminiDataSource {
  Future<String> transcribeAudio(File audioFile);
  Future<String> translateText(String text, String targetLanguage);
}

class GeminiDataSourceImpl implements GeminiDataSource {
  final GenerativeModel _model;

  GeminiDataSourceImpl(this._model);

  @override
  Future<String> transcribeAudio(File audioFile) async {
    try {
      final bytes = await audioFile.readAsBytes();
      // Simple mime type detection or assumption
      String mimeType = 'audio/mp3';
      if (audioFile.path.endsWith('.wav')) mimeType = 'audio/wav';
      if (audioFile.path.endsWith('.m4a')) mimeType = 'audio/m4a';

      final content = [
        Content.multi([
          TextPart('Please transcribe the following audio file verbatim.'),
          DataPart(mimeType, bytes),
        ])
      ];

      final response = await _model.generateContent(content);
      if (response.text == null) {
        throw const ServerFailure('No transcription result.');
      }
      return response.text!;
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<String> translateText(String text, String targetLanguage) async {
    try {
      final content = [
        Content.text('Translate the following text to $targetLanguage:\n\n$text')
      ];
      final response = await _model.generateContent(content);
      if (response.text == null) {
        throw const ServerFailure('No translation result.');
      }
      return response.text!;
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
