import 'package:fl_clash/xboard/features/update_check/models/update_check_state.dart';
import 'package:fl_clash/xboard/features/update_check/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester tester, bool force) async {
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => showDialog<void>(
                            context: context,
                            barrierDismissible: !force,
                            builder: (_) => UpdateDialog(
                                state: UpdateCheckState(
                                    hasUpdate: true,
                                    forceUpdate: force,
                                    currentVersion: '3.6.2',
                                    latestVersion: '3.6.3',
                                    releaseNotes: 'Fixes'))),
                        child: const Text('Show')))))));
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
  }

  testWidgets('optional update offers cancel and update', (tester) async {
    await open(tester, false);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateDialog), findsNothing);
  });
  testWidgets('forced update has only update and blocks back', (tester) async {
    await open(tester, true);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Update'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(UpdateDialog), findsOneWidget);
  });
}
