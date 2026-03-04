import 'package:flutter_test/flutter_test.dart';
import 'package:audiotranslator/core/utils/language_mapper.dart';

void main() {
  group('LanguageMapper.toGroqCode', () {
    final expectedGroq = {
      'French': 'fr',
      'English': 'en',
      'Spanish': 'es',
      'German': 'de',
      'Italian': 'it',
      'Portuguese': 'pt',
      'Japanese': 'ja',
      'Chinese': 'zh',
      'Korean': 'ko',
      'Arabic': 'ar',
    };

    for (final entry in expectedGroq.entries) {
      test('${entry.key} → ${entry.value}', () {
        expect(LanguageMapper.toGroqCode(entry.key), entry.value);
      });
    }

    test('Auto-detect → fallback lowercase', () {
      expect(LanguageMapper.toGroqCode('Auto-detect'), 'auto-detect');
    });

    test('unknown language → fallback lowercase', () {
      expect(LanguageMapper.toGroqCode('Unknown'), 'unknown');
    });
  });

  group('LanguageMapper.toDeeplCode', () {
    final expectedDeepl = {
      'French': 'FR',
      'English': 'EN',
      'Spanish': 'ES',
      'German': 'DE',
      'Italian': 'IT',
      'Portuguese': 'PT-BR',
      'Japanese': 'JA',
      'Chinese': 'ZH',
      'Korean': 'KO',
    };

    for (final entry in expectedDeepl.entries) {
      test('${entry.key} → ${entry.value}', () {
        expect(LanguageMapper.toDeeplCode(entry.key), entry.value);
      });
    }

    test('Arabic → fallback uppercase (not in DeepL map)', () {
      expect(LanguageMapper.toDeeplCode('Arabic'), 'ARABIC');
    });

    test('unknown language → fallback uppercase', () {
      expect(LanguageMapper.toDeeplCode('Unknown'), 'UNKNOWN');
    });
  });

  group('LanguageMapper.toGoogleTtsCode', () {
    final expectedTts = {
      'French': 'fr-FR',
      'English': 'en-US',
      'Spanish': 'es-ES',
      'German': 'de-DE',
      'Italian': 'it-IT',
      'Portuguese': 'pt-BR',
      'Japanese': 'ja-JP',
      'Chinese': 'zh-CN',
      'Korean': 'ko-KR',
      'Arabic': 'ar-XA',
    };

    for (final entry in expectedTts.entries) {
      test('${entry.key} → ${entry.value}', () {
        expect(LanguageMapper.toGoogleTtsCode(entry.key), entry.value);
      });
    }

    test('unknown language → fallback en-US', () {
      expect(LanguageMapper.toGoogleTtsCode('Unknown'), 'en-US');
    });
  });

  group('LanguageMapper.isDeeplSupported', () {
    test('supported languages return true', () {
      for (final lang in [
        'French', 'English', 'Spanish', 'German', 'Italian',
        'Portuguese', 'Japanese', 'Chinese', 'Korean',
      ]) {
        expect(LanguageMapper.isDeeplSupported(lang), isTrue,
            reason: '$lang should be supported');
      }
    });

    test('Arabic is not supported by DeepL', () {
      expect(LanguageMapper.isDeeplSupported('Arabic'), isFalse);
    });

    test('unknown language is not supported', () {
      expect(LanguageMapper.isDeeplSupported('Unknown'), isFalse);
    });
  });

  group('LanguageMapper.getLabel', () {
    test('known languages return emoji + label', () {
      expect(LanguageMapper.getLabel('French'), contains('Fran'));
      expect(LanguageMapper.getLabel('English'), contains('English'));
      expect(LanguageMapper.getLabel('Auto-detect'), contains('Auto-detect'));
    });

    test('unknown language returns input as-is', () {
      expect(LanguageMapper.getLabel('Klingon'), 'Klingon');
    });
  });
}
