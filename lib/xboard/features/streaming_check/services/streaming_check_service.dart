import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/features/streaming_check/models/streaming_test_result.dart';

class StreamingCheckService {
  const StreamingCheckService();

  static const targets = <StreamingTarget>[
    StreamingTarget(
      id: 'netflix',
      name: 'Netflix',
      url: 'https://www.netflix.com/title/70143836',
    ),
    StreamingTarget(
      id: 'disney',
      name: 'Disney+',
      url: 'https://www.disneyplus.com/',
    ),
    StreamingTarget(
      id: 'youtube',
      name: 'YouTube Premium',
      url: 'https://www.youtube.com/premium',
    ),
    StreamingTarget(
      id: 'prime_video',
      name: 'Prime Video',
      url: 'https://www.primevideo.com/',
    ),
    StreamingTarget(
      id: 'max',
      name: 'Max',
      url: 'https://www.max.com/',
    ),
    StreamingTarget(
      id: 'apple_tv',
      name: 'Apple TV+',
      url: 'https://tv.apple.com/',
    ),
    StreamingTarget(
      id: 'bbc_iplayer',
      name: 'BBC iPlayer',
      url: 'https://www.bbc.co.uk/iplayer',
    ),
    StreamingTarget(
      id: 'dazn',
      name: 'DAZN',
      url: 'https://www.dazn.com/',
    ),
    StreamingTarget(
      id: 'chatgpt',
      name: 'ChatGPT',
      url: 'https://chatgpt.com/',
    ),
    StreamingTarget(
      id: 'claude',
      name: 'Claude',
      url: 'https://claude.ai/',
    ),
    StreamingTarget(
      id: 'gemini',
      name: 'Gemini',
      url: 'https://gemini.google.com/',
    ),
    StreamingTarget(
      id: 'copilot',
      name: 'Microsoft Copilot',
      url: 'https://copilot.microsoft.com/',
    ),
    StreamingTarget(
      id: 'crunchyroll',
      name: 'Crunchyroll',
      url: 'https://www.crunchyroll.com/',
    ),
    StreamingTarget(
      id: 'tiktok',
      name: 'TikTok',
      url: 'https://www.tiktok.com/explore',
    ),
    StreamingTarget(
      id: 'grok',
      name: 'Grok',
      url: 'https://grok.com/',
    ),
    StreamingTarget(
      id: 'google_ai_studio',
      name: 'Google AI Studio',
      url: 'https://aistudio.google.com/welcome',
    ),
  ];

