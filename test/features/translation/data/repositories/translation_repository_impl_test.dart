import 'dart:io';
import 'package:audiotranslator/core/errors/failures.dart';
import 'package:audiotranslator/features/translation/data/datasources/gemini_data_source.dart';
import 'package:audiotranslator/features/translation/data/datasources/tts_data_source.dart';
import 'package:audiotranslator/features/translation/data/repositories/translation_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockGeminiDataSource extends Mock implements GeminiDataSource {}
class MockTtsDataSource extends Mock implements TtsDataSource {}
class FakeFile extends Fake implements File {}

void main() {
  late TranslationRepositoryImpl repository;
  late MockGeminiDataSource mockGeminiDataSource;
  late MockTtsDataSource mockTtsDataSource;

  setUp(() {
    mockGeminiDataSource = MockGeminiDataSource();
    mockTtsDataSource = MockTtsDataSource();
    repository = TranslationRepositoryImpl(mockGeminiDataSource, mockTtsDataSource);
    registerFallbackValue(FakeFile());
  });

  const tText = 'Hello World';
  const tTranslatedText = 'Bonjour le monde';
  final tFile = FakeFile();

  group('transcribeAudio', () {
    test('should return transcription when call to data source is successful', () async {
      // Arrange
      when(() => mockGeminiDataSource.transcribeAudio(any())).thenAnswer((_) async => tText);
      // Act
      final result = await repository.transcribeAudio(tFile);
      // Assert
      expect(result, const Right(tText));
      verify(() => mockGeminiDataSource.transcribeAudio(tFile)).called(1);
    });

    test('should return ServerFailure when call to data source is unsuccessful', () async {
      // Arrange
      when(() => mockGeminiDataSource.transcribeAudio(any())).thenThrow(const ServerFailure('Server Error'));
      // Act
      final result = await repository.transcribeAudio(tFile);
      // Assert
      expect(result, const Left(ServerFailure('Server Error')));
      verify(() => mockGeminiDataSource.transcribeAudio(tFile)).called(1);
    });
  });

  group('translateText', () {
    test('should return translated text when call to data source is successful', () async {
      // Arrange
      when(() => mockGeminiDataSource.translateText(any(), any())).thenAnswer((_) async => tTranslatedText);
      // Act
      final result = await repository.translateText(tText, 'French');
      // Assert
      expect(result, const Right(tTranslatedText));
      verify(() => mockGeminiDataSource.translateText(tText, 'French')).called(1);
    });
  });

  group('generateSpeech', () {
    test('should return audio file when call to data source is successful', () async {
      // Arrange
      when(() => mockTtsDataSource.generateSpeech(any(), any())).thenAnswer((_) async => tFile);
      // Act
      final result = await repository.generateSpeech(tTranslatedText, 'fr-FR');
      // Assert
      expect(result, Right(tFile));
      verify(() => mockTtsDataSource.generateSpeech(tTranslatedText, 'fr-FR')).called(1);
    });
  });
}
