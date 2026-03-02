class LanguageMapper {
  static const _groqCodes = {
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

  static const _deeplCodes = {
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

  static const _googleTtsCodes = {
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

  static const _labels = {
    'French': '\u{1F1EB}\u{1F1F7} Fran\u00e7ais',
    'English': '\u{1F1EC}\u{1F1E7} English',
    'Spanish': '\u{1F1EA}\u{1F1F8} Espa\u00f1ol',
    'German': '\u{1F1E9}\u{1F1EA} Deutsch',
    'Italian': '\u{1F1EE}\u{1F1F9} Italiano',
    'Portuguese': '\u{1F1F5}\u{1F1F9} Portugu\u00eas',
    'Japanese': '\u{1F1EF}\u{1F1F5} \u65E5\u672C\u8A9E',
    'Chinese': '\u{1F1E8}\u{1F1F3} \u4E2D\u6587',
    'Korean': '\u{1F1F0}\u{1F1F7} \uD55C\uAD6D\uC5B4',
    'Arabic': '\u{1F1F8}\u{1F1E6} \u0627\u0644\u0639\u0631\u0628\u064A\u0629',
    'Auto-detect': '\u{1F50D} Auto-detect',
  };

  /// All supported target languages (10, including Arabic for TTS-only mode)
  static const supportedTargetLanguages = [
    'French', 'English', 'Spanish', 'German', 'Italian',
    'Portuguese', 'Japanese', 'Chinese', 'Korean', 'Arabic',
  ];

  /// Target languages for the audio pipeline (9, without Arabic)
  static const pipelineTargetLanguages = [
    'French', 'English', 'Spanish', 'German', 'Italian',
    'Portuguese', 'Japanese', 'Chinese', 'Korean',
  ];

  /// Source languages for audio pipeline (with Auto-detect)
  static const sourceLanguages = [
    'Auto-detect', 'French', 'English', 'Spanish', 'German', 'Italian',
    'Portuguese', 'Japanese', 'Chinese', 'Korean', 'Arabic',
  ];

  static String toGroqCode(String language) =>
      _groqCodes[language] ?? language.toLowerCase();

  static String toDeeplCode(String language) =>
      _deeplCodes[language] ?? language.toUpperCase();

  static String toGoogleTtsCode(String language) =>
      _googleTtsCodes[language] ?? 'en-US';

  static bool isDeeplSupported(String language) =>
      _deeplCodes.containsKey(language);

  static String getLabel(String language) => _labels[language] ?? language;
}
