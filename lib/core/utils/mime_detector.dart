import 'dart:io';
import 'package:mime/mime.dart';

class MimeDetector {
  /// Detect MIME type of an audio file
  static String? detectMimeType(File file) {
    return lookupMimeType(file.path);
  }

  /// Check if the file is a supported audio format
  static bool isSupportedAudioFormat(File file) {
    final mimeType = detectMimeType(file);
    
    if (mimeType == null) return false;
    
    const supportedMimeTypes = [
      'audio/mpeg',      // MP3
      'audio/mp3',       // MP3 alternative
      'audio/wav',       // WAV
      'audio/x-wav',     // WAV alternative
      'audio/wave',      // WAV alternative
      'audio/x-m4a',     // M4A
      'audio/mp4',       // M4A/MP4
      'audio/flac',      // FLAC
      'audio/x-flac',    // FLAC alternative
      'audio/ogg',       // OGG
      'audio/vorbis',    // OGG Vorbis
    ];
    
    return supportedMimeTypes.contains(mimeType);
  }

  /// Get MIME type for Google Cloud Speech-to-Text API
  static String getMimeTypeForApi(File file) {
    final mimeType = detectMimeType(file);
    
    // Normalize MIME types for Google Cloud API
    if (mimeType == null) return 'audio/mpeg';
    
    if (mimeType.contains('wav')) return 'audio/wav';
    if (mimeType.contains('flac')) return 'audio/flac';
    if (mimeType.contains('ogg')) return 'audio/ogg';
    if (mimeType.contains('m4a') || mimeType == 'audio/mp4') return 'audio/mp4';
    
    return 'audio/mpeg'; // Default to MP3
  }
}
