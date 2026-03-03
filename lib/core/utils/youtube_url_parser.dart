class YouTubeUrlParser {
  static final _patterns = [
    // youtube.com/watch?v=VIDEO_ID
    RegExp(r'(?:https?://)?(?:www\.|m\.)?youtube\.com/watch\?.*v=([a-zA-Z0-9_-]{11})'),
    // youtu.be/VIDEO_ID
    RegExp(r'(?:https?://)?youtu\.be/([a-zA-Z0-9_-]{11})'),
    // youtube.com/embed/VIDEO_ID
    RegExp(r'(?:https?://)?(?:www\.)?youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
    // youtube.com/shorts/VIDEO_ID
    RegExp(r'(?:https?://)?(?:www\.)?youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
  ];

  /// Extracts the video ID from a YouTube URL, or returns null if invalid.
  static String? extractVideoId(String url) {
    final trimmed = url.trim();
    for (final pattern in _patterns) {
      final match = pattern.firstMatch(trimmed);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  /// Returns true if the URL is a valid YouTube URL.
  static bool isValidYouTubeUrl(String url) {
    return extractVideoId(url) != null;
  }
}
