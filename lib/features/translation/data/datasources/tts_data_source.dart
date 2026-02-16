import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/text_chunker.dart';
import '../../../../core/utils/wav_concatenator.dart';

abstract class TtsDataSource {
  Future<File> generateSpeech(String text, String language, {Function(String)? onProgress});
}

class TtsDataSourceImpl implements TtsDataSource {
  final http.Client _client;
  final ApiConfig _apiConfig;

  TtsDataSourceImpl(this._client, this._apiConfig);

  @override
  Future<File> generateSpeech(String text, String language, {Function(String)? onProgress}) async {
    // Check if text needs to be chunked
    if (text.length <= 4500) {
      onProgress?.call('Génération de l\'audio...');
      return _generateSingleAudio(text, language);
    } else {
      return _generateAndConcatenate(text, language, onProgress: onProgress);
    }
  }

  /// Generate audio for long texts by chunking and concatenating
  Future<File> _generateAndConcatenate(String text, String language, {Function(String)? onProgress}) async {
    try {
      // Split text into chunks
      final chunks = TextChunker.splitIntelligently(text);
      onProgress?.call('Découpage du texte en ${chunks.length} parties...');
      
      final audioFiles = <File>[];
      
      // Generate audio for each chunk
      for (int i = 0; i < chunks.length; i++) {
        onProgress?.call('Génération audio partie ${i + 1}/${chunks.length}...');
        final audioFile = await _generateSingleAudio(chunks[i], language);
        audioFiles.add(audioFile);
        
        // Small delay to avoid rate limiting
        if (i < chunks.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      // Concatenate all audio files
      onProgress?.call('Assemblage des fichiers audio...');
      final concatenatedFile = await _concatenateAudioFiles(audioFiles);
      
      // Clean up individual chunk files
      for (final file in audioFiles) {
        try {
          await file.delete();
        } catch (_) {
          // Ignore cleanup errors
        }
      }
      
      return concatenatedFile;
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('Failed to generate and concatenate audio: ${e.toString()}');
    }
  }

  /// Generate audio for a single text chunk
  Future<File> _generateSingleAudio(String text, String language) async {
    try {
      // Prepare request body
      final requestBody = {
        'input': {
          'text': text,
        },
        'voice': {
          'languageCode': language,
          'name': _getVoiceName(language),
          'ssmlGender': 'NEUTRAL',
        },
        'audioConfig': {
          'audioEncoding': 'LINEAR16', // WAV format
          'speakingRate': 1.0,
          'pitch': 0.0,
        },
      };

      // Make API request
      final response = await _client.post(
        Uri.parse('${ApiConfig.textToSpeechEndpoint}?key=${_apiConfig.apiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw const TimeoutFailure('Text-to-Speech request timed out'),
      );

      // Handle response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Extract audio content (base64 encoded)
        final audioContent = data['audioContent'] as String;
        
        if (audioContent.isEmpty) {
          throw const ServerFailure('No audio content in response');
        }
        
        // Decode base64 to bytes
        final audioBytes = base64Decode(audioContent);
        
        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final fileName = 'tts_chunk_${DateTime.now().millisecondsSinceEpoch}.wav';
        final file = File('${tempDir.path}/$fileName');
        
        await file.writeAsBytes(audioBytes);
        
        return file;
      } else if (response.statusCode == 429) {
        throw const QuotaExceededFailure(
          'Text-to-Speech quota exceeded. Try again tomorrow or upgrade your plan.'
        );
      } else if (response.statusCode == 403) {
        throw const ServerFailure(
          'API key invalid or Text-to-Speech API not enabled in Google Cloud Console'
        );
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        final errorMessage = error['error']?['message'] ?? 'Unknown error';
        
        // Check if it's a character limit error
        if (errorMessage.contains('exceeds') || errorMessage.contains('limit')) {
          throw const ServerFailure(
            'Text exceeds API character limit. This should not happen with chunking enabled.'
          );
        }
        
        throw ServerFailure('Text-to-Speech API error: $errorMessage');
      } else {
        final error = jsonDecode(response.body);
        throw ServerFailure(
          'Text-to-Speech API error: ${error['error']?['message'] ?? 'Unknown error'}'
        );
      }
    } on TimeoutException {
      throw const TimeoutFailure('Text-to-Speech request timed out after 60 seconds');
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('Failed to generate speech: ${e.toString()}');
    }
  }

  /// Concatenate multiple audio files into one using manual WAV concatenation
  Future<File> _concatenateAudioFiles(List<File> audioFiles) async {
    if (audioFiles.isEmpty) {
      throw const ServerFailure('No audio files to concatenate');
    }
    
    if (audioFiles.length == 1) {
      return audioFiles.first;
    }
    
    try {
      final tempDir = await getTemporaryDirectory();
      final outputFileName = 'translation_${DateTime.now().millisecondsSinceEpoch}.wav';
      final outputPath = '${tempDir.path}/$outputFileName';
      
      // Use WavConcatenator to manually concatenate WAV files
      final concatenatedFile = await WavConcatenator.concatenate(audioFiles, outputPath);
      
      return concatenatedFile;
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('Failed to concatenate audio: ${e.toString()}');
    }
  }

  /// Get the best voice name for the language (using WaveNet for better quality)
  String _getVoiceName(String languageCode) {
    final voiceMap = {
      'fr-FR': 'fr-FR-Wavenet-A',
      'en-US': 'en-US-Wavenet-D',
      'es-ES': 'es-ES-Wavenet-B',
      'de-DE': 'de-DE-Wavenet-A',
      'it-IT': 'it-IT-Wavenet-A',
      'pt-BR': 'pt-BR-Wavenet-A',
      'ja-JP': 'ja-JP-Wavenet-A',
      'zh-CN': 'cmn-CN-Wavenet-A',
      'ko-KR': 'ko-KR-Wavenet-A',
      'ar-XA': 'ar-XA-Wavenet-A',
    };
    
    return voiceMap[languageCode] ?? '$languageCode-Wavenet-A';
  }
}
