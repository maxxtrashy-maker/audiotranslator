import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart' as xml;
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/subtitle_cleaner.dart';
import '../../domain/entities/youtube_subtitle_track.dart';

abstract class YouTubeTranscriptDataSource {
  Future<({String transcript, String title, List<YouTubeSubtitleTrack> tracks})>
      fetchTranscript(String videoId);
}

/// YouTube subtitle extraction inspired by NewPipe's approach.
///
/// Uses dart:io HttpClient for automatic cookie management across requests.
/// Strategy:
///   1. Fetch visitorData from InnerTube visitor_id endpoint
///   2. ANDROID client via youtubei.googleapis.com (primary)
///   3. IOS client fallback
///   4. Watch page scraping fallback
///   5. Fetch caption URL directly (no auth needed once obtained)
class YouTubeTranscriptDataSourceImpl implements YouTubeTranscriptDataSource {
  final io.HttpClient Function() _clientFactory;

  YouTubeTranscriptDataSourceImpl({io.HttpClient Function()? clientFactory})
      : _clientFactory = clientFactory ?? _defaultClientFactory;

  static io.HttpClient _defaultClientFactory() {
    final client = io.HttpClient();
    client.userAgent = _webUserAgent;
    return client;
  }

  // ---------------------------------------------------------------------------
  // Constants — based on NewPipe's ClientsConstants.java
  // ---------------------------------------------------------------------------

  static const _webUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  static const _androidUserAgent =
      'com.google.android.youtube/21.03.36 (Linux; U; Android 16; US) gzip';

  static const _iosUserAgent =
      'com.google.ios.youtube/21.03.2 (iPhone16,2; U; CPU iOS 18_7_2 like Mac OS X; US)';

  // InnerTube endpoint — mobile clients use googleapis.com (NewPipe)
  static const _googleapisBase = 'https://youtubei.googleapis.com/youtubei/v1';

  static final _random = Random();

  /// Generates a random nonce (like NewPipe's contentPlaybackNonce).
  static String _generateNonce(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    return List.generate(length, (_) => chars[_random.nextInt(chars.length)])
        .join();
  }

  // ---------------------------------------------------------------------------
  // InnerTube client configs
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _androidClientContext({String? visitorData}) => {
        'clientName': 'ANDROID',
        'clientVersion': '21.03.36',
        'platform': 'MOBILE',
        'osName': 'Android',
        'osVersion': '16',
        'androidSdkVersion': 36,
        'hl': 'fr',
        'gl': 'FR',
        'utcOffsetMinutes': 0,
        if (visitorData != null) 'visitorData': visitorData,
      };

  static Map<String, dynamic> _iosClientContext({String? visitorData}) => {
        'clientName': 'IOS',
        'clientVersion': '21.03.2',
        'platform': 'MOBILE',
        'deviceMake': 'Apple',
        'deviceModel': 'iPhone16,2',
        'osName': 'iOS',
        'osVersion': '18.7.2.22H124',
        'hl': 'fr',
        'gl': 'FR',
        'utcOffsetMinutes': 0,
        if (visitorData != null) 'visitorData': visitorData,
      };

  static const _mobileHeaders = {
    'X-Goog-Api-Format-Version': '2',
    'Content-Type': 'application/json',
  };

  // ---------------------------------------------------------------------------
  // HTTP helpers using dart:io (automatic cookie jar)
  // ---------------------------------------------------------------------------

  Future<({int statusCode, String body})> _get(
    io.HttpClient client,
    String url, {
    Map<String, String>? headers,
  }) async {
    final request = await client.getUrl(Uri.parse(url));
    headers?.forEach((k, v) => request.headers.set(k, v));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return (statusCode: response.statusCode, body: body);
  }

  Future<({int statusCode, String body})> _postJson(
    io.HttpClient client,
    String url,
    Map<String, dynamic> jsonBody, {
    Map<String, String>? headers,
  }) async {
    final request = await client.postUrl(Uri.parse(url));
    request.headers.set('Content-Type', 'application/json');
    headers?.forEach((k, v) => request.headers.set(k, v));
    request.write(jsonEncode(jsonBody));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return (statusCode: response.statusCode, body: body);
  }

  // ---------------------------------------------------------------------------
  // Main fetch flow
  // ---------------------------------------------------------------------------

