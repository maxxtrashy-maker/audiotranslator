import 'dart:io';
import 'dart:typed_data';

/// Utility class for concatenating WAV audio files
class WavConcatenator {
  /// Concatenate multiple WAV files into a single WAV file
  static Future<File> concatenate(List<File> wavFiles, String outputPath) async {
    if (wavFiles.isEmpty) {
      throw Exception('No WAV files to concatenate');
    }
    
    if (wavFiles.length == 1) {
      // If only one file, just copy it
      return wavFiles.first.copy(outputPath);
    }
    
    // Read all WAV files
    final audioDataChunks = <Uint8List>[];
    WavHeader? firstHeader;
    
    for (final file in wavFiles) {
      final bytes = await file.readAsBytes();
      
      // Parse WAV header
      final header = WavHeader.parse(bytes);
      
      // Use the first file's header as the template
      firstHeader ??= header;
      
      // Extract audio data (skip header)
      final audioData = bytes.sublist(header.dataOffset, header.dataOffset + header.dataSize);
      audioDataChunks.add(audioData);
    }
    
    if (firstHeader == null) {
      throw Exception('Failed to parse WAV headers');
    }
    
    // Concatenate all audio data
    final totalAudioSize = audioDataChunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final concatenatedAudio = Uint8List(totalAudioSize);
    
    int offset = 0;
    for (final chunk in audioDataChunks) {
      concatenatedAudio.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    
    // Create new WAV file with concatenated audio
    final outputFile = File(outputPath);
    final wavBytes = _createWavFile(
      concatenatedAudio,
      firstHeader.numChannels,
      firstHeader.sampleRate,
      firstHeader.bitsPerSample,
    );
    
    await outputFile.writeAsBytes(wavBytes);
    return outputFile;
  }
  
  /// Create a complete WAV file from audio data
  static Uint8List _createWavFile(
    Uint8List audioData,
    int numChannels,
    int sampleRate,
    int bitsPerSample,
  ) {
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final dataSize = audioData.length;
    final fileSize = 36 + dataSize;
    
    final buffer = ByteData(44 + dataSize);
    
    // RIFF header
    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 0x49); // 'I'
    buffer.setUint8(2, 0x46); // 'F'
    buffer.setUint8(3, 0x46); // 'F'
    buffer.setUint32(4, fileSize, Endian.little);
    
    // WAVE header
    buffer.setUint8(8, 0x57);  // 'W'
    buffer.setUint8(9, 0x41);  // 'A'
    buffer.setUint8(10, 0x56); // 'V'
    buffer.setUint8(11, 0x45); // 'E'
    
    // fmt subchunk
    buffer.setUint8(12, 0x66); // 'f'
    buffer.setUint8(13, 0x6D); // 'm'
    buffer.setUint8(14, 0x74); // 't'
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    buffer.setUint16(20, 1, Endian.little);  // AudioFormat (1 for PCM)
    buffer.setUint16(22, numChannels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);
    
    // data subchunk
    buffer.setUint8(36, 0x64); // 'd'
    buffer.setUint8(37, 0x61); // 'a'
    buffer.setUint8(38, 0x74); // 't'
    buffer.setUint8(39, 0x61); // 'a'
    buffer.setUint32(40, dataSize, Endian.little);
    
    // Copy audio data
    final result = Uint8List(44 + dataSize);
    result.setRange(0, 44, buffer.buffer.asUint8List());
    result.setRange(44, 44 + dataSize, audioData);
    
    return result;
  }
}

/// WAV file header information
class WavHeader {
  final int numChannels;
  final int sampleRate;
  final int bitsPerSample;
  final int dataSize;
  final int dataOffset;
  
  WavHeader({
    required this.numChannels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.dataSize,
    required this.dataOffset,
  });
  
  /// Parse WAV header from bytes
  static WavHeader parse(Uint8List bytes) {
    final buffer = ByteData.view(bytes.buffer);
    
    // Verify RIFF header
    if (bytes[0] != 0x52 || bytes[1] != 0x49 || bytes[2] != 0x46 || bytes[3] != 0x46) {
      throw Exception('Invalid WAV file: Missing RIFF header');
    }
    
    // Verify WAVE format
    if (bytes[8] != 0x57 || bytes[9] != 0x41 || bytes[10] != 0x56 || bytes[11] != 0x45) {
      throw Exception('Invalid WAV file: Missing WAVE format');
    }
    
    // Read fmt chunk
    final numChannels = buffer.getUint16(22, Endian.little);
    final sampleRate = buffer.getUint32(24, Endian.little);
    final bitsPerSample = buffer.getUint16(34, Endian.little);
    
    // Find data chunk (it should be at offset 36 for standard WAV)
    int dataOffset = 36;
    int dataSize = 0;
    
    // Check if "data" chunk is at expected position
    if (bytes[36] == 0x64 && bytes[37] == 0x61 && bytes[38] == 0x74 && bytes[39] == 0x61) {
      dataSize = buffer.getUint32(40, Endian.little);
      dataOffset = 44;
    } else {
      // Search for data chunk
      for (int i = 36; i < bytes.length - 8; i++) {
        if (bytes[i] == 0x64 && bytes[i + 1] == 0x61 && bytes[i + 2] == 0x74 && bytes[i + 3] == 0x61) {
          dataSize = buffer.getUint32(i + 4, Endian.little);
          dataOffset = i + 8;
          break;
        }
      }
    }
    
    return WavHeader(
      numChannels: numChannels,
      sampleRate: sampleRate,
      bitsPerSample: bitsPerSample,
      dataSize: dataSize,
      dataOffset: dataOffset,
    );
  }
}
