import 'dart:io';
import 'package:fpdart/fpdart.dart';
import '../../domain/repositories/translation_repository.dart';
import '../datasources/speech_to_text_data_source.dart';
import '../datasources/translation_data_source.dart';
import '../datasources/tts_data_source.dart';
import '../../../../core/errors/failures.dart';

class TranslationRepositoryImpl implements TranslationRepository {
  final SpeechToTextDataSource _sttDataSource;
  final TranslationDataSource _translationDataSource;
  final TtsDataSource _ttsDataSource;

  TranslationRepositoryImpl(
    this._sttDataSource,
    this._translationDataSource,
    this._ttsDataSource,
  );

  @override
  Future<Either<Failure, String>> transcribeAudio(File audioFile) async {
    return _retryOperation(
      () async {
        try {
          final text = await _sttDataSource.transcribeAudio(audioFile);
          return Right(text);
        } catch (e) {
          if (e is Failure) return Left(e);
          return Left(ServerFailure(e.toString()));
        }
      },
      maxRetries: 2,
    );
  }

  @override
  Future<Either<Failure, String>> translateText(String text, String targetLanguage) async {
    return _retryOperation(
      () async {
        try {
          final translated = await _translationDataSource.translateText(text, targetLanguage);
          return Right(translated);
        } catch (e) {
          if (e is Failure) return Left(e);
          return Left(ServerFailure(e.toString()));
        }
      },
      maxRetries: 2,
    );
  }

  @override
  Future<Either<Failure, File>> generateSpeech(String text, String language, {Function(String)? onProgress}) async {
    return _retryOperation(
      () async {
        try {
          final audioFile = await _ttsDataSource.generateSpeech(text, language, onProgress: onProgress);
          return Right(audioFile);
        } catch (e) {
          if (e is Failure) return Left(e);
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

        return result.fold(
          (failure) {
            if (failure is QuotaExceededFailure ||
                failure is TimeoutFailure ||
                failure is InvalidFormatFailure ||
                failure is FileTooLargeFailure) {
              return Left(failure);
            }
            throw failure;
          },
          (success) => Right(success),
        );
      } catch (e) {
        retryCount++;
        if (retryCount > maxRetries) {
          if (e is Failure) return Left(e);
          return Left(ServerFailure(e.toString()));
        }
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
  }
}
