/// A process-local lease over exactly the settings this instance changed.
///
/// A pre-existing localhost proxy is not evidence of ownership. No disk marker
/// is adopted after a crash: only successful writes observed in this process
/// may be restored. Callers serialize apply/restore operations.
class ProxyConfigurationLease {
  ProxyConfigurationLease({
    required this.read,
    required this.write,
    this.groups = const [],
  });

  final Future<Map<String, String>?> Function() read;
  final Future<bool> Function(Map<String, String>) write;

  /// Settings such as a proxy endpoint and its enabled flag must travel
  /// together. If another app changes the endpoint, do not disable its flag.
  final List<Set<String>> groups;
  final Map<String, _OwnedSetting> _owned = {};

  bool get isEmpty => _owned.isEmpty;

  Future<Map<String, String>?> _read() async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _write(Map<String, String> values) async {
    try {
      return await write(values);
    } catch (_) {
      // A failed command may still have partially written settings. Always
      // read back and restore only properties whose intended value was seen.
      return false;
    }
  }

  Future<bool> apply(Map<String, String> desired) async {
    final before = await _read();
    if (before == null || desired.keys.any((key) => !before.containsKey(key))) {
      return false;
    }
    _releaseChanged(before);
    final previous = Map<String, _OwnedSetting>.of(_owned);
    final changes = <String, String>{
      for (final entry in desired.entries)
        if (before[entry.key] != entry.value) entry.key: entry.value,
    };
    if (changes.isEmpty) return true;
    final written = await _write(changes);
    final after = await _read();
    // Retain pending claims for retry if readback is unavailable. A later
    // restore still has to compare the exact intended value before writing.
    for (final entry in changes.entries) {
      if (after == null || after[entry.key] == entry.value) {
        _owned[entry.key] = _OwnedSetting(
          previous[entry.key]?.original ?? before[entry.key]!,
          entry.value,
        );
      }
    }
    if (after == null) _refreshGuards({...before, ...desired});
    if (written &&
        after != null &&
        desired.entries.every((entry) => after[entry.key] == entry.value)) {
      _refreshGuards(after);
      return true;
    }

    // Failed refreshes roll back to the working state before this attempt,
    // not all the way back to the pre-connection user configuration.
    if (after != null) {
      final rollback = <String, String>{
        for (final entry in changes.entries)
          if (after[entry.key] == entry.value) entry.key: before[entry.key]!,
      };
      if (rollback.isNotEmpty) await _write(rollback);
      final rolledBack = await _read();
      if (rolledBack != null) {
        for (final entry in changes.entries) {
          final value = rolledBack[entry.key];
          if (value == before[entry.key]) {
            final old = previous[entry.key];
            if (old == null) {
              _owned.remove(entry.key);
            } else {
              _owned[entry.key] = old;
            }
          } else if (value != entry.value) {
            _owned.remove(entry.key);
          }
        }
        _refreshGuards(rolledBack);
      }
    }
    return false;
  }

  Future<bool> restore() async {
    if (_owned.isEmpty) return true;
    final current = await _read();
    if (current == null) return false;
    if (_owned.keys.any((key) => !current.containsKey(key))) return false;
    _releaseChanged(current);
    if (_owned.isEmpty) return true;
    final restoreValues = {
      for (final entry in _owned.entries) entry.key: entry.value.original,
    };
    final written = await _write(restoreValues);
    final restored = await _read();
    if (restored == null) return false;
    for (final entry in restoreValues.entries) {
      if (restored[entry.key] == entry.value) _owned.remove(entry.key);
    }
    _refreshGuards(restored);
    return written && _owned.isEmpty;
  }

  void _releaseChanged(Map<String, String> current) {
    _owned.removeWhere((key, value) =>
        (current.containsKey(key) && current[key] != value.applied) ||
        value.guards.entries.any((entry) =>
            current.containsKey(entry.key) &&
            current[entry.key] != entry.value));
  }

  void _refreshGuards(Map<String, String> values) {
    for (final entry in _owned.entries.toList()) {
      _owned[entry.key] = _OwnedSetting(
        entry.value.original,
        entry.value.applied,
        {
          for (final group
              in groups.where((group) => group.contains(entry.key)))
            for (final key in group)
              if (values.containsKey(key)) key: values[key]!,
        },
      );
    }
  }
}

class _OwnedSetting {
  const _OwnedSetting(this.original, this.applied, [this.guards = const {}]);
  final String original;
  final String applied;
  final Map<String, String> guards;
}
