import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/mime_detector.dart';

abstract class SpeechToTextDataSource {
  Future<String> transcribeAudio(File audioFile);
}

class SpeechToTextDataSourceImpl implements SpeechToTextDataSource {
  final http.Client _client;
  final ApiConfig _apiConfig;

  SpeechToTextDataSourceImpl(this._client, this._apiConfig);

  @override
  Future<String> transcribeAudio(File audioFile) async {
    try {
      // Read audio file as bytes
      final bytes = await audioFile.readAsBytes();
      
      // Encode to base64
      final audioContent = base64Encode(bytes);
      
      // Detect MIME type
      final mimeType = MimeDetector.getMimeTypeForApi(audioFile);
      
      // Prepare request body for long-running recognize
      final requestBody = {
        'config': {
          'encoding': _getEncodingFromMimeType(mimeType),
          'languageCode': 'en-US',
          'enableAutomaticPunctuation': true,
          'model': 'default',
        },
        'audio': {
          'content': audioContent,
        },
      };

      // Use longrunningrecognize endpoint for files of any length
      final response = await _client.post(
        Uri.parse('${ApiConfig.speechToTextLongRunningEndpoint}?key=${_apiConfig.apiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw const TimeoutFailure('Speech-to-Text request timed out'),
      );

      // Handle response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Extract operation name for polling
        final operationName = data['name'] as String?;
        
        if (operationName == null) {
          throw const ServerFailure('No operation name returned from API');
        }
        
        // Poll for results
        return await _pollForResults(operationName);
      } else if (response.statusCode == 429) {
        throw const QuotaExceededFailure(
          'Speech-to-Text quota exceeded. Try again tomorrow or upgrade your plan.'
        );
      } else if (response.statusCode == 403) {
        throw const ServerFailure(
          'API key invalid or Speech-to-Text API not enabled in Google Cloud Console'
        );
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        final message = error['error']?['message'] ?? 'Unknown error';
        
        // Check for common errors
        if (message.contains('longer than 1 minute')) {
          throw const ServerFailure(
            'Audio file too long for synchronous processing. Please use a shorter file.'
          );
        }
        
        throw ServerFailure('Speech-to-Text API error: $message');
      } else {
        final error = jsonDecode(response.body);
        throw ServerFailure(
          'Speech-to-Text API error: ${error['error']?['message'] ?? 'Unknown error'}'
        );
      }
    } on TimeoutException {
      throw const TimeoutFailure('Speech-to-Text request timed out after 30 seconds');
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('Failed to transcribe audio: ${e.toString()}');
    }
  }

  /// Poll for long-running operation results
  Future<String> _pollForResults(String operationName) async {
    const maxAttempts = 60; // Max 5 minutes (60 * 5 seconds)
    int attempts = 0;

    while (attempts < maxAttempts) {
      attempts++;
      
      // Wait before polling (exponential backoff)
      final waitTime = attempts < 5 ? 2 : 5; // 2s for first 4 attempts, then 5s
      await Future.delayed(Duration(seconds: waitTime));

      try {
        final response = await _client.get(
          Uri.parse('https://speech.googleapis.com/v1/operations/$operationName?key=${_apiConfig.apiKey}'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw const TimeoutFailure('Polling request timed out'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          // Check if operation is done
          final done = data['done'] as bool?;
          
          if (done == true) {
            // Check for errors
            if (data['error'] != null) {
              final errorMessage = data['error']['message'] ?? 'Unknown error';
              throw ServerFailure('Transcription failed: $errorMessage');
            }
            
            // Extract results
            final response = data['response'];
            if (response == null || response['results'] == null) {
              throw const ServerFailure('No transcription result from audio');
            }
            
            final results = response['results'] as List;
            if (results.isEmpty) {
              throw const ServerFailure('No transcription result from audio');
            }
            
            // Concatenate all transcripts
            final transcripts = results
                .map((result) => result['alternatives']?[0]?['transcript'] as String?)
                .where((t) => t != null)
                .join(' ');
            
            if (transcripts.isEmpty) {
              throw const ServerFailure('No transcription alternatives found');
            }
            
            return transcripts;
          }
          
          // Operation still in progress, continue polling
        } else {
          throw ServerFailure('Failed to poll operation status: ${response.statusCode}');
        }
      } catch (e) {
        if (e is Failure) rethrow;
        // Continue polling on transient errors
        if (attempts >= maxAttempts) {
          throw ServerFailure('Polling failed after $maxAttempts attempts: ${e.toString()}');
        }
      }
    }

    throw const TimeoutFailure('Transcription timed out after 5 minutes');
  }

  /// Convert MIME type to Google Cloud encoding format
  String _getEncodingFromMimeType(String mimeType) {
    if (mimeType.contains('flac')) return 'FLAC';
    if (mimeType.contains('wav')) return 'LINEAR16';
    if (mimeType.contains('ogg')) return 'OGG_OPUS';
    if (mimeType.contains('mp4') || mimeType.contains('m4a')) return 'MP3';
    return 'MP3'; // Default
  }
}
