/// Cleans raw subtitle text by removing non-speech artifacts.
///
/// Handles: bracketed annotations ([music], [applause], etc.),
/// speaker markers (>>), filler words (hum, euh, etc.),
/// and normalises whitespace.
class SubtitleCleaner {
  SubtitleCleaner._();

  /// Bracketed annotations — case-insensitive, any language.
  /// Matches [music], [musique], [applause], [rires], [Musique], etc.
  static final _bracketedAnnotations = RegExp(
    r'\[(?:musique|musicales?|music|applause|applaudissements|rires|laughter|silence|inaudible|bruit|noise)[^\]]*\]',
    caseSensitive: false,
  );

  /// Speaker-change markers: >> or >>> (with optional trailing space).
  static final _speakerMarkers = RegExp(r'>{2,}\s*');

  /// French filler words at word boundaries.
  /// Matches: "Hum", "Euh", "Heu", "Hmm", "Bah" — standalone or followed by
  /// a comma/period (e.g. "Hum," or "euh,").
  static final _fillerWords = RegExp(
    r'\b(?:hum|euh|heu|hmm|bah|ah)\b[,.]?\s*',
    caseSensitive: false,
  );

  /// Collapse multiple spaces / leading-trailing whitespace.
  static final _multipleSpaces = RegExp(r' {2,}');

  /// Clean subtitle [text] by removing non-speech artifacts.
  static String clean(String text) {
    if (text.isEmpty) return text;

    var result = text;

    // 1. Remove bracketed annotations
    result = result.replaceAll(_bracketedAnnotations, ' ');

    // 2. Remove speaker-change markers
    result = result.replaceAll(_speakerMarkers, ' ');

    // 3. Remove filler words
    result = result.replaceAll(_fillerWords, '');

    // 4. Normalise whitespace
    result = result.replaceAll(_multipleSpaces, ' ').trim();

    // 5. Fix punctuation artefacts left after removals (e.g. " ," → ",")
    result = result.replaceAll(RegExp(r'\s+([,.\?!;:])'), r'$1');

    return result;
  }
}
