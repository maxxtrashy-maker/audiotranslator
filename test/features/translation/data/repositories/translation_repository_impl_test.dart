import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audiotranslator/core/errors/failures.dart';
import 'package:audiotranslator/features/translation/data/datasources/speech_to_text_data_source.dart';
import 'package:audiotranslator/features/translation/data/datasources/translation_data_source.dart';
import 'package:audiotranslator/features/translation/data/datasources/tts_data_source.dart';
import 'package:audiotranslator/features/translation/data/repositories/translation_repository_impl.dart';

class MockSttDataSource extends Mock implements SpeechToTextDataSource {}

class MockTranslationDataSource extends Mock implements TranslationDataSource {}

class MockTtsDataSource extends Mock implements TtsDataSource {}

class FakeFile extends Fake implements File {}

void main() {
  late MockSttDataSource mockStt;
  late MockTranslationDataSource mockTranslation;
  late MockTtsDataSource mockTts;
  late TranslationRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(FakeFile());
  });

  setUp(() {
    mockStt = MockSttDataSource();
    mockTranslation = MockTranslationDataSource();
    mockTts = MockTtsDataSource();
    repository = TranslationRepositoryImpl(mockStt, mockTranslation, mockTts);
  });

  group('transcribeAudio', () {
    final tFile = File('test.wav');

    test('returns Right(text) on success', () async {
      when(() => mockStt.transcribeAudio(any()))
          .thenAnswer((_) async => 'Bonjour le monde');

      final result = await repository.transcribeAudio(tFile);

      expect(result, isA<Right>());
      result.fold(
        (_) => fail('should be Right'),
        (text) => expect(text, 'Bonjour le monde'),
      );
      verify(() => mockStt.transcribeAudio(tFile)).called(1);
    });

    test('returns Left(ServerFailure) when datasource throws ServerFailure', () async {
      when(() => mockStt.transcribeAudio(any()))
          .thenThrow(const ServerFailure('Erreur serveur'));

      final result = await repository.transcribeAudio(tFile);

      expect(result, isA<Left>());
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('should be Left'),
      );
    });

    test('returns Left immediately for QuotaExceededFailure (no retry)', () async {
      when(() => mockStt.transcribeAudio(any()))
          .thenThrow(const QuotaExceededFailure('Quota dépassé'));

      final result = await repository.transcribeAudio(tFile);

      expect(result, isA<Left>());
      result.fold(
        (failure) => expect(failure, isA<QuotaExceededFailure>()),
        (_) => fail('should be Left'),
      );
      verify(() => mockStt.transcribeAudio(tFile)).called(1);
    });

    test('returns Left immediately for FileTooLargeFailure (no retry)', () async {
      when(() => mockStt.transcribeAudio(any()))
          .thenThrow(const FileTooLargeFailure('Trop gros'));

      final result = await repository.transcribeAudio(tFile);

      expect(result, isA<Left>());
      result.fold(
        (failure) => expect(failure, isA<FileTooLargeFailure>()),
        (_) => fail('should be Left'),
      );
      verify(() => mockStt.transcribeAudio(tFile)).called(1);
    });

    test('returns Left immediately for TimeoutFailure (no retry)', () async {
      when(() => mockStt.transcribeAudio(any()))
          .thenThrow(const TimeoutFailure('Timeout'));

      final result = await repository.transcribeAudio(tFile);

      expect(result, isA<Left>());
      result.fold(
        (failure) => expect(failure, isA<TimeoutFailure>()),
        (_) => fail('should be Left'),
      );
      verify(() => mockStt.transcribeAudio(tFile)).called(1);
    });

    test('retries on ServerFailure then succeeds', () async {
      var callCount = 0;
      when(() => mockStt.transcribeAudio(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw const ServerFailure('Erreur transitoire');
        return 'OK';
      });

      final result = await repository.transcribeAudio(tFile);

      expect(result, isA<Right>());
      result.fold(
        (_) => fail('should be Right'),
        (text) => expect(text, 'OK'),
      );
      verify(() => mockStt.transcribeAudio(tFile)).called(2);
    });

    test('returns Left after max retries exceeded', () async {
      when(() => mockStt.transcribeAudio(any()))
          .thenThrow(const ServerFailure('Erreur persistante'));

      final result = await repository.transcribeAudio(tFile);

      expect(result, isA<Left>());
      // 1 initial + 2 retries = 3 calls
      verify(() => mockStt.transcribeAudio(tFile)).called(3);
    });
  });

  group('translateText', () {
    test('returns Right(text) on success', () async {
      when(() => mockTranslation.translateText(any(), any()))
          .thenAnswer((_) async => 'Hello world');

      final result = await repository.translateText('Bonjour le monde', 'EN');

      expect(result, isA<Right>());
      result.fold(
        (_) => fail('should be Right'),
        (text) => expect(text, 'Hello world'),
      );
    });

    test('returns Left(ServerFailure) on error', () async {
      when(() => mockTranslation.translateText(any(), any()))
          .thenThrow(const ServerFailure('Erreur DeepL'));

      final result = await repository.translateText('Bonjour', 'EN');

      expect(result, isA<Left>());
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('should be Left'),
      );
    });

    test('returns Left immediately for QuotaExceededFailure', () async {
      when(() => mockTranslation.translateText(any(), any()))
          .thenThrow(const QuotaExceededFailure('Quota'));

      final result = await repository.translateText('Bonjour', 'EN');

      expect(result, isA<Left>());
      result.fold(
        (failure) => expect(failure, isA<QuotaExceededFailure>()),
        (_) => fail('should be Left'),
      );
      verify(() => mockTranslation.translateText(any(), any())).called(1);
    });
  });

  group('generateSpeech', () {
    final tAudioFile = File('output.wav');

    test('returns Right(File) on success', () async {
      when(() => mockTts.generateSpeech(any(), any(), onProgress: any(named: 'onProgress')))
          .thenAnswer((_) async => tAudioFile);

      final result = await repository.generateSpeech('Hello', 'en-US');

      expect(result, isA<Right>());
      result.fold(
        (_) => fail('should be Right'),
        (file) => expect(file.path, tAudioFile.path),
      );
    });

    test('returns Left on failure', () async {
      when(() => mockTts.generateSpeech(any(), any(), onProgress: any(named: 'onProgress')))
          .thenThrow(const ServerFailure('TTS error'));

      final result = await repository.generateSpeech('Hello', 'en-US');

      expect(result, isA<Left>());
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('should be Left'),
      );
    });

    test('passes onProgress callback to datasource', () async {
      final messages = <String>[];
      when(() => mockTts.generateSpeech(any(), any(), onProgress: any(named: 'onProgress')))
          .thenAnswer((invocation) async {
        final onProgress = invocation.namedArguments[#onProgress] as Function(String)?;
        onProgress?.call('Generating...');
        return tAudioFile;
      });

      await repository.generateSpeech('Hello', 'en-US', onProgress: messages.add);

      expect(messages, ['Generating...']);
    });
  });
}
