import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';
import 'notice_cache.dart';

Future<List<String>>? _sources;
Future<List<String>> noticeSourceIdentity() => _sources ??= () async {
      final root =
          loadYaml(await rootBundle.loadString('assets/config/config.yaml'));
      final values = root['remote_config']?['sources'] as List? ?? const [];
      return values.map((s) => s['url'] as String).toList();
    }();

class NoticeBootstrap {
  const NoticeBootstrap(
      {required this.scope,
      required this.email,
      required this.locale,
      required this.record,
      required this.dismissed,
      required this.shown,
      this.legacyScope});
  final String scope;
  final String email;
  final String locale;
  final String? legacyScope;
  final NoticeCacheRecord record;
  final Set<int> dismissed;
  final Set<int> shown;
}

final initialNoticeBootstrapProvider = Provider<NoticeBootstrap?>((_) => null);

Future<NoticeBootstrap?> loadNoticeBootstrap(
    {required SharedPreferences prefs,
    required String? email,
    required String locale,
    String? legacyScope}) async {
  if (email == null || email.isEmpty) return null;
  try {
    final scope = noticeCacheScope(
        sources: await noticeSourceIdentity(), email: email, locale: locale);
    final raw = prefs.getString('xboard_notice_cache_v1:$scope') ??
        prefs.getString('xboard_notice_cache_v1:$legacyScope');
    if (raw == null) return null;
    Set<int> ids(String prefix) => (prefs.getStringList('$prefix:$scope') ??
            prefs.getStringList('$prefix:$legacyScope') ??
            [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    return NoticeBootstrap(
        scope: scope,
        email: email.trim().toLowerCase(),
        locale: locale,
        legacyScope: legacyScope,
        record: NoticeCacheRecord.decode(raw, DateTime.now()),
        dismissed: ids('xboard_dismissed_notice_ids'),
        shown: ids('xboard_popup_shown_notice_ids'));
  } catch (_) {
    return null;
  }
}
