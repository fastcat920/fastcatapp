List<Map<String, dynamic>> parseResponseMapList(
  dynamic response, {
  List<String> listKeys = const [
    'data',
    'items',
    'list',
    'records',
    'orders',
    'plans',
    'tickets',
    'notices',
    'payment_methods',
    'methods',
    'details',
  ],
}) {
  final raw = _extractRawList(response, listKeys);
  return raw
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

List<dynamic> _extractRawList(dynamic value, List<String> listKeys) {
  if (value is List) return value;
  if (value is! Map) return const [];

  for (final key in listKeys) {
    final child = value[key];
    if (child is List) return child;
  }

  final data = value['data'];
  if (data is List) return data;
  if (data is Map) {
    final nested = _extractRawList(data, listKeys);
    if (nested.isNotEmpty) return nested;
  }

  return value.values.whereType<List>().expand((list) => list).toList();
}
