import 'package:flutter_test/flutter_test.dart';
import 'package:audiotranslator/core/utils/youtube_url_parser.dart';

void main() {
  const validId = 'dQw4w9WgXcQ';

  group('YouTubeUrlParser.extractVideoId', () {
    test('standard URL with https://www', () {
      expect(
        YouTubeUrlParser.extractVideoId('https://www.youtube.com/watch?v=$validId'),
        validId,
      );
    });

    test('standard URL with http', () {
      expect(
        YouTubeUrlParser.extractVideoId('http://youtube.com/watch?v=$validId'),
        validId,
      );
    });

    test('standard URL without protocol', () {
      expect(
        YouTubeUrlParser.extractVideoId('youtube.com/watch?v=$validId'),
        validId,
      );
    });

    test('mobile URL (m.youtube.com)', () {
      expect(
        YouTubeUrlParser.extractVideoId('https://m.youtube.com/watch?v=$validId'),
        validId,
      );
    });

    test('short URL (youtu.be)', () {
      expect(
        YouTubeUrlParser.extractVideoId('https://youtu.be/$validId'),
        validId,
      );
    });

    test('short URL without protocol', () {
      expect(
        YouTubeUrlParser.extractVideoId('youtu.be/$validId'),
        validId,
      );
    });

    test('embed URL', () {
      expect(
        YouTubeUrlParser.extractVideoId('https://www.youtube.com/embed/$validId'),
        validId,
      );
    });

    test('shorts URL', () {
      expect(
        YouTubeUrlParser.extractVideoId('https://www.youtube.com/shorts/$validId'),
        validId,
      );
    });

    test('URL with extra parameters', () {
      expect(
        YouTubeUrlParser.extractVideoId(
          'https://www.youtube.com/watch?v=$validId&t=123&list=PLtest',
        ),
        validId,
      );
    });

    test('URL with leading/trailing whitespace', () {
      expect(
        YouTubeUrlParser.extractVideoId('  https://youtu.be/$validId  '),
        validId,
      );
    });

    test('invalid URL returns null', () {
      expect(YouTubeUrlParser.extractVideoId('https://example.com/video'), isNull);
    });

    test('empty string returns null', () {
      expect(YouTubeUrlParser.extractVideoId(''), isNull);
    });

    test('non-YouTube URL returns null', () {
      expect(
        YouTubeUrlParser.extractVideoId('https://vimeo.com/123456789'),
        isNull,
      );
    });

    test('random text returns null', () {
      expect(YouTubeUrlParser.extractVideoId('not a url at all'), isNull);
    });
  });

  group('YouTubeUrlParser.isValidYouTubeUrl', () {
    test('valid standard URL returns true', () {
      expect(
        YouTubeUrlParser.isValidYouTubeUrl('https://www.youtube.com/watch?v=$validId'),
        isTrue,
      );
    });

    test('valid short URL returns true', () {
      expect(
        YouTubeUrlParser.isValidYouTubeUrl('https://youtu.be/$validId'),
        isTrue,
      );
    });

    test('invalid URL returns false', () {
      expect(
        YouTubeUrlParser.isValidYouTubeUrl('https://example.com'),
        isFalse,
      );
    });

    test('empty string returns false', () {
      expect(YouTubeUrlParser.isValidYouTubeUrl(''), isFalse);
    });
  });
}
