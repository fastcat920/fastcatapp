import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

/// Keep the live core state separate from remembered/display-only selections.
class ProxySelectionSync {
  ProxySelectionSync({
    required this.readGroups,
    required this.writeSelection,
    required this.publishGroups,
    this.timeout = const Duration(seconds: 5),
  });

  final Future<List<Group>> Function() readGroups;
  final Future<String> Function(String group, String node) writeSelection;
  final void Function(List<Group>) publishGroups;
  final Duration timeout;
  Future<void> _pending = Future.value();

  Future<void> _serialize(Future<void> Function() action) {
    final operation = _pending.then((_) => action());
    _pending =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Future<List<Group>> _read() async {
    final groups = await readGroups().timeout(timeout);
    if (groups.isEmpty) throw StateError('Core proxy groups unavailable');
    publishGroups(groups);
    return groups;
  }

  Future<void> _select(String group, String node) async {
    final error = await writeSelection(group, node).timeout(timeout);
    // Read back even on rejection: never leave optimistic UI state as truth.
    final actual = await _read();
    if (error.isNotEmpty || actual.getGroup(group)?.now != node) {
      throw StateError('Core proxy selection was not applied');
    }
  }

  Future<void> select(String group, String node) =>
      _serialize(() => _select(group, node));

  Future<void> synchronize({
    required Map<String, String> saved,
    required String? activeGroup,
  }) =>
      _serialize(() async {
        var groups = await _read();
        // Restore explicit choices, including nested selector groups. Never
        // pick another working node in response to a latency-test failure.
        for (final entry in saved.entries) {
          final group = groups.getGroup(entry.key);
          if (group?.type != GroupType.Selector ||
              !group!.all.any((node) => node.name == entry.value)) {
            continue;
          }
          if (group.now != entry.value) {
            await _select(entry.key, entry.value);
            groups = await _read();
          }
        }
        final group = groups.getGroup(activeGroup ?? '');
        if (group?.type != GroupType.Selector) return;
        final valid = group!.all.where((node) =>
            node.name != 'DIRECT' &&
            node.name != 'REJECT' &&
            node.name != 'COMPATIBLE' &&
            node.name != group.name);
        if (valid.any((node) => node.name == group.now)) return;
        if (valid.isEmpty) {
          throw StateError('No selectable proxy in active group');
        }
        final computed = valid.where((node) => groups.any((candidate) =>
            candidate.name == node.name && candidate.type.isComputedSelected));
        await _select(group.name, (computed.firstOrNull ?? valid.first).name);
      });
}
