import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:audiotranslator/core/config/api_config.dart';
import 'package:audiotranslator/core/errors/failures.dart';
import 'package:audiotranslator/features/translation/data/datasources/youtube_transcript_data_source.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockApiConfig extends Mock implements ApiConfig {}

class FakeUri extends Fake implements Uri {}

void main() {
  late MockHttpClient mockClient;
  late MockApiConfig mockApiConfig;
  late YouTubeTranscriptDataSourceImpl dataSource;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    mockClient = MockHttpClient();
    mockApiConfig = MockApiConfig();
    when(() => mockApiConfig.youtubeWebKey).thenReturn('fake-web-key');
    when(() => mockApiConfig.youtubeAndroidKey).thenReturn('fake-android-key');
    dataSource = YouTubeTranscriptDataSourceImpl(mockClient, mockApiConfig);
  });

  const tVideoId = 'dQw4w9WgXcQ';

  /// Helper: builds a player response JSON with captions
  String playerResponse({
    String status = 'OK',
    String title = 'Test Video',
    List<Map<String, dynamic>>? captionTracks,
  }) {
    return jsonEncode({
      'playabilityStatus': {'status': status},
      'videoDetails': {'title': title},
      if (captionTracks != null)
        'captions': {
          'playerCaptionsTracklistRenderer': {
            'captionTracks': captionTracks,
          },
        },
    });
  }

  /// Transcript XML (srv1 format)
  const tTranscriptXml = '''<?xml version="1.0" encoding="utf-8"?>
<transcript>
  <text start="0" dur="5">Hello world</text>
  <text start="5" dur="3">How are you</text>
</transcript>''';

  group('fetchTranscript', () {
    test('returns transcript and title on success', () async {
      // Player response (WEB client)
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            playerResponse(
              title: 'My Video',
              captionTracks: [
                {
                  'baseUrl': 'https://www.youtube.com/api/timedtext?v=$tVideoId',
                  'languageCode': 'fr',
                  'kind': '',
                },
              ],
            ),
            200,
          ));

      // Transcript fetch
      when(() => mockClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(tTranscriptXml, 200));

      final result = await dataSource.fetchTranscript(tVideoId);

      expect(result.title, 'My Video');
      expect(result.transcript, contains('Hello world'));
      expect(result.transcript, contains('How are you'));
    });

    test('uses WEB key in first request', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            playerResponse(
              captionTracks: [
                {
                  'baseUrl': 'https://example.com/captions',
                  'languageCode': 'en',
                  'kind': '',
                },
              ],
            ),
            200,
          ));

      when(() => mockClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(tTranscriptXml, 200));

      await dataSource.fetchTranscript(tVideoId);

      final captured = verify(() => mockClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).captured;

      final uri = (captured.first as Uri).toString();
      expect(uri, contains('fake-web-key'));
    });

    test('throws ServerFailure when all clients fail (non-200)', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('error', 500));

      expect(
        () => dataSource.fetchTranscript(tVideoId),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('throws ServerFailure when no captions available', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            playerResponse(captionTracks: []),
            200,
          ));

      expect(
        () => dataSource.fetchTranscript(tVideoId),
        throwsA(isA<ServerFailure>().having(
          (f) => f.message,
          'message',
          contains('sous-titre'),
        )),
      );
    });

    test('throws ServerFailure when video is not playable', () async {
      // Both WEB and ANDROID return non-OK status
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            playerResponse(status: 'UNPLAYABLE'),
            200,
          ));

      expect(
        () => dataSource.fetchTranscript(tVideoId),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('parses HTML entities in transcript', () async {
      const xmlWithEntities = '''<?xml version="1.0" encoding="utf-8"?>
<transcript>
  <text start="0" dur="5">Tom &amp; Jerry &lt;3</text>
</transcript>''';

      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            playerResponse(
              captionTracks: [
                {
                  'baseUrl': 'https://example.com/captions',
                  'languageCode': 'en',
                  'kind': '',
                },
              ],
            ),
            200,
          ));

      when(() => mockClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(xmlWithEntities, 200));

      final result = await dataSource.fetchTranscript(tVideoId);

      expect(result.transcript, contains('Tom & Jerry <3'));
    });

    test('falls back to ANDROID client when WEB is not playable', () async {
      var callCount = 0;
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          // WEB: not playable
          return http.Response(
            playerResponse(status: 'LOGIN_REQUIRED'),
            200,
          );
        }
        // ANDROID: OK
        return http.Response(
          playerResponse(
            captionTracks: [
              {
                'baseUrl': 'https://example.com/captions',
                'languageCode': 'en',
                'kind': '',
              },
            ],
          ),
          200,
        );
      });

      when(() => mockClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(tTranscriptXml, 200));

      final result = await dataSource.fetchTranscript(tVideoId);

      expect(result.transcript, contains('Hello world'));
      // Should have called post twice (WEB then ANDROID)
      verify(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).called(2);
    });
  });
}