  Future<String?> resolveCurrentNodeName() async {
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        final controller = globalState.appController;
        final groups = controller.getCurrentGroups();
        final currentGroupName = controller.getCurrentGroupName()?.toString();
        final candidates = [
          ...groups.where((group) => group.name == currentGroupName),
          ...groups.where((group) => group.realNow.isNotEmpty),
        ];
        for (final group in candidates) {
          final selected =
              controller.getSelectedProxyName(group.name)?.toString();
          final candidate =
              selected?.isNotEmpty == true ? selected! : group.realNow;
          if (candidate.isEmpty) continue;
          final state = controller.getProxyCardState(candidate);
          return state.proxyName.isEmpty ? candidate : state.proxyName;
        }
      } catch (_) {
        // The core may still be synchronizing immediately after connection.
      }
      if (attempt < 5) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    return null;
  }

  Future<String?> detectRegion(String proxyName) async {
    final raw = await clashCore.streamingProbe(
      'https://www.cloudflare.com/cdn-cgi/trace',
      proxyName,
    );
    if (raw['ok'] != true) return null;
    final body = raw['body']?.toString() ?? '';
    return parseRegion(body);
  }

  static String? parseRegion(String body) {
    final match =
        RegExp(r'^loc=([A-Za-z]{2})$', multiLine: true).firstMatch(body);
    return match?.group(1)?.toUpperCase();
  }

  static StreamingTestStatus classifyStatusCode(int statusCode) {
    return switch (statusCode) {
      >= 200 && < 400 => StreamingTestStatus.accessible,
      451 => StreamingTestStatus.restricted,
      403 => StreamingTestStatus.uncertain,
      _ => StreamingTestStatus.unavailable,
    };
  }

  Future<StreamingTestResult> testTarget(
    StreamingTarget target,
    String proxyName, {
    String? region,
  }) async {
    try {
      final routeRegionFuture = _detectPlatformRouteRegion(
        target.id,
        proxyName,
      );
      final result = await switch (target.id) {
        'bbc_iplayer' => _testBbc(target, proxyName, region),
        'dazn' => _testDazn(target, proxyName, region),
        'netflix' => _testNetflix(target, proxyName, region),
        'youtube' => _testYoutube(target, proxyName, region),
        'prime_video' => _testPrimeVideo(target, proxyName, region),
        'chatgpt' => _testChatGpt(target, proxyName, region),
        'claude' => _testClaude(target, proxyName, region),
        'max' => _testMax(target, proxyName, region),
        'disney' => _testDisney(target, proxyName, region),
        'gemini' => _testGemini(target, proxyName, region),
        'crunchyroll' => _testCrunchyroll(target, proxyName, region),
        'tiktok' => _testTikTok(target, proxyName, region),
        'grok' => _testProtectedAi(target, proxyName, region),
        'google_ai_studio' => _testGoogleAiStudio(target, proxyName, region),
        _ => _testGeneric(target, proxyName, region),
      };
      final routeRegion = await routeRegionFuture;
      const responseRegionTargets = {
        'bbc_iplayer',
        'dazn',
        'youtube',
        'prime_video',
        'max',
        'crunchyroll',
        'tiktok',
      };
      final platformRegion = routeRegion ??
          (responseRegionTargets.contains(target.id) ? result.region : null) ??
          region;
      return StreamingTestResult(
        target: result.target,
        status: result.status,
        elapsedMs: result.elapsedMs,
        region: platformRegion,
        statusCode: result.statusCode,
        detail: result.detail,
      );
    } catch (error) {
      final message = error.toString();
      final timeout = message.toLowerCase().contains('timeout') ||
          message.toLowerCase().contains('deadline');
      return StreamingTestResult(
        target: target,
        status:
            timeout ? StreamingTestStatus.timeout : StreamingTestStatus.error,
        elapsedMs: 0,
        region: region,
        detail: message,
      );
    }
  }

  Future<String?> _detectPlatformRouteRegion(
    String targetId,
    String proxyName,
  ) async {
    final traceUrl = switch (targetId) {
      'chatgpt' => 'https://chatgpt.com/cdn-cgi/trace',
      'claude' => 'https://claude.ai/cdn-cgi/trace',
      'crunchyroll' => 'https://www.crunchyroll.com/cdn-cgi/trace',
      'grok' => 'https://grok.com/cdn-cgi/trace',
      _ => null,
    };
    if (traceUrl == null) return null;
    try {
      final raw = await _probe(
        proxyName,
        traceUrl,
        timeout: const Duration(seconds: 8),
        retryTransient: true,
      );
      if (raw['ok'] != true || _statusCode(raw) != 200) return null;
      return parseRegion(_body(raw));
    } catch (_) {
      return null;
    }
  }

  Future<StreamingTestResult> _testBbc(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final responses = await Future.wait([
      _probe(
        proxyName,
        'https://open.live.bbc.co.uk/mediaselector/6/select/version/2.0/'
        'mediaset/pc/vpid/bbc_one_london/format/json/jsfunc/JS_callbacks0',
        timeout: const Duration(seconds: 16),
        retryTransient: true,
      ),
      _probe(
        proxyName,
        'https://www.bbc.co.uk/userinfo',
        timeout: const Duration(seconds: 12),
        retryTransient: true,
      ),
    ]);
    final mediaRaw = responses.first;
    final userInfoRaw = responses.last;
    final raw = _mergeResponses(responses);
    final body = _body(mediaRaw).toLowerCase();
    final userInfo = _decodeJson(_body(userInfoRaw));
    final isUk =
        _jsonValue(userInfo, 'X-Ip_is_uk_combined')?.toString().toLowerCase();
    final bbcRegion =
        _jsonValue(userInfo, 'X-Country')?.toString().toUpperCase();
    if (body.contains('geolocation')) {
      return _result(
        target,
        raw,
        StreamingTestStatus.restricted,
        bbcRegion,
        detail: 'BBC media API returned geolocation restriction',
      );
    }
    if (body.contains('vs-hls-push-uk') || body.contains('href')) {
      return _result(
        target,
        raw,
        StreamingTestStatus.accessible,
        bbcRegion,
        detail: 'BBC media stream is available',
      );
    }
    if (isUk == 'no') {
      return _result(
        target,
        raw,
        StreamingTestStatus.restricted,
        bbcRegion,
        detail: 'BBC classified the exit IP as outside the UK',
      );
    }
    if (_statusCode(mediaRaw) == 403) {
      return _result(
        target,
        raw,
        StreamingTestStatus.blocked,
        bbcRegion,
        detail: 'BBC rejected the exit IP',
      );
    }
    if (isUk == 'yes') {
      return _result(
        target,
        raw,
        StreamingTestStatus.accessible,
        bbcRegion ?? 'GB',
        detail: 'BBC classified the exit IP as a UK connection',
      );
    }
    final mediaFailure = _failure(target, mediaRaw, bbcRegion);
    if (mediaFailure != null) return mediaFailure;
    final userInfoFailure = _failure(target, userInfoRaw, region);
    if (userInfoFailure != null) return userInfoFailure;
    return _result(
      target,
      raw,
      StreamingTestStatus.uncertain,
      bbcRegion,
      detail: 'BBC media and location APIs returned an inconclusive response',
    );
  }

  Future<StreamingTestResult> _testDazn(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final raw = await _probe(
      proxyName,
      'https://startup.core.indazn.com/misl/v5/Startup',
      method: 'POST',
      body: jsonEncode({
        'Version': '2',
        'LandingPageKey': 'generic',
        'Languages': 'zh-CN',
        'Platform': 'web',
        'Manufacturer': '',
        'PromoCode': '',
        'PlatformAttributes': <String, dynamic>{},
      }),
      headers: const {
        'Content-Type': 'application/json',
        'Origin': 'https://www.dazn.com',
        'Referer': 'https://www.dazn.com/',
      },
      timeout: const Duration(seconds: 12),
      retryTransient: true,
    );
    final failure = _failure(target, raw, region);
    if (failure != null) return failure;
    final body = _body(raw);
    final decoded = _decodeJson(body);
    final serviceRegion =
        _jsonValue(decoded, 'GeolocatedCountry')?.toString().toUpperCase();
    if (body.toLowerCase().contains('security policy has been breached') ||
        _statusCode(raw) == 403) {
      return _result(
        target,
        raw,
        StreamingTestStatus.blocked,
        serviceRegion,
        detail: 'DAZN rejected the exit IP',
      );
    }
    final allowed = _jsonValue(decoded, 'isAllowed');
    final reason = _jsonValue(decoded, 'DisallowedReason')?.toString();
    if (allowed == true) {
      return _result(
        target,
        raw,
        StreamingTestStatus.accessible,
        serviceRegion,
        detail: 'DAZN startup API allowed playback',
      );
    }
    if (allowed == false) {
      return _result(
        target,
        raw,
        StreamingTestStatus.restricted,
        serviceRegion,
        detail: reason?.isNotEmpty == true ? reason : 'DAZN region denied',
      );
    }
    return _result(
      target,
      raw,
      StreamingTestStatus.uncertain,
      serviceRegion,
      detail: 'DAZN startup API returned an unknown response',
    );
  }

  Future<StreamingTestResult> _testNetflix(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final responses = await Future.wait([
      _probe(proxyName, 'https://www.netflix.com/title/81280792'),
      _probe(proxyName, 'https://www.netflix.com/title/70143836'),
    ]);
    for (final raw in responses) {
      final failure = _failure(target, raw, region);
      if (failure != null) return failure;
    }
    final raw = _mergeResponses(responses);
    final codes = responses.map(_statusCode).toList();
    final bodies = responses.map(_body).map((body) => body.toLowerCase());
    if (codes.every((code) => code == 403)) {
      return _result(
        target,
        raw,
        StreamingTestStatus.blocked,
        region,
        detail: 'Netflix rejected the exit IP',
      );
    }
    if (codes.every((code) => code == 404) ||
        bodies.every((body) => body.contains('oh no!'))) {
      return _result(
        target,
        raw,
        StreamingTestStatus.partiallyAccessible,
        region,
        detail: 'Netflix Originals only',
      );
    }
    if (codes.any((code) => code >= 200 && code < 400)) {
      return _result(
        target,
        raw,
        StreamingTestStatus.accessible,
        region,
        detail: 'Netflix regional titles are available',
      );
    }
    return _result(
      target,
      raw,
      StreamingTestStatus.uncertain,
      region,
      detail: 'Netflix title checks were inconclusive',
    );
  }

  Future<StreamingTestResult> _testYoutube(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final raw = await _probe(
      proxyName,
      target.url,
      headers: const {'Accept-Language': 'en-US,en;q=0.9'},
      timeout: const Duration(seconds: 16),
      maxBodySize: 1024 * 1024,
      retryTransient: true,
    );
    final failure = _failure(target, raw, region);
    if (failure != null) return failure;
    final body = _body(raw);
    final lower = body.toLowerCase();
    final serviceRegion = RegExp(
      r'"(?:INNERTUBE_CONTEXT_GL|countryCode)"\s*:\s*"([A-Za-z]{2})"',
    ).firstMatch(body)?.group(1)?.toUpperCase();
    if (lower.contains('premium is not available in your country') ||
        lower.contains('www.google.cn')) {
      return _result(
        target,
        raw,
        StreamingTestStatus.restricted,
        serviceRegion,
        detail: 'YouTube Premium is unavailable in this region',
      );
    }
    if (lower.contains('premiumpurchasebutton') ||
        lower.contains('managesubscriptionbutton') ||
        lower.contains('ad-free') ||
        lower.contains('/month')) {
      return _result(
        target,
        raw,
        StreamingTestStatus.accessible,
        serviceRegion,
        detail: 'YouTube Premium offer is available',
      );
    }
    return _result(
      target,
      raw,
      StreamingTestStatus.uncertain,
      serviceRegion,
      detail: 'YouTube Premium response was inconclusive',
    );
  }

  Future<StreamingTestResult> _testPrimeVideo(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final raw = await _probe(
      proxyName,
      target.url,
      timeout: const Duration(seconds: 18),
      maxBodySize: 1536 * 1024,
      retryTransient: true,
    );
    final failure = _failure(target, raw, region);
    if (failure != null) return failure;
    final body = _body(raw);
    final serviceRegion = RegExp(
      r'"currentTerritory"\s*:\s*"([A-Za-z]{2})"',
    ).firstMatch(body)?.group(1)?.toUpperCase();
    final restricted = RegExp(
      r'"isServiceRestricted"\s*:\s*true',
      caseSensitive: false,
    ).hasMatch(body);
    if (restricted) {
      return _result(
        target,
        raw,
        StreamingTestStatus.restricted,
        serviceRegion,
        detail: 'Prime Video reported service restriction',
      );
    }
    if (serviceRegion != null) {
      return _result(
        target,
        raw,
        StreamingTestStatus.accessible,
        serviceRegion,
        detail: 'Prime Video territory detected',
      );
    }
    return _result(
      target,
      raw,
      StreamingTestStatus.uncertain,
      null,
      detail: 'Prime Video territory was not found',
    );
  }

  Future<StreamingTestResult> _testChatGpt(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final raw = await _probe(
      proxyName,
      'https://api.openai.com/compliance/cookie_requirements',
      headers: const {
        'Authorization': 'Bearer null',
        'Origin': 'https://platform.openai.com',
        'Referer': 'https://platform.openai.com/',
        'Accept': 'application/json',
      },
    );
    final failure = _failure(target, raw, region);
    if (failure != null) return failure;
    final body = _body(raw).toLowerCase();
    if (body.contains('unsupported_country')) {
      return _result(
        target,
        raw,
        StreamingTestStatus.restricted,
        region,
        detail: 'OpenAI compliance API reported unsupported country',
      );
    }
    if (isCloudflareChallenge(raw)) {
      return _result(
        target,
        raw,
        StreamingTestStatus.verificationRequired,
        null,
        detail: 'Cloudflare browser verification required',
      );
    }
    if (_statusCode(raw) == 200 && body.contains('cookie_consent_required')) {
      return _result(
        target,
        raw,
        StreamingTestStatus.accessible,
        region,
        detail: 'OpenAI compliance API is available',
      );
    }
    return _result(
      target,
      raw,
      StreamingTestStatus.uncertain,
      null,
      detail: 'OpenAI compliance response was inconclusive',
    );
  }

  Future<StreamingTestResult> _testClaude(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final raw = await _probe(
      proxyName,
      'https://api.anthropic.com/v1/messages',
      method: 'POST',
      body: jsonEncode({
        'model': 'claude-sonnet-4-5',
        'max_tokens': 1,
        'messages': [
          {'role': 'user', 'content': 'test'},
        ],
      }),
      headers: const {
        'Content-Type': 'application/json',
        'Anthropic-Version': '2023-06-01',
        'Accept': 'application/json',
      },
    );
    final failure = _failure(target, raw, region);
    if (failure != null) return failure;
    final body = _body(raw).toLowerCase();
    if (_containsRegionRestriction(body)) {
      return _result(
        target,
        raw,
        StreamingTestStatus.restricted,
        region,
        detail: 'Anthropic API reported region restriction',
      );
    }
    if (isCloudflareChallenge(raw)) {
      return _result(
        target,
        raw,
        StreamingTestStatus.verificationRequired,
        region,
        detail: 'Cloudflare browser verification required',
      );
    }
    if (_statusCode(raw) == 401 &&
        body.contains('x-api-key header is required')) {
      return _result(
        target,
        raw,
        StreamingTestStatus.accessible,
        region,
        detail: 'Anthropic API is reachable in this region',
      );
    }
    return _result(
      target,
      raw,
      StreamingTestStatus.uncertain,
      region,
      detail: 'Anthropic API response was inconclusive',
    );
  }

  Future<StreamingTestResult> _testMax(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final raw = await _probe(proxyName, target.url);
    final failure = _failure(target, raw, region);
    if (failure != null) return failure;
    final body = _body(raw);
    final finalUrl = raw['final-url']?.toString().toLowerCase() ?? '';
    final serviceRegion = RegExp(
      r'countryCode=([A-Z]{2})',
    ).firstMatch(body)?.group(1);
    if (finalUrl.contains('geo-availability') ||
        body.toLowerCase().contains('not available in your region')) {
      return _result(
        target,
        raw,
        StreamingTestStatus.restricted,
        serviceRegion,
        detail: 'Max reported region restriction',
      );
    }
    return _result(
      target,
      raw,
      classifyStatusCode(_statusCode(raw)),
      serviceRegion,
      detail: 'Max public service response',
    );
  }

  Future<StreamingTestResult> _testDisney(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final raw = await _probe(proxyName, target.url);
    final failure = _failure(target, raw, region);
    if (failure != null) return failure;
    final finalUrl = raw['final-url']?.toString().toLowerCase() ?? '';
    final body = _body(raw).toLowerCase();
    if (finalUrl.contains('unavailable') ||
        body.contains('not available in your region')) {
      return _result(
        target,
        raw,
        StreamingTestStatus.restricted,
        region,
        detail: 'Disney+ reported region restriction',
      );
    }
    return _genericResult(target, raw, region);
  }

  Future<StreamingTestResult> _testGemini(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final raw = await _probe(proxyName, target.url);
    final failure = _failure(target, raw, region);
    if (failure != null) return failure;
    final body = _body(raw);
    final lower = body.toLowerCase();
    if (_containsRegionRestriction(lower)) {
      return _result(
        target,
        raw,
        StreamingTestStatus.restricted,
        region,
        detail: 'Gemini reported region restriction',
      );
    }
    if (body.contains('45631641,null,true')) {
      return _result(
        target,
        raw,
        StreamingTestStatus.accessible,
        region,
        detail: 'Gemini availability flag detected',
      );
    }
    return _genericResult(target, raw, region);
  }

  Future<StreamingTestResult> _testCrunchyroll(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final responses = await Future.wait([
      _probe(proxyName, 'https://c.evidon.com/geo/country.js'),
      _probe(proxyName, target.url),
    ]);
    for (final raw in responses) {
      final failure = _failure(target, raw, region);
      if (failure != null) return failure;
    }
    final geoRaw = responses.first;
    final pageRaw = responses.last;
    final merged = _mergeResponses(responses);
    if (isCloudflareChallenge(pageRaw)) {
      return _result(
        target,
        merged,
        StreamingTestStatus.verificationRequired,
        null,
        detail: 'Browser verification required',
      );
    }
    final serviceRegion = RegExp(
      r"'code'\s*:\s*'([a-z]{2})'",
      caseSensitive: false,
    ).firstMatch(_body(geoRaw))?.group(1)?.toUpperCase();
    final pageCode = _statusCode(pageRaw);
    if (serviceRegion != null && pageCode >= 200 && pageCode < 400) {
      return _result(
        target,
        merged,
        StreamingTestStatus.accessible,
        serviceRegion,
        detail: 'Crunchyroll page and service region are available',
      );
    }
    return _result(
      target,
      merged,
      StreamingTestStatus.uncertain,
      serviceRegion,
      detail: 'Crunchyroll response was inconclusive',
    );
  }

  Future<StreamingTestResult> _testTikTok(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final raw = await _probe(proxyName, target.url);
    final failure = _failure(target, raw, region);
    if (failure != null) return failure;
    if (isCloudflareChallenge(raw)) {
      return _result(
        target,
        raw,
        StreamingTestStatus.verificationRequired,
        null,
        detail: 'Browser verification required',
      );
    }
    final body = _body(raw);
    final lower = body.toLowerCase();
    final regions = RegExp(
      r'"region"\s*:\s*"([A-Za-z]+)"',
    ).allMatches(body).map((match) => match.group(1)).whereType<String>();
    String? serviceRegion;
    for (final candidate in regions) {
      if (candidate.length == 2) {
        serviceRegion = candidate.toUpperCase();
        break;
      }
    }
    if (lower.contains('tiktok.com/hk/notfound')) {
      return _result(
        target,
        raw,
        StreamingTestStatus.restricted,
        serviceRegion ?? 'HK',
        detail: 'TikTok redirected to a regional not-found page',
      );
    }
    if (serviceRegion != null &&
        _statusCode(raw) >= 200 &&
        _statusCode(raw) < 400) {
      return _result(
        target,
        raw,
        StreamingTestStatus.accessible,
        serviceRegion,
        detail: 'TikTok region detected',
      );
    }
    return _result(
      target,
      raw,
      StreamingTestStatus.uncertain,
      null,
      detail: 'TikTok region was not found',
    );
  }

  Future<StreamingTestResult> _testProtectedAi(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final raw = await _probe(proxyName, target.url);
    final failure = _failure(target, raw, region);
    if (failure != null) return failure;
    final body = _body(raw);
    if (_containsRegionRestriction(body)) {
      return _result(
        target,
        raw,
        StreamingTestStatus.restricted,
        region,
        detail: '${target.name} reported region restriction',
      );
    }
    if (isCloudflareChallenge(raw)) {
      return _result(
        target,
        raw,
        StreamingTestStatus.verificationRequired,
        region,
        detail: 'Cloudflare browser verification required',
      );
    }
    if (_statusCode(raw) >= 200 &&
        _statusCode(raw) < 400 &&
        body.toLowerCase().contains(target.id)) {
      return _result(
        target,
        raw,
        StreamingTestStatus.accessible,
        region,
        detail: '${target.name} application page is available',
      );
    }
    return _result(
      target,
      raw,
      StreamingTestStatus.uncertain,
      region,
      detail: '${target.name} response was inconclusive',
    );
  }

  Future<StreamingTestResult> _testGoogleAiStudio(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final raw = await _probe(proxyName, target.url);
    final failure = _failure(target, raw, region);
    if (failure != null) return failure;
    final body = _body(raw);
    if (_containsRegionRestriction(body)) {
      return _result(
        target,
        raw,
        StreamingTestStatus.restricted,
        region,
        detail: 'Google AI Studio reported region restriction',
      );
    }
    if (_statusCode(raw) >= 200 &&
        _statusCode(raw) < 400 &&
        body.toLowerCase().contains('google ai studio')) {
      return _result(
        target,
        raw,
        StreamingTestStatus.accessible,
        region,
        detail: 'Google AI Studio welcome application is available',
      );
    }
    return _result(
      target,
      raw,
      StreamingTestStatus.uncertain,
      region,
      detail: 'Google AI Studio response was inconclusive',
    );
  }

  Future<StreamingTestResult> _testGeneric(
    StreamingTarget target,
    String proxyName,
    String? region,
  ) async {
    final raw = await _probe(proxyName, target.url);
    final failure = _failure(target, raw, region);
    if (failure != null) return failure;
    return _genericResult(target, raw, region);
  }

  StreamingTestResult _genericResult(
    StreamingTarget target,
    Map<String, dynamic> raw,
    String? region,
  ) {
    if (isCloudflareChallenge(raw)) {
      return _result(
        target,
        raw,
        StreamingTestStatus.verificationRequired,
        region,
        detail: 'Cloudflare browser verification required',
      );
    }
    return _result(
      target,
      raw,
      classifyStatusCode(_statusCode(raw)),
      region,
      detail: raw['final-url']?.toString(),
    );
  }

  Future<Map<String, dynamic>> _probe(
    String proxyName,
    String url, {
    String method = 'GET',
    String? body,
    Map<String, String> headers = const {},
    bool followRedirects = true,
    Duration timeout = const Duration(seconds: 8),
    int maxBodySize = 256 * 1024,
    bool retryTransient = false,
  }) async {
    Future<Map<String, dynamic>> run() => clashCore.streamingProbe(
          url,
          proxyName,
          method: method,
          body: body,
          headers: headers,
          followRedirects: followRedirects,
          timeout: timeout,
          maxBodySize: maxBodySize,
        );

    var result = await run();
    if (retryTransient && _isTransientProbeFailure(result)) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      result = await run();
    }
    return result;
  }

  static bool _isTransientProbeFailure(Map<String, dynamic> raw) {
    if (raw['ok'] == true) return false;
    final error = (raw['error']?.toString() ?? '').toLowerCase();
    return error.contains('timeout') ||
        error.contains('deadline') ||
        error.contains('ws closed') ||
        error.contains('connection reset') ||
        error.contains('broken pipe') ||
        error.contains('eof') ||
        error.contains('tls') ||
        error.contains('ssl');
  }

  StreamingTestResult? _failure(
    StreamingTarget target,
    Map<String, dynamic> raw,
    String? region,
  ) {
    if (raw['ok'] == true) return null;
    final error = raw['error']?.toString() ?? '';
    final timeout = error.toLowerCase().contains('timeout') ||
        error.toLowerCase().contains('deadline');
    return _result(
      target,
      raw,
      timeout ? StreamingTestStatus.timeout : StreamingTestStatus.error,
      null,
      detail: error,
    );
  }

  StreamingTestResult _result(
    StreamingTarget target,
    Map<String, dynamic> raw,
    StreamingTestStatus status,
    String? region, {
    String? detail,
  }) {
    final statusCode = _statusCode(raw);
    return StreamingTestResult(
      target: target,
      status: status,
      elapsedMs: (raw['elapsed-ms'] as num?)?.toInt() ?? 0,
      region: region,
      statusCode: statusCode > 0 ? statusCode : null,
      detail: detail,
    );
  }

  static int _statusCode(Map<String, dynamic> raw) {
    return (raw['status-code'] as num?)?.toInt() ?? 0;
  }

  static String _body(Map<String, dynamic> raw) {
    return raw['body']?.toString() ?? '';
  }

  static dynamic _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static dynamic _jsonValue(dynamic value, String key) {
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key.toString().toLowerCase() == key.toLowerCase()) {
          return entry.value;
        }
        final nested = _jsonValue(entry.value, key);
        if (nested != null) return nested;
      }
    } else if (value is List) {
      for (final item in value) {
        final nested = _jsonValue(item, key);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  static bool _containsRegionRestriction(String body) {
    final lower = body.toLowerCase();
    return lower.contains('unsupported_country') ||
        lower.contains('not available in your country') ||
        lower.contains('not available in your region') ||
        lower.contains('app-unavailable-in-region');
  }

  static bool isCloudflareChallenge(Map<String, dynamic> raw) {
    final headers = raw['headers'];
    var server = '';
    var mitigated = '';
    if (headers is Map) {
      for (final entry in headers.entries) {
        final key = entry.key.toString().toLowerCase();
        if (key == 'server') server = entry.value.toString().toLowerCase();
        if (key == 'cf-mitigated') {
          mitigated = entry.value.toString().toLowerCase();
        }
      }
    }
    final body = _body(raw).toLowerCase();
    return mitigated.contains('challenge') ||
        body.contains('cf-chl-') ||
        body.contains('just a moment') ||
        (_statusCode(raw) == 403 &&
            server.contains('cloudflare') &&
            body.contains('cloudflare'));
  }

  static Map<String, dynamic> _mergeResponses(
    List<Map<String, dynamic>> responses,
  ) {
    final merged = Map<String, dynamic>.from(responses.first);
    merged['elapsed-ms'] = responses.fold<int>(0, (current, raw) {
      final elapsed = (raw['elapsed-ms'] as num?)?.toInt() ?? 0;
      return elapsed > current ? elapsed : current;
    });
    merged['body'] = responses.map(_body).join('\n');
    return merged;
  }
}

const streamingCheckService = StreamingCheckService();
