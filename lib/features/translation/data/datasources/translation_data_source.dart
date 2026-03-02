import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/errors/failures.dart';

abstract class TranslationDataSource {
  Future<String> translateText(String text, String targetLanguage);
}

class DeeplTranslationDataSourceImpl implements TranslationDataSource {
  final http.Client _client;
  final ApiConfig _apiConfig;

  DeeplTranslationDataSourceImpl(this._client, this._apiConfig);

  @override
  Future<String> translateText(String text, String targetLanguage) async {
    try {
      final response = await _client.post(
        Uri.parse(ApiConfig.deeplTranslationEndpoint),
        headers: {
          'Authorization': 'DeepL-Auth-Key ${_apiConfig.deeplApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': [text],
          'target_lang': targetLanguage,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw const TimeoutFailure('La traduction a d\u00e9pass\u00e9 le d\u00e9lai (30s).'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translations = data['translations'] as List;
        if (translations.isEmpty) {
          throw const ServerFailure('Aucun r\u00e9sultat de traduction.');
        }
        return translations[0]['text'] as String;
      } else if (response.statusCode == 429) {
        throw const QuotaExceededFailure(
          'Quota DeepL d\u00e9pass\u00e9. R\u00e9essayez plus tard.',
        );
      } else if (response.statusCode == 456) {
        throw const QuotaExceededFailure(
          'Quota mensuel DeepL atteint. R\u00e9essayez le mois prochain.',
        );
      } else if (response.statusCode == 403) {
        throw const ServerFailure(
          'Cl\u00e9 API DeepL invalide. V\u00e9rifiez votre fichier .env.',
        );
      } else {
        final error = jsonDecode(response.body);
        final message = error['message'] ?? 'Erreur inconnue';
        throw ServerFailure('Erreur DeepL : $message');
      }
    } on TimeoutException {
      throw const TimeoutFailure(
        'La traduction a d\u00e9pass\u00e9 le d\u00e9lai (30s).',
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('Erreur de traduction : ${e.toString()}');
    }
  }
}
