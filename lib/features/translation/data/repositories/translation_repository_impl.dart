import 'dart:io';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/repositories/translation_repository.dart';
import '../datasources/gemini_data_source.dart';
import '../datasources/tts_data_source.dart';

class TranslationRepositoryImpl implements TranslationRepository {
  final GeminiDataSource _geminiDataSource;
  final TtsDataSource _ttsDataSource;

  TranslationRepositoryImpl(this._geminiDataSource, this._ttsDataSource);

  @override
  ResultFuture<String> transcribeAudio(File audioFile) async {
    try {
      final result = await _geminiDataSource.transcribeAudio(audioFile);
      return Right(result);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  ResultFuture<String> translateText(String text, String targetLanguage) async {
    try {
      final result = await _geminiDataSource.translateText(text, targetLanguage);
      return Right(result);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  ResultFuture<File> generateSpeech(String text, String language) async {
    try {
      final result = await _ttsDataSource.generateSpeech(text, language);
      return Right(result);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(e.toString()));
    }
  }
}
