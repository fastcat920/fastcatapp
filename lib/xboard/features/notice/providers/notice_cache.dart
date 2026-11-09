import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:fl_clash/xboard/domain/models/notice.dart';

String noticeCacheScope(
    {required List<String> sources,
    required String email,
    required String locale}) {
  final ordered = sources.toList()..sort();
  final identity = jsonEncode([ordered, email.trim().toLowerCase()]);
  return '${sha256.convert(utf8.encode(identity)).toString().substring(0, 24)}:$locale';
}

class NoticeCacheRecord {
  const NoticeCacheRecord(this.notices, this.savedAt);
  final List<DomainNotice> notices;
  final DateTime? savedAt;

  static NoticeCacheRecord decode(String raw, DateTime now) {
    final value = jsonDecode(raw);
    final items = value is Map ? value['items'] : value;
    if (items is! List) throw const FormatException('Invalid notice cache');
    DateTime? savedAt;
    if (value is Map && value['savedAt'] is int) {
      final time = DateTime.fromMillisecondsSinceEpoch(value['savedAt'] as int);
      if (!time.isAfter(now)) savedAt = time;
    }
    return NoticeCacheRecord(
        items
            .map((item) =>
                DomainNotice.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        savedAt);
  }

  String encode() => jsonEncode({
        'savedAt': savedAt?.millisecondsSinceEpoch,
        'items': notices.map((n) => n.toJson()).toList()
      });
}
