import 'dart:io';
import 'package:fpdart/fpdart.dart';
import '../../domain/repositories/translation_repository.dart';
import '../datasources/tts_data_source.dart';
import '../../../../core/errors/failures.dart';

class TranslationRepositoryImpl implements TranslationRepository {
  final TtsDataSource _ttsDataSource;

  TranslationRepositoryImpl(this._ttsDataSource);

  @override
  Future<Either<Failure, String>> transcribeAudio(File audioFile) async {
    // Not implemented - user provides text file directly
    return const Left(ServerFailure('Transcription not supported'));
  }

  @override
  Future<Either<Failure, String>> translateText(String text, String targetLanguage) async {
    // Not implemented - user provides translated text
    return const Left(ServerFailure('Translation not supported'));
  }

  @override
  Future<Either<Failure, File>> generateSpeech(String text, String language, {Function(String)? onProgress}) async {
    return _retryOperation(
      () async {
        try {
          final audioFile = await _ttsDataSource.generateSpeech(text, language, onProgress: onProgress);
          return Right(audioFile);
        } catch (e) {
          if (e is Failure) {
            return Left(e);
          }
          return Left(ServerFailure(e.toString()));
        }
      },
      maxRetries: 2,
    );
  }

  /// Retry operation with exponential backoff
  Future<Either<Failure, T>> _retryOperation<T>(
    Future<Either<Failure, T>> Function() operation, {
    required int maxRetries,
  }) async {
    int retryCount = 0;

    while (true) {
      try {
        final result = await operation();
        
        // If operation succeeded or returned a non-retryable failure, return
        return result.fold(
          (failure) {
            // Don't retry on these failures
            if (failure is QuotaExceededFailure ||
                failure is TimeoutFailure ||
                failure is InvalidFormatFailure ||
                failure is FileTooLargeFailure) {
              return Left(failure);
            }
            
            // Retry on other failures
            throw failure;
          },
          (success) => Right(success),
        );
      } catch (e) {
        retryCount++;
        if (retryCount > maxRetries) {
          if (e is Failure) {
            return Left(e);
          }
          return Left(ServerFailure(e.toString()));
        }
        
        // Exponential backoff
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
  }
}
