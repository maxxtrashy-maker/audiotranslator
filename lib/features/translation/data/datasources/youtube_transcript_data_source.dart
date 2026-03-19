import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../../../../core/config/api_config.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/youtube_subtitle_track.dart';

abstract class YouTubeTranscriptDataSource {
  Future<({String transcript, String title, List<YouTubeSubtitleTrack> tracks})> fetchTranscript(String videoId);
}

class YouTubeTranscriptDataSourceImpl implements YouTubeTranscriptDataSource {
  final http.Client _client;
  final ApiConfig _apiConfig;

  YouTubeTranscriptDataSourceImpl(this._client, this._apiConfig);

  /// InnerTube clients to try in order (WEB first, then ANDROID, then IOS fallback).
  /// Keys are loaded from ApiConfig (sourced from .env).
  List<_InnerTubeClient> get _clients => [
    _InnerTubeClient(
      name: 'WEB',
      key: _apiConfig.youtubeWebKey,
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      body: {
        'clientName': 'WEB',
        'clientVersion': '2.20240304.00.00',
      },
      extraHeaders: {
        'X-Youtube-Client-Name': '1',
        'X-Youtube-Client-Version': '2.20240304.00.00',
        'Origin': 'https://www.youtube.com',
        'Referer': 'https://www.youtube.com/',
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
      extraHeaders: {
        'X-Youtube-Client-Name': '3',
        'X-Youtube-Client-Version': '19.09.37',
      },
    ),
    _InnerTubeClient(
      name: 'IOS',
      key: _apiConfig.youtubeWebKey, // Use Web key for IOS as fallback if needed, or appropriate key
      userAgent: 'com.google.ios.youtube/19.08.2 (iPhone16,2; U; CPU iOS 17_4_1 like Mac OS X; en_US)',
      body: {
        'clientName': 'IOS',
        'clientVersion': '19.08.2',
        'osName': 'iOS',
        'osVersion': '17.4.1',
        'platform': 'MOBILE',
      },
      extraHeaders: {
        'X-Youtube-Client-Name': '5',
        'X-Youtube-Client-Version': '19.08.2',
      },
    ),
  ];

  @override
  Future<({String transcript, String title, List<YouTubeSubtitleTrack> tracks})> fetchTranscript(String videoId) async {
    try {
      Map<String, dynamic>? playerJson;
      String usedUserAgent = _clients.first.userAgent;

      for (final client in _clients) {
        debugPrint('[YT] Trying InnerTube client ${client.name} for videoId=$videoId');

        final url = 'https://www.youtube.com/youtubei/v1/player?key=${client.key}&prettyPrint=false';

        final response = await _client.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': client.userAgent,
            ...client.extraHeaders,
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

        if (response.statusCode == 200) {
          playerJson = jsonDecode(response.body);
          usedUserAgent = client.userAgent;

          final playabilityStatus = playerJson!['playabilityStatus'];
          if (playabilityStatus?['status'] == 'OK') {
             // Check if video ID matches to avoid bot detection redirects
             final respVideoId = playerJson['videoDetails']?['videoId'];
             if (respVideoId != null && respVideoId != videoId) {
               debugPrint('[YT] ${client.name}: Video ID mismatch ($respVideoId != $videoId)');
               playerJson = null;
               continue;
             }
            break;
          }

          _checkPlayabilityStatus(playabilityStatus);
          playerJson = null;
          continue;
        }
      }

      if (playerJson == null) {
        throw const ServerFailure(
          'Impossible de charger la vidéo YouTube. Vérifiez que la vidéo est publique.',
        );
      }

      final videoTitle = playerJson['videoDetails']?['title'] as String? ?? 'youtube_transcript';
      final tracks = _extractCaptionTracksFromJson(playerJson);

      if (tracks.isEmpty) {
        throw const ServerFailure(
          'Aucun sous-titre disponible pour cette vidéo.',
        );
      }

      final bestTrack = _selectBestTrack(tracks);

      // Fetch transcript in srv1 format
      final cleanUrl = bestTrack.baseUrl.replaceAll(RegExp(r'[&?]fmt=[^&]*'), '');
      final fetchUrl = cleanUrl.contains('?') ? '$cleanUrl&fmt=srv1' : '$cleanUrl?fmt=srv1';

      var transcriptResponse = await _client.get(
        Uri.parse(fetchUrl),
        headers: {
          'User-Agent': usedUserAgent,
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 30));

      if (transcriptResponse.statusCode != 200 || transcriptResponse.body.isEmpty) {
         // Retry with VTT if srv1 fails
         final vttUrl = cleanUrl.contains('?') ? '$cleanUrl&fmt=vtt' : '$cleanUrl?fmt=vtt';
         transcriptResponse = await _client.get(
            Uri.parse(vttUrl),
            headers: {'User-Agent': usedUserAgent},
         ).timeout(const Duration(seconds: 30));
      }

      if (transcriptResponse.statusCode != 200) {
        throw ServerFailure('Impossible de charger les sous-titres (code ${transcriptResponse.statusCode}).');
      }

      final transcript = _parseTranscript(transcriptResponse.body);

      return (transcript: transcript, title: videoTitle, tracks: tracks);
    } on Failure {
      rethrow;
    } catch (e) {
      debugPrint('[YT] Unexpected error: $e');
      throw ServerFailure('Erreur lors de l\'extraction des sous-titres : ${e.toString()}');
    }
  }

  void _checkPlayabilityStatus(Map<String, dynamic>? playabilityStatus) {
    if (playabilityStatus == null) return;
    final status = playabilityStatus['status'] as String?;
    final reason = playabilityStatus['reason'] as String?;

    if (status == 'OK') return;

    if (status == 'LOGIN_REQUIRED') {
      if (reason?.contains('age') == true) {
        throw const ServerFailure('Cette vidéo est soumise à une limite d\'âge.');
      }
      if (reason?.contains('private') == true) {
        throw const ServerFailure('Cette vidéo est privée.');
      }
    }

    if (status == 'UNPLAYABLE' || status == 'ERROR') {
       if (reason?.contains('members') == true) {
         throw const ServerFailure('Cette vidéo est réservée aux membres.');
       }
       throw ServerFailure(reason ?? 'Vidéo non disponible.');
    }
  }

  List<YouTubeSubtitleTrack> _extractCaptionTracksFromJson(Map<String, dynamic> playerJson) {
    final List<YouTubeSubtitleTrack> tracks = [];
    try {
      final captions = playerJson['captions'];
      final renderer = captions?['playerCaptionsTracklistRenderer'];
      final captionTracks = renderer?['captionTracks'] as List?;

      if (captionTracks != null) {
        for (final track in captionTracks) {
          final languageCode = track['languageCode'] as String?;
          final baseUrl = track['baseUrl'] as String?;
          final name = track['name']?['simpleText'] as String?;
          final vssId = track['vssId'] as String?;

          if (languageCode != null && baseUrl != null) {
            tracks.add(YouTubeSubtitleTrack(
              languageCode: languageCode,
              name: name ?? languageCode,
              baseUrl: baseUrl,
              isAutoGenerated: vssId?.startsWith('a.') ?? false,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('[YT] Error extracting caption tracks: $e');
    }
    return tracks;
  }

  YouTubeSubtitleTrack _selectBestTrack(List<YouTubeSubtitleTrack> tracks) {
    final manual = tracks.where((t) => !t.isAutoGenerated).toList();
    final auto = tracks.where((t) => t.isAutoGenerated).toList();

    for (final trackList in [manual, auto]) {
      if (trackList.isEmpty) continue;

      // 1. Try French
      try {
        return trackList.firstWhere((t) => t.languageCode.startsWith('fr'));
      } catch (_) {}

      // 2. Try English
      try {
        return trackList.firstWhere((t) => t.languageCode.startsWith('en'));
      } catch (_) {}

      // 3. Take first available
      return trackList.first;
    }
    return tracks.first;
  }

  String _parseTranscript(String content) {
    if (content.contains('<transcript>') || content.contains('<timedtext')) {
      return _parseTranscriptXml(content);
    }
    if (content.contains('WEBVTT')) {
      return _parseVtt(content);
    }
    return content;
  }

  String _parseTranscriptXml(String xmlContent) {
    try {
      final document = xml.XmlDocument.parse(xmlContent);
      final buffer = StringBuffer();

      final textElements = document.findAllElements('text');
      if (textElements.isNotEmpty) {
        for (final element in textElements) {
          final text = _decodeHtmlEntities(element.innerText).trim();
          if (text.isNotEmpty) {
            if (buffer.isNotEmpty) buffer.write(' ');
            buffer.write(text.replaceAll('\n', ' '));
          }
        }
      } else {
        // srv3 support
        final pElements = document.findAllElements('p');
        for (final p in pElements) {
          final text = _decodeHtmlEntities(p.innerText).trim();
          if (text.isNotEmpty) {
            if (buffer.isNotEmpty) buffer.write(' ');
            buffer.write(text.replaceAll('\n', ' '));
          }
        }
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('[YT] XML Parse error: $e');
      return xmlContent.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
    }
  }

  String _parseVtt(String vttContent) {
    final lines = vttContent.split('\n');
    final buffer = StringBuffer();
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty ||
          line.startsWith('WEBVTT') ||
          line.startsWith('Kind:') ||
          line.startsWith('Language:') ||
          RegExp(r'^\d{2}:\d{2}').hasMatch(line) ||
          RegExp(r'^\d+$').hasMatch(line)) {
        continue;
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(line);
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

class _InnerTubeClient {
  final String name;
  final String key;
  final String userAgent;
  final Map<String, dynamic> body;
  final Map<String, String> extraHeaders;

  const _InnerTubeClient({
    required this.name,
    required this.key,
    required this.userAgent,
    required this.body,
    this.extraHeaders = const {},
  });
}
