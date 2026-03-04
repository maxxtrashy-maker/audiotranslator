import 'package:flutter_test/flutter_test.dart';
import 'package:audiotranslator/core/utils/text_chunker.dart';

void main() {
  group('TextChunker.splitIntelligently', () {
    test('empty string returns single empty string', () {
      expect(TextChunker.splitIntelligently(''), ['']);
    });

    test('text shorter than maxChars returns single chunk', () {
      const text = 'Hello world';
      final result = TextChunker.splitIntelligently(text, maxChars: 100);
      expect(result, [text]);
    });

    test('text equal to maxChars returns single chunk', () {
      final text = 'a' * 100;
      final result = TextChunker.splitIntelligently(text, maxChars: 100);
      expect(result, [text]);
    });

    test('splits on paragraph break (double newline) in priority', () {
      final text = '${'a' * 40}\n\n${'b' * 40}';
      final result = TextChunker.splitIntelligently(text, maxChars: 50);
      expect(result.length, 2);
      expect(result[0], 'a' * 40);
      expect(result[1], 'b' * 40);
    });

    test('splits on single newline when no paragraph break', () {
      final text = '${'a' * 40}\n${'b' * 40}';
      final result = TextChunker.splitIntelligently(text, maxChars: 50);
      expect(result.length, 2);
      expect(result[0], 'a' * 40);
      expect(result[1], 'b' * 40);
    });

    test('splits on sentence ending (period + space)', () {
      final text = '${'a' * 38}. ${'b' * 40}';
      final result = TextChunker.splitIntelligently(text, maxChars: 50);
      expect(result.length, 2);
      expect(result[0], '${'a' * 38}.');
      expect(result[1], 'b' * 40);
    });

    test('splits on comma when no sentence ending', () {
      final text = '${'a' * 38}, ${'b' * 40}';
      final result = TextChunker.splitIntelligently(text, maxChars: 50);
      expect(result.length, 2);
      expect(result[0], '${'a' * 38},');
      expect(result[1], 'b' * 40);
    });

    test('splits on space when no punctuation', () {
      final text = '${'a' * 40} ${'b' * 40}';
      final result = TextChunker.splitIntelligently(text, maxChars: 50);
      expect(result.length, 2);
      expect(result[0], 'a' * 40);
      expect(result[1], 'b' * 40);
    });

    test('force cuts when no natural break point', () {
      final text = 'a' * 200;
      final result = TextChunker.splitIntelligently(text, maxChars: 100);
      expect(result.length, 2);
      expect(result[0].length, 100);
      expect(result[1].length, 100);
    });

    test('respects custom maxChars', () {
      final text = 'a' * 50;
      final result = TextChunker.splitIntelligently(text, maxChars: 20);
      expect(result.length, 3);
      for (final chunk in result) {
        expect(chunk.length, lessThanOrEqualTo(20));
      }
    });

    test('uses default maxChars (4500)', () {
      final text = 'a' * 4500;
      final result = TextChunker.splitIntelligently(text);
      expect(result, [text]);
    });
  });

  group('TextChunker.getChunkingStats', () {
    test('totalCharacters matches input length', () {
      const text = 'Hello world';
      final stats = TextChunker.getChunkingStats(text);
      expect(stats['totalCharacters'], text.length);
    });

    test('numberOfChunks is 1 for short text', () {
      const text = 'Short text';
      final stats = TextChunker.getChunkingStats(text);
      expect(stats['numberOfChunks'], 1);
    });

    test('stats are consistent with splitIntelligently', () {
      final text = 'a' * 200;
      final stats = TextChunker.getChunkingStats(text, maxChars: 100);
      final chunks = TextChunker.splitIntelligently(text, maxChars: 100);
      expect(stats['numberOfChunks'], chunks.length);
      expect(stats['chunkSizes'], chunks.map((c) => c.length).toList());
    });

    test('averageChunkSize is computed correctly', () {
      final text = 'a' * 300;
      final stats = TextChunker.getChunkingStats(text, maxChars: 100);
      expect(stats['averageChunkSize'], 300 ~/ stats['numberOfChunks']);
    });
  });
}
