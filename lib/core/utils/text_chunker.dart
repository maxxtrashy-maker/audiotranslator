class TextChunker {
  static const int defaultMaxChars = 4500;
  
  /// Split text intelligently into chunks respecting sentence and paragraph boundaries
  static List<String> splitIntelligently(String text, {int maxChars = defaultMaxChars}) {
    if (text.length <= maxChars) {
      return [text];
    }
    
    final chunks = <String>[];
    var remainingText = text;
    
    while (remainingText.isNotEmpty) {
      if (remainingText.length <= maxChars) {
        chunks.add(remainingText);
        break;
      }
      
      // Find the best split point
      final splitPoint = _findBestSplitPoint(remainingText, maxChars);
      
      // Extract chunk and update remaining text
      final chunk = remainingText.substring(0, splitPoint).trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }
      
      remainingText = remainingText.substring(splitPoint).trim();
    }
    
    return chunks;
  }
  
  /// Find the best point to split the text, prioritizing natural boundaries
  static int _findBestSplitPoint(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text.length;
    }
    
    // Search window: last 500 characters before maxLength
    final searchStart = maxLength - 500 > 0 ? maxLength - 500 : 0;
    final searchText = text.substring(searchStart, maxLength);
    
    // Priority 1: Double newline (paragraph break)
    int splitPoint = searchText.lastIndexOf('\n\n');
    if (splitPoint != -1) {
      return searchStart + splitPoint + 2; // Include the newlines
    }
    
    // Priority 2: Single newline
    splitPoint = searchText.lastIndexOf('\n');
    if (splitPoint != -1) {
      return searchStart + splitPoint + 1;
    }
    
    // Priority 3: Sentence endings (. ! ?)
    final sentenceEndings = ['. ', '! ', '? ', '.\n', '!\n', '?\n'];
    int latestSentenceEnd = -1;
    
    for (final ending in sentenceEndings) {
      final index = searchText.lastIndexOf(ending);
      if (index > latestSentenceEnd) {
        latestSentenceEnd = index;
      }
    }
    
    if (latestSentenceEnd != -1) {
      return searchStart + latestSentenceEnd + 2; // Include the punctuation and space
    }
    
    // Priority 4: Comma or semicolon
    final punctuation = [', ', '; ', ',\n', ';\n'];
    int latestPunctuation = -1;
    
    for (final punct in punctuation) {
      final index = searchText.lastIndexOf(punct);
      if (index > latestPunctuation) {
        latestPunctuation = index;
      }
    }
    
    if (latestPunctuation != -1) {
      return searchStart + latestPunctuation + 2;
    }
    
    // Priority 5: Last space
    splitPoint = searchText.lastIndexOf(' ');
    if (splitPoint != -1) {
      return searchStart + splitPoint + 1;
    }
    
    // Last resort: hard cut at maxLength
    return maxLength;
  }
  
  /// Get statistics about the chunking
  static Map<String, dynamic> getChunkingStats(String text, {int maxChars = defaultMaxChars}) {
    final chunks = splitIntelligently(text, maxChars: maxChars);
    
    return {
      'totalCharacters': text.length,
      'numberOfChunks': chunks.length,
      'averageChunkSize': chunks.isEmpty ? 0 : text.length ~/ chunks.length,
      'chunkSizes': chunks.map((c) => c.length).toList(),
    };
  }
}