  @override
  Future<({String transcript, String title, List<YouTubeSubtitleTrack> tracks})>
      fetchTranscript(String videoId) async {
    final client = _clientFactory();
    try {
      // --- Step 1: Fetch visitorData ---
      final visitorData = await _fetchVisitorData(client);

      // --- Step 2: Try ANDROID client (primary, like NewPipe) ---
      Map<String, dynamic>? playerJson;
      playerJson = await _fetchPlayerAndroid(client, videoId, visitorData);

      // --- Step 3: Fallback to IOS ---
      if (playerJson == null) {
        playerJson = await _fetchPlayerIos(client, videoId, visitorData);
      }

      // --- Step 4: Fallback to watch page scraping ---
      if (playerJson == null) {
        playerJson = await _fetchPlayerFromWatchPage(client, videoId);
      }

      if (playerJson == null) {
        throw const ServerFailure(
          'Impossible de charger la vidéo YouTube. '
          'Vérifiez que la vidéo est publique.',
        );
      }

      // --- Validate playability ---
      _checkPlayabilityStatus(
        playerJson['playabilityStatus'] as Map<String, dynamic>?,
      );

      final videoTitle = playerJson['videoDetails']?['title'] as String? ??
          'youtube_transcript';
      debugPrint('[YT] Video title: $videoTitle');

      // --- Extract caption tracks ---
      final tracks = _extractCaptionTracks(playerJson);
      debugPrint('[YT] Found ${tracks.length} caption tracks');

      if (tracks.isEmpty) {
        throw const ServerFailure(
          'Aucun sous-titre disponible pour cette vidéo.',
        );
      }

      for (final t in tracks) {
        debugPrint('[YT] Track: lang=${t.languageCode}, '
            'auto=${t.isAutoGenerated}, name=${t.name}');
      }

      // --- Step 5: Fetch transcript from caption URL ---
      final bestTrack = _selectBestTrack(tracks);
      final transcript = await _fetchTranscriptFromTrack(client, bestTrack);

      if (transcript.trim().isEmpty) {
        throw const ServerFailure('Les sous-titres extraits sont vides.');
      }

      // Clean non-speech artifacts ([musique], >>, filler words, etc.)
      final cleaned = SubtitleCleaner.clean(transcript);
      debugPrint('[YT] Final transcript: ${cleaned.length} chars '
          '(cleaned from ${transcript.length})');
      return (transcript: cleaned, title: videoTitle, tracks: tracks);
    } on TimeoutException {
      throw const TimeoutFailure(
        'Le chargement des sous-titres a dépassé le délai.',
      );
    } catch (e) {
      if (e is Failure) rethrow;
      debugPrint('[YT] Unexpected error: $e');
      throw ServerFailure(
          'Erreur lors de l\'extraction des sous-titres : ${e.toString()}');
    } finally {
      client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // visitorData (NewPipe: fetched before every player request)
  // ---------------------------------------------------------------------------

  Future<String?> _fetchVisitorData(io.HttpClient client) async {
    debugPrint('[YT] Fetching visitorData...');
    try {
      final result = await _postJson(
        client,
        '$_googleapisBase/visitor_id?prettyPrint=false',
        {
          'context': {'client': _androidClientContext()},
        },
        headers: _mobileHeaders,
      ).timeout(const Duration(seconds: 10));

      if (result.statusCode == 200) {
        final json = jsonDecode(result.body) as Map<String, dynamic>;
        final vd = json['responseContext']?['visitorData'] as String?;
        if (vd != null) {
          debugPrint('[YT] Got visitorData: ${vd.substring(0, min(20, vd.length))}...');
          return vd;
        }
      }
      debugPrint('[YT] visitorData: status=${result.statusCode}');
    } catch (e) {
      debugPrint('[YT] visitorData error: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Player requests (NewPipe order: ANDROID → IOS → watch page)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _fetchPlayerAndroid(
      io.HttpClient client, String videoId, String? visitorData) async {
    debugPrint('[YT] Trying ANDROID client for videoId=$videoId');
    final t = _generateNonce(12);
    try {
      final result = await _postJson(
        client,
        '$_googleapisBase/player?prettyPrint=false&t=$t&id=$videoId',
        {
          'context': {
            'client': _androidClientContext(visitorData: visitorData),
            'request': {'internalExperimentFlags': [], 'useSsl': true},
            'user': {'lockedSafetyMode': false},
          },
          'videoId': videoId,
          'cpn': _generateNonce(16),
          'contentCheckOk': true,
          'racyCheckOk': true,
        },
        headers: {
          ..._mobileHeaders,
          'User-Agent': _androidUserAgent,
        },
      ).timeout(const Duration(seconds: 30));

      debugPrint('[YT] ANDROID: status=${result.statusCode}, '
          'body length=${result.body.length}');

      return _validatePlayerResponse(result, videoId, 'ANDROID');
    } catch (e) {
      debugPrint('[YT] ANDROID error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchPlayerIos(
      io.HttpClient client, String videoId, String? visitorData) async {
    debugPrint('[YT] Trying IOS client for videoId=$videoId');
    final t = _generateNonce(12);
    try {
      final result = await _postJson(
        client,
        '$_googleapisBase/player?prettyPrint=false&t=$t&id=$videoId',
        {
          'context': {
            'client': _iosClientContext(visitorData: visitorData),
            'request': {'internalExperimentFlags': [], 'useSsl': true},
            'user': {'lockedSafetyMode': false},
          },
          'videoId': videoId,
          'cpn': _generateNonce(16),
          'contentCheckOk': true,
          'racyCheckOk': true,
        },
        headers: {
          ..._mobileHeaders,
          'User-Agent': _iosUserAgent,
        },
      ).timeout(const Duration(seconds: 30));

      debugPrint('[YT] IOS: status=${result.statusCode}, '
          'body length=${result.body.length}');

      return _validatePlayerResponse(result, videoId, 'IOS');
    } catch (e) {
      debugPrint('[YT] IOS error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchPlayerFromWatchPage(
      io.HttpClient client, String videoId) async {
    debugPrint('[YT] Trying watch page scraping for videoId=$videoId');
    try {
      final result = await _get(
        client,
        'https://www.youtube.com/watch?v=$videoId&hl=fr',
        headers: {
          'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
          'Cookie': 'SOCS=CAE=',
        },
      ).timeout(const Duration(seconds: 30));

      debugPrint('[YT] Watch page: status=${result.statusCode}, '
          'body length=${result.body.length}');

      if (result.statusCode != 200) return null;

      final match = RegExp(
        r'var\s+ytInitialPlayerResponse\s*=\s*(\{.+?\})\s*;',
        dotAll: true,
      ).firstMatch(result.body);
      if (match == null) {
        debugPrint('[YT] Watch page: ytInitialPlayerResponse not found');
        return null;
      }

      final json = jsonDecode(match.group(1)!) as Map<String, dynamic>;
      final status = json['playabilityStatus']?['status'];
      if (status == 'OK') {
        debugPrint('[YT] Watch page: playability OK');
        return json;
      }
      debugPrint('[YT] Watch page: not playable ($status)');
      return null;
    } catch (e) {
      debugPrint('[YT] Watch page error: $e');
      return null;
    }
  }

  Map<String, dynamic>? _validatePlayerResponse(
    ({int statusCode, String body}) result,
    String videoId,
    String clientName,
  ) {
    if (result.statusCode != 200) {
      debugPrint('[YT] $clientName failed: status=${result.statusCode}');
      return null;
    }

    final json = jsonDecode(result.body) as Map<String, dynamic>;
    final status = json['playabilityStatus']?['status'];

    if (status != 'OK') {
      final reason = json['playabilityStatus']?['reason'] ?? status;
      debugPrint('[YT] $clientName: not playable ($reason)');
      return null;
    }

    // NewPipe: detect spoofed responses (video ID mismatch)
    final respVideoId = json['videoDetails']?['videoId'];
    if (respVideoId != null && respVideoId != videoId) {
      debugPrint('[YT] $clientName: video ID mismatch '
          '($respVideoId != $videoId)');
      return null;
    }

    debugPrint('[YT] $clientName: playability OK');
    return json;
  }

  // ---------------------------------------------------------------------------
  // Playability status (Jules' error messages)
  // ---------------------------------------------------------------------------

  void _checkPlayabilityStatus(Map<String, dynamic>? playabilityStatus) {
    if (playabilityStatus == null) return;
    final status = playabilityStatus['status'] as String?;
    final reason = playabilityStatus['reason'] as String?;

    if (status == 'OK') return;

    if (status == 'LOGIN_REQUIRED') {
      if (reason?.contains('age') == true) {
        throw const ServerFailure(
            'Cette vidéo est soumise à une limite d\'âge.');
      }
      if (reason?.contains('private') == true) {
        throw const ServerFailure('Cette vidéo est privée.');
      }
    }

    if (status == 'UNPLAYABLE' || status == 'ERROR') {
      if (reason?.contains('members') == true) {
        throw const ServerFailure('Cette vidéo est réservée aux membres.');
      }
      // NewPipe: detect bot blocking
      if (reason?.contains('bot') == true) {
        throw const ServerFailure(
            'YouTube a temporairement bloqué l\'accès depuis cette IP.');
      }
      throw ServerFailure(reason ?? 'Vidéo non disponible.');
    }
  }

  // ---------------------------------------------------------------------------
  // Caption tracks extraction (NewPipe + Jules' YouTubeSubtitleTrack)
  // ---------------------------------------------------------------------------

  List<YouTubeSubtitleTrack> _extractCaptionTracks(
      Map<String, dynamic> playerJson) {
    final List<YouTubeSubtitleTrack> tracks = [];
    try {
      final captionTracks = playerJson['captions']
          ?['playerCaptionsTracklistRenderer']?['captionTracks'] as List?;
      if (captionTracks == null) return [];

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
            // NewPipe: auto-generated detection via vssId prefix
            isAutoGenerated: vssId?.startsWith('a.') ?? false,
          ));
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

      for (final lang in ['fr', 'en']) {
        final match = trackList
            .where((t) => t.languageCode.startsWith(lang))
            .toList();
        if (match.isNotEmpty) {
          debugPrint('[YT] Selected: lang=$lang, '
              'auto=${match.first.isAutoGenerated}');
          return match.first;
        }
      }
      return trackList.first;
    }
    return tracks.first;
  }

  // ---------------------------------------------------------------------------
  // Transcript fetching — NewPipe: strip fmt & tlang, append desired format
  // ---------------------------------------------------------------------------

  Future<String> _fetchTranscriptFromTrack(
      io.HttpClient client, YouTubeSubtitleTrack track) async {
    // NewPipe: strip existing fmt and tlang params, then add desired format
    final cleanUrl = track.baseUrl
        .replaceAll(RegExp(r'[&?]fmt=[^&]*'), '')
        .replaceAll(RegExp(r'[&?]tlang=[^&]*'), '');

    // Try formats in order: srv1 (XML), vtt (WebVTT)
    for (final fmt in ['srv1', 'vtt']) {
      final url = cleanUrl.contains('?')
          ? '$cleanUrl&fmt=$fmt'
          : '$cleanUrl?fmt=$fmt';

      debugPrint('[YT] Fetching transcript (fmt=$fmt)...');
      try {
        final result = await _get(client, url).timeout(
          const Duration(seconds: 30),
        );

        debugPrint('[YT] Transcript ($fmt): status=${result.statusCode}, '
            'body=${result.body.length} bytes');

        if (result.statusCode == 200 && result.body.isNotEmpty) {
          final parsed = _parseTranscript(result.body);
          if (parsed.isNotEmpty) return parsed;
        }
      } catch (e) {
        debugPrint('[YT] Transcript ($fmt) error: $e');
      }
    }

    throw const ServerFailure(
      'Le serveur YouTube a renvoyé une réponse vide pour les sous-titres.',
    );
  }

  // ---------------------------------------------------------------------------
  // Transcript parsing (srv1 XML, srv3 XML, VTT)
  // ---------------------------------------------------------------------------

  String _parseTranscript(String content) {
    if (content.contains('WEBVTT')) return _parseVtt(content);
    return _parseTranscriptXml(content);
  }

  String _parseTranscriptXml(String xmlContent) {
    try {
      final document = xml.XmlDocument.parse(xmlContent);
      final buffer = StringBuffer();

      // srv1: <text> elements
      final textElements = document.findAllElements('text');
      if (textElements.isNotEmpty) {
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

      // srv3: <p> elements
      final pElements = document.findAllElements('p');
      for (final p in pElements) {
        final text = _decodeHtmlEntities(p.innerText)
            .replaceAll('\n', ' ')
            .trim();
        if (text.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(text);
        }
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('[YT] XML parse error: $e');
      // Regex fallback
      return _parseTranscriptRegex(xmlContent);
    }
  }

  String _parseTranscriptRegex(String content) {
    final pattern = RegExp(r'<text[^>]*>(.*?)</text>', dotAll: true);
    var matches = pattern.allMatches(content);
    if (matches.isEmpty) {
      matches = RegExp(r'<s[^>]*>(.*?)</s>', dotAll: true).allMatches(content);
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
