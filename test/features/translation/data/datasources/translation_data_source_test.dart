import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:audiotranslator/core/config/api_config.dart';
import 'package:audiotranslator/core/errors/failures.dart';
import 'package:audiotranslator/features/translation/data/datasources/translation_data_source.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockApiConfig extends Mock implements ApiConfig {}

class FakeUri extends Fake implements Uri {}

void main() {
  late MockHttpClient mockClient;
  late MockApiConfig mockApiConfig;
  late DeeplTranslationDataSourceImpl dataSource;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    mockClient = MockHttpClient();
    mockApiConfig = MockApiConfig();
    when(() => mockApiConfig.deeplApiKey).thenReturn('fake-deepl-key');
    dataSource = DeeplTranslationDataSourceImpl(mockClient, mockApiConfig);
  });

  group('translateText', () {
    test('returns translated text on 200', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'translations': [
                {'text': 'Hello world'}
              ]
            }),
            200,
          ));

      final result = await dataSource.translateText('Bonjour le monde', 'EN');

      expect(result, 'Hello world');
    });

    test('sends correct headers and body', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'translations': [
                {'text': 'Hi'}
              ]
            }),
            200,
          ));

      await dataSource.translateText('Salut', 'EN');

      final captured = verify(() => mockClient.post(
            captureAny(),
            headers: captureAny(named: 'headers'),
            body: captureAny(named: 'body'),
          )).captured;

      final uri = captured[0] as Uri;
      expect(uri.toString(), ApiConfig.deeplTranslationEndpoint);

      final headers = captured[1] as Map<String, String>;
      expect(headers['Authorization'], 'DeepL-Auth-Key fake-deepl-key');
      expect(headers['Content-Type'], 'application/json');

      final body = jsonDecode(captured[2] as String);
      expect(body['text'], ['Salut']);
      expect(body['target_lang'], 'EN');
    });

    test('throws QuotaExceededFailure on 429', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('', 429));

      expect(
        () => dataSource.translateText('Bonjour', 'EN'),
        throwsA(isA<QuotaExceededFailure>()),
      );
    });

    test('throws QuotaExceededFailure on 456 (monthly quota)', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('', 456));

      expect(
        () => dataSource.translateText('Bonjour', 'EN'),
        throwsA(isA<QuotaExceededFailure>()),
      );
    });

    test('throws ServerFailure on 403 (invalid key)', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('', 403));

      expect(
        () => dataSource.translateText('Bonjour', 'EN'),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('throws ServerFailure with message on other status codes', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'message': 'Bad request'}),
            400,
          ));

      expect(
        () => dataSource.translateText('Bonjour', 'EN'),
        throwsA(isA<ServerFailure>().having(
          (f) => f.message,
          'message',
          contains('Bad request'),
        )),
      );
    });

    test('throws ServerFailure when translations list is empty', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'translations': []}),
            200,
          ));

      expect(
        () => dataSource.translateText('Bonjour', 'EN'),
        throwsA(isA<ServerFailure>()),
      );
    });
  });
}
