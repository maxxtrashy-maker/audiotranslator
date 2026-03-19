import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:audiotranslator/core/config/api_config.dart';
import 'package:audiotranslator/core/errors/failures.dart';
import 'package:audiotranslator/features/translation/data/datasources/youtube_transcript_data_source.dart';
import 'package:audiotranslator/features/translation/domain/entities/youtube_subtitle_track.dart';

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

  String playerResponse({
    String status = 'OK',
    String? reason,
    String title = 'Test Video',
    String? videoId = tVideoId,
    List<Map<String, dynamic>>? captionTracks,
  }) {
    return jsonEncode({
      'playabilityStatus': {
        'status': status,
        if (reason != null) 'reason': reason,
      },
      'videoDetails': {
        'title': title,
        'videoId': videoId,
      },
      if (captionTracks != null)
        'captions': {
          'playerCaptionsTracklistRenderer': {
            'captionTracks': captionTracks,
          },
        },
    });
  }

  const tTranscriptXml = '''<?xml version="1.0" encoding="utf-8"?>
<transcript>
  <text start="0" dur="5">Hello world</text>
  <text start="5" dur="3">How are you</text>
</transcript>''';

  group('fetchTranscript', () {
    test('returns transcript, title and tracks on success', () async {
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
                  'name': {'simpleText': 'Français'},
                  'vssId': '.fr',
                },
              ],
            ),
            200,
          ));

      when(() => mockClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(tTranscriptXml, 200));

      final result = await dataSource.fetchTranscript(tVideoId);

      expect(result.title, 'My Video');
      expect(result.transcript, contains('Hello world'));
      expect(result.tracks.length, 1);
      expect(result.tracks.first.languageCode, 'fr');
    });

    test('prioritizes manual French over auto-generated French', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            playerResponse(
              captionTracks: [
                {
                  'baseUrl': 'https://example.com/auto_fr',
                  'languageCode': 'fr',
                  'vssId': 'a.fr',
                },
                {
                  'baseUrl': 'https://example.com/manual_fr',
                  'languageCode': 'fr',
                  'vssId': '.fr',
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

      final capturedUri = verify(() => mockClient.get(
            captureAny(),
            headers: any(named: 'headers'),
          )).captured.first as Uri;

      expect(capturedUri.toString(), contains('manual_fr'));
    });

    test('throws Failure with specific message for age-restricted video', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            playerResponse(status: 'LOGIN_REQUIRED', reason: 'This video is age-restricted'),
            200,
          ));

      expect(
        () => dataSource.fetchTranscript(tVideoId),
        throwsA(isA<ServerFailure>().having((f) => f.message, 'message', contains('limite d\'âge'))),
      );
    });

    test('throws Failure for private video', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            playerResponse(status: 'LOGIN_REQUIRED', reason: 'This video is private'),
            200,
          ));

      expect(
        () => dataSource.fetchTranscript(tVideoId),
        throwsA(isA<ServerFailure>().having((f) => f.message, 'message', contains('privée'))),
      );
    });

    test('parses VTT format when XML fails or returns empty', () async {
      const vttContent = '''WEBVTT

1
00:00:00.000 --> 00:00:05.000
Hello from VTT''';

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
                },
              ],
            ),
            200,
          ));

      var getCall = 0;
      when(() => mockClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async {
            getCall++;
            if (getCall == 1) return http.Response('', 404); // XML fails
            return http.Response(vttContent, 200); // VTT success
          });

      final result = await dataSource.fetchTranscript(tVideoId);
      expect(result.transcript, 'Hello from VTT');
    });

    test('handles video ID mismatch by trying next client', () async {
      var postCall = 0;
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {
            postCall++;
            if (postCall == 1) {
              return http.Response(playerResponse(videoId: 'WRONG_ID'), 200);
            }
            return http.Response(playerResponse(
              captionTracks: [{'baseUrl': 'https://ok.com', 'languageCode': 'en'}]
            ), 200);
          });

      when(() => mockClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(tTranscriptXml, 200));

      await dataSource.fetchTranscript(tVideoId);
      verify(() => mockClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).called(2);
    });
  });
}
