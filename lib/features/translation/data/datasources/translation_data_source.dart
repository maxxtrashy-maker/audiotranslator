import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/errors/failures.dart';

abstract class TranslationDataSource {
  Future<String> translateText(String text, String targetLanguage);
}

class TranslationDataSourceImpl implements TranslationDataSource {
  final http.Client _client;
  final ApiConfig _apiConfig;

  TranslationDataSourceImpl(this._client, this._apiConfig);

  @override
  Future<String> translateText(String text, String targetLanguage) async {
    try {
      // Prepare request parameters
      final uri = Uri.parse(ApiConfig.translationEndpoint).replace(
        queryParameters: {
          'key': _apiConfig.apiKey,
          'q': text,
          'target': _getLanguageCode(targetLanguage),
          'format': 'text',
        },
      );

      // Make API request
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw const TimeoutFailure('Translation request timed out'),
      );

      // Handle response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Extract translation
        final translations = data['data']['translations'] as List;
        
        if (translations.isEmpty) {
          throw const ServerFailure('No translation result');
        }
        
        return translations[0]['translatedText'] as String;
      } else if (response.statusCode == 429) {
        throw const QuotaExceededFailure(
          'Translation quota exceeded (500K chars/month). Try again tomorrow.'
        );
      } else if (response.statusCode == 403) {
        throw const ServerFailure(
          'API key invalid or Translation API not enabled in Google Cloud Console'
        );
      } else {
        final error = jsonDecode(response.body);
        throw ServerFailure(
          'Translation API error: ${error['error']?['message'] ?? 'Unknown error'}'
        );
      }
    } on TimeoutException {
      throw const TimeoutFailure('Translation request timed out after 30 seconds');
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('Failed to translate text: ${e.toString()}');
    }
  }

  /// Convert language name to ISO 639-1 code
  String _getLanguageCode(String language) {
    final languageMap = {
      'French': 'fr',
      'English': 'en',
      'Spanish': 'es',
      'German': 'de',
      'Italian': 'it',
      'Portuguese': 'pt',
      'Japanese': 'ja',
      'Chinese': 'zh',
      'Korean': 'ko',
      'Arabic': 'ar',
    };
    
    return languageMap[language] ?? language.toLowerCase();
  }
}
