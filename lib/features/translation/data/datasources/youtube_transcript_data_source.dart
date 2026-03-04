import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../../../../core/config/api_config.dart';
import '../../../../core/errors/failures.dart';

abstract class YouTubeTranscriptDataSource {
  Future<({String transcript, String title})> fetchTranscript(String videoId);
}

class YouTubeTranscriptDataSourceImpl implements YouTubeTranscriptDataSource {
  final http.Client _client;
  final ApiConfig _apiConfig;

  YouTubeTranscriptDataSourceImpl(this._client, this._apiConfig);

  /// InnerTube clients to try in order (WEB first, then ANDROID fallback).
  /// Keys are loaded from ApiConfig (sourced from .env).
  List<_InnerTubeClient> get _clients => [
    _InnerTubeClient(
      name: 'WEB',
      key: _apiConfig.youtubeWebKey,
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      body: {
        'clientName': 'WEB',
        'clientVersion': '2.20240304.00.00',
      },
    ),
    _InnerTubeClient(
      name: 'ANDROID',
      key: _apiConfig.youtubeAndroidKey,
      userAgent: 'com.google.android.youtube/19.09.37 '
          '(Linux; U; Android 11) gzip',
      body: {
        'clientName': 'ANDROID',
        'clientVersion': '19.09.37',
        'androidSdkVersion': 30,
      },
    ),
  ];

  @override
  Future<({String transcript, String title})> fetchTranscript(String videoId) async {
    try {
      // Step 1: Get player response — try each InnerTube client
      Map<String, dynamic>? playerJson;
      String usedUserAgent = _clients.first.userAgent;

      for (final client in _clients) {
        debugPrint('[YT] Trying InnerTube client ${client.name} '
            'for videoId=$videoId');

        final url = 'https://www.youtube.com/youtubei/v1/player'
            '?key=${client.key}&prettyPrint=false';

        final response = await _client.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': client.userAgent,
          },
          body: jsonEncode({
            'context': {
              'client': {
                'hl': 'fr',
                'gl': 'FR',
                ...client.body,
              },
            },
            'videoId': videoId,
          }),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw const TimeoutFailure(
            'Le chargement de la vidéo YouTube a dépassé le délai (30s).',
          ),
        );

        debugPrint('[YT] ${client.name}: status=${response.statusCode}, '
            'body length=${response.body.length}');

        if (response.statusCode == 200) {
          playerJson = jsonDecode(response.body);
          usedUserAgent = client.userAgent;

          // Check playability
          final status = playerJson!['playabilityStatus']?['status'];
          if (status == 'OK') {
            debugPrint('[YT] ${client.name}: playability OK');
            break;
          }

          final reason = playerJson['playabilityStatus']?['reason'] ?? status;
          debugPrint('[YT] ${client.name}: not playable ($reason), '
              'trying next client');
          playerJson = null;
          continue;
        }

        debugPrint('[YT] ${client.name} failed: ${response.body}');
      }

      if (playerJson == null) {
        throw const ServerFailure(
          'Impossible de charger la vidéo YouTube. '
          'Vérifiez que la vidéo est publique.',
        );
      }

      // Step 2: Extract video title
      final videoTitle = playerJson['videoDetails']?['title'] as String? ??
          'youtube_transcript';
      debugPrint('[YT] Video title: $videoTitle');

      // Step 3: Extract caption tracks
      final captionTracks = _extractCaptionTracksFromJson(playerJson);
      debugPrint('[YT] Found ${captionTracks.length} caption tracks');

      if (captionTracks.isEmpty) {
        throw const ServerFailure(
          'Aucun sous-titre disponible pour cette vidéo. '
          'Vérifiez que la vidéo est publique et possède des sous-titres.',
        );
      }

      for (final track in captionTracks) {
        debugPrint('[YT] Track: lang=${track['languageCode']}, '
            'kind=${track['kind']}');
      }

      // Step 3: Select best caption track
      final captionUrl = _selectBestTrack(captionTracks);

      // Step 4: Fetch transcript — remove existing fmt, force srv1
      final cleanUrl =
          captionUrl.replaceAll(RegExp(r'[&?]fmt=[^&]*'), '');
      final fetchUrl = cleanUrl.contains('?')
          ? '$cleanUrl&fmt=srv1'
          : '$cleanUrl?fmt=srv1';

      debugPrint('[YT] Fetching transcript (srv1)...');

      var transcriptResponse = await _client.get(
        Uri.parse(fetchUrl),
        headers: {
          'User-Agent': usedUserAgent,
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 30));

      debugPrint('[YT] Transcript: status=${transcriptResponse.statusCode}, '
          'body=${transcriptResponse.body.length} bytes');

      // If srv1 returns empty, try without fmt override (accept srv3)
      if (transcriptResponse.statusCode == 200 &&
          transcriptResponse.body.isEmpty) {
        debugPrint('[YT] srv1 empty, retrying with original URL...');
        transcriptResponse = await _client.get(
          Uri.parse(captionUrl),
          headers: {
            'User-Agent': usedUserAgent,
            'Accept': '*/*',
          },
        ).timeout(const Duration(seconds: 30));

        debugPrint('[YT] Retry: status=${transcriptResponse.statusCode}, '
            'body=${transcriptResponse.body.length} bytes');
      }

      if (transcriptResponse.statusCode != 200) {
        throw ServerFailure(
          'Impossible de charger les sous-titres '
          '(code ${transcriptResponse.statusCode}).',
        );
      }

