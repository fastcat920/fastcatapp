import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/settings/pages/fastcat_custom_routing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ProfileId extends CurrentProfileId {
  @override
  String? build() => 'test-profile';
}

final _refreshProvider = StateProvider<int>((ref) => 0);

void main() {
  testWidgets('typing keeps focus and selection during background updates',
      (tester) async {
    final container = ProviderContainer(overrides: [
      currentProfileIdProvider.overrideWith(_ProfileId.new),
      currentProfileProvider.overrideWith((ref) {
        final tick = ref.watch(_refreshProvider);
        return Profile(
          id: 'test-profile',
          autoUpdateDuration: const Duration(hours: 1),
          lastUpdateDate: DateTime(2026, 1, 1, 0, 0, tick),
        );
      }),
      currentGroupsStateProvider.overrideWith((ref) {
        final tick = ref.watch(_refreshProvider);
        return GroupsState(value: [
          Group(name: 'Proxy', type: GroupType.Selector, now: 'node-$tick'),
        ]);
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: FastCatCustomRoutingPage()),
    ));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    const input = 'example.com';
    for (var i = 1; i <= input.length; i++) {
      final value = TextEditingValue(
        text: input.substring(0, i),
        selection: TextSelection.collapsed(offset: i),
      );
      tester.testTextInput.updateEditingValue(value);
      container.read(_refreshProvider.notifier).state++;
      await tester.pump();
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(editable.widget.controller.value, value);
      expect(tester.state(find.byType(EditableText)), same(editable));
    }
  });
}
