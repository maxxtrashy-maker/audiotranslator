import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static final ApiConfig _instance = ApiConfig._internal();
  factory ApiConfig() => _instance;
  ApiConfig._internal();

  String? _apiKey;
  String? _groqApiKey;
  String? _deeplApiKey;

  /// Initialize API configuration from .env file
  Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
    _apiKey = dotenv.env['GOOGLE_CLOUD_API_KEY'];
    _groqApiKey = dotenv.env['GROQ_API_KEY'];
    _deeplApiKey = dotenv.env['DEEPL_API_KEY'];

    if (_apiKey == null || _apiKey!.isEmpty || _apiKey == 'your_api_key_here') {
      throw Exception(
        'GOOGLE_CLOUD_API_KEY not configured. Please add your API key to .env file.'
      );
    }
    if (_groqApiKey == null || _groqApiKey!.isEmpty || _groqApiKey == 'your_groq_api_key_here') {
      throw Exception(
        'GROQ_API_KEY not configured. Please add your API key to .env file.'
      );
    }
    if (_deeplApiKey == null || _deeplApiKey!.isEmpty || _deeplApiKey == 'your_deepl_api_key_here') {
      throw Exception(
        'DEEPL_API_KEY not configured. Please add your API key to .env file.'
      );
    }
  }

  /// Get the Google Cloud API key
  String get apiKey {
    if (_apiKey == null) {
      throw Exception('ApiConfig not initialized. Call initialize() first.');
    }
    return _apiKey!;
  }

  /// Get the Groq API key
  String get groqApiKey {
    if (_groqApiKey == null) {
      throw Exception('ApiConfig not initialized. Call initialize() first.');
    }
    return _groqApiKey!;
  }

  /// Get the DeepL API key
  String get deeplApiKey {
    if (_deeplApiKey == null) {
      throw Exception('ApiConfig not initialized. Call initialize() first.');
    }
    return _deeplApiKey!;
  }

  // API endpoints
  static const String groqSttEndpoint =
      'https://api.groq.com/openai/v1/audio/transcriptions';

  static const String deeplTranslationEndpoint =
      'https://api-free.deepl.com/v2/translate';

  static const String textToSpeechEndpoint =
      'https://texttospeech.googleapis.com/v1/text:synthesize';
}