      final rawBody = transcriptResponse.body;
      if (rawBody.isEmpty) {
        throw const ServerFailure(
          'Le serveur YouTube a renvoyé une réponse vide pour les sous-titres.',
        );
      }

      debugPrint('[YT] Preview: '
          '${rawBody.substring(0, rawBody.length > 300 ? 300 : rawBody.length)}');

      // Step 5: Parse to plain text
      final transcript = _parseTranscriptXml(rawBody);
      debugPrint('[YT] Parsed transcript: ${transcript.length} chars');

      if (transcript.trim().isEmpty) {
        throw const ServerFailure(
          'Les sous-titres extraits sont vides après parsing.',
        );
      }

      return (transcript: transcript, title: videoTitle);
    } on TimeoutException {
      throw const TimeoutFailure(
        'Le chargement des sous-titres a dépassé le délai.',
      );
    } catch (e) {
      if (e is Failure) rethrow;
      debugPrint('[YT] Unexpected error: $e');
      throw ServerFailure(
          'Erreur lors de l\'extraction des sous-titres : ${e.toString()}');
    }
  }

  /// Extracts caption tracks from InnerTube player response JSON.
  List<Map<String, dynamic>> _extractCaptionTracksFromJson(
      Map<String, dynamic> playerJson) {
    try {
      final captions = playerJson['captions'];
      if (captions == null) return [];

      final renderer = captions['playerCaptionsTracklistRenderer'];
      if (renderer == null) return [];

      final tracks = renderer['captionTracks'];
      if (tracks == null) return [];

      return List<Map<String, dynamic>>.from(tracks);
    } catch (e) {
      debugPrint('[YT] Error extracting caption tracks: $e');
      return [];
    }
  }

  /// Selects the best caption track URL.
  /// Priority: manual > auto-generated, French > English > first available.
  String _selectBestTrack(List<Map<String, dynamic>> tracks) {
    final manual = tracks.where((t) => t['kind'] != 'asr').toList();
    final auto = tracks.where((t) => t['kind'] == 'asr').toList();

    const preferredLangs = ['fr', 'en'];

    for (final trackList in [manual, auto]) {
      if (trackList.isEmpty) continue;

      for (final lang in preferredLangs) {
        final match = trackList.where(
          (t) => (t['languageCode'] as String?)?.startsWith(lang) == true,
        );
        if (match.isNotEmpty) {
          debugPrint('[YT] Selected: lang=$lang, kind=${match.first['kind']}');
          return match.first['baseUrl'] as String;
        }
      }

      return trackList.first['baseUrl'] as String;
    }

    return tracks.first['baseUrl'] as String;
  }

  /// Parses YouTube transcript XML into plain text.
  /// Supports srv1 (<text>) and srv3 (<p>/<s>) formats.
  String _parseTranscriptXml(String xmlContent) {
    xml.XmlDocument document;

    try {
      document = xml.XmlDocument.parse(xmlContent);
    } catch (e) {
      debugPrint('[YT] XmlDocument.parse failed: $e');
      try {
        document = xml.XmlDocument.parse('<root>$xmlContent</root>');
      } catch (_) {
        return _parseTranscriptRegex(xmlContent);
      }
    }

    // srv1: <text> elements
    final textElements = document.findAllElements('text');
    if (textElements.isNotEmpty) {
      debugPrint('[YT] Parsing srv1: ${textElements.length} <text> elements');
      final buffer = StringBuffer();
      for (final element in textElements) {
        final text = _decodeHtmlEntities(element.innerText)
            .replaceAll('\n', ' ')
            .trim();
        if (text.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(text);
        }
      }
      return buffer.toString();
    }

    // srv3: <p> > <s> elements
    final pElements = document.findAllElements('p');
    if (pElements.isNotEmpty) {
      debugPrint('[YT] Parsing srv3: ${pElements.length} <p> elements');
      final buffer = StringBuffer();
      for (final p in pElements) {
        final segments = p.findElements('s');
        if (segments.isNotEmpty) {
          for (final s in segments) {
            final text = _decodeHtmlEntities(s.innerText)
                .replaceAll('\n', ' ')
                .trim();
            if (text.isNotEmpty) {
              buffer.write(text);
            }
          }
        } else {
          final text = _decodeHtmlEntities(p.innerText)
              .replaceAll('\n', ' ')
              .trim();
          if (text.isNotEmpty) {
            if (buffer.isNotEmpty) buffer.write(' ');
            buffer.write(text);
          }
        }
      }
      return buffer.toString();
    }

    return _parseTranscriptRegex(xmlContent);
  }

  /// Regex fallback for malformed XML.
  String _parseTranscriptRegex(String content) {
    final textPattern = RegExp(r'<text[^>]*>(.*?)</text>', dotAll: true);
    var matches = textPattern.allMatches(content);

    if (matches.isEmpty) {
      final sPattern = RegExp(r'<s[^>]*>(.*?)</s>', dotAll: true);
      matches = sPattern.allMatches(content);
    }

    final buffer = StringBuffer();
    for (final match in matches) {
      final text = _decodeHtmlEntities(match.group(1) ?? '')
          .replaceAll('\n', ' ')
          .trim();
      if (text.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(text);
      }
    }

    return buffer.toString();
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}

/// Configuration for an InnerTube client variant.
class _InnerTubeClient {
  final String name;
  final String key;
  final String userAgent;
  final Map<String, dynamic> body;

  const _InnerTubeClient({
    required this.name,
    required this.key,
    required this.userAgent,
    required this.body,
  });
}
