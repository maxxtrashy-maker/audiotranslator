import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audiotranslator/core/errors/failures.dart';
import 'package:audiotranslator/features/translation/data/datasources/youtube_transcript_data_source.dart';
import 'package:audiotranslator/features/translation/data/repositories/youtube_transcript_repository_impl.dart';

class MockYouTubeTranscriptDataSource extends Mock
    implements YouTubeTranscriptDataSource {}

void main() {
  late MockYouTubeTranscriptDataSource mockDataSource;
  late YouTubeTranscriptRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockYouTubeTranscriptDataSource();
    repository = YouTubeTranscriptRepositoryImpl(mockDataSource);
  });

  const tVideoId = 'dQw4w9WgXcQ';
  const tTranscript = 'Never gonna give you up';
  const tTitle = 'Rick Astley - Never Gonna Give You Up';

  group('extractTranscript', () {
    test('returns Right with transcript and title on success', () async {
      when(() => mockDataSource.fetchTranscript(any()))
          .thenAnswer((_) async => (transcript: tTranscript, title: tTitle));

      final result = await repository.extractTranscript(tVideoId);

      expect(result, isA<Right>());
      result.fold(
        (_) => fail('should be Right'),
        (data) {
          expect(data.transcript, tTranscript);
          expect(data.title, tTitle);
        },
      );
      verify(() => mockDataSource.fetchTranscript(tVideoId)).called(1);
    });

    test('returns Left(ServerFailure) when datasource throws ServerFailure', () async {
      when(() => mockDataSource.fetchTranscript(any()))
          .thenThrow(const ServerFailure('Vidéo non disponible'));

      final result = await repository.extractTranscript(tVideoId);

      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, 'Vidéo non disponible');
        },
        (_) => fail('should be Left'),
      );
    });

    test('returns Left immediately for TimeoutFailure (no retry)', () async {
      when(() => mockDataSource.fetchTranscript(any()))
          .thenThrow(const TimeoutFailure('Timeout'));

      final result = await repository.extractTranscript(tVideoId);

      expect(result, isA<Left>());
      result.fold(
        (failure) => expect(failure, isA<TimeoutFailure>()),
        (_) => fail('should be Left'),
      );
      verify(() => mockDataSource.fetchTranscript(tVideoId)).called(1);
    });

    test('retries on ServerFailure then succeeds', () async {
      var callCount = 0;
      when(() => mockDataSource.fetchTranscript(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw const ServerFailure('Erreur transitoire');
        return (transcript: tTranscript, title: tTitle);
      });

      final result = await repository.extractTranscript(tVideoId);

      expect(result, isA<Right>());
      result.fold(
        (_) => fail('should be Right'),
        (data) => expect(data.transcript, tTranscript),
      );
      verify(() => mockDataSource.fetchTranscript(tVideoId)).called(2);
    });

    test('returns Left after max retries exceeded', () async {
      when(() => mockDataSource.fetchTranscript(any()))
          .thenThrow(const ServerFailure('Erreur persistante'));

      final result = await repository.extractTranscript(tVideoId);

      expect(result, isA<Left>());
      // 1 initial + 2 retries = 3 calls
      verify(() => mockDataSource.fetchTranscript(tVideoId)).called(3);
    });

    test('wraps non-Failure exceptions as ServerFailure', () async {
      when(() => mockDataSource.fetchTranscript(any()))
          .thenThrow(Exception('Unexpected'));

      final result = await repository.extractTranscript(tVideoId);

      expect(result, isA<Left>());
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('Unexpected'));
        },
        (_) => fail('should be Left'),
      );
    });
  });
}
