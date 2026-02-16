import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static final ApiConfig _instance = ApiConfig._internal();
  factory ApiConfig() => _instance;
  ApiConfig._internal();

  String? _apiKey;

  /// Initialize API configuration from .env file
  Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
    _apiKey = dotenv.env['GOOGLE_CLOUD_API_KEY'];
    
    if (_apiKey == null || _apiKey!.isEmpty || _apiKey == 'your_api_key_here') {
      throw Exception(
        'GOOGLE_CLOUD_API_KEY not configured. Please add your API key to .env file.'
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

  // Google Cloud API endpoints
  static const String speechToTextEndpoint = 
      'https://speech.googleapis.com/v1/speech:recognize';
  
  static const String speechToTextLongRunningEndpoint = 
      'https://speech.googleapis.com/v1/speech:longrunningrecognize';
  
  static const String translationEndpoint = 
      'https://translation.googleapis.com/language/translate/v2';
  
  static const String textToSpeechEndpoint = 
      'https://texttospeech.googleapis.com/v1/text:synthesize';
}
