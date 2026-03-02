import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/errors/failures.dart';

abstract class SpeechToTextDataSource {
  Future<String> transcribeAudio(File audioFile);
}

class GroqSpeechToTextDataSourceImpl implements SpeechToTextDataSource {
  final http.Client _client;
  final ApiConfig _apiConfig;

  GroqSpeechToTextDataSourceImpl(this._client, this._apiConfig);

  @override
  Future<String> transcribeAudio(File audioFile) async {
    try {
      final fileSize = await audioFile.length();
      if (fileSize > 25 * 1024 * 1024) {
        throw const FileTooLargeFailure(
          'Le fichier audio d\u00e9passe 25 Mo (limite Groq).',
        );
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.groqSttEndpoint),
      );

      request.headers['Authorization'] = 'Bearer ${_apiConfig.groqApiKey}';
      request.fields['model'] = 'whisper-large-v3';
      request.files.add(
        await http.MultipartFile.fromPath('file', audioFile.path),
      );

      final streamedResponse = await _client.send(request).timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw const TimeoutFailure(
          'La transcription a d\u00e9pass\u00e9 le d\u00e9lai (120s).',
        ),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['text'] as String?;
        if (text == null || text.trim().isEmpty) {
          throw const ServerFailure(
            'Aucun texte transcrit depuis l\u0027audio.',
          );
        }
        return text;
      } else if (response.statusCode == 429) {
        throw const QuotaExceededFailure(
          'Quota Groq d\u00e9pass\u00e9. R\u00e9essayez plus tard.',
        );
      } else if (response.statusCode == 401) {
        throw const ServerFailure(
          'Cl\u00e9 API Groq invalide. V\u00e9rifiez votre fichier .env.',
        );
      } else if (response.statusCode == 413) {
        throw const FileTooLargeFailure(
          'Fichier audio trop volumineux pour Groq.',
        );
      } else {
        final error = jsonDecode(response.body);
        final message = error['error']?['message'] ?? 'Erreur inconnue';
        throw ServerFailure('Erreur Groq STT : $message');
      }
    } on TimeoutException {
      throw const TimeoutFailure(
        'La transcription a d\u00e9pass\u00e9 le d\u00e9lai (120s).',
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('Erreur de transcription : ${e.toString()}');
    }
  }
}
