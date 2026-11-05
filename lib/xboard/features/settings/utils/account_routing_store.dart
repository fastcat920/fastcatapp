import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_clash/models/models.dart';

class AccountRoutingStore {
  static String _key(String id) =>
      'account_routing_v1:${Uri.encodeComponent(id)}';
  static Future<void> save(String id, List<Rule> rules) async {
    if (id.isEmpty) throw StateError('Account identity unavailable');
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setStringList(
        _key(id), rules.map((rule) => rule.value).toList())) {
      throw StateError('Cannot save routing rules');
    }
  }

  static Future<List<Rule>?> load(String id) async {
    if (id.isEmpty) return null;
    final values =
        (await SharedPreferences.getInstance()).getStringList(_key(id));
    return values?.map(Rule.value).toList();
  }
}
