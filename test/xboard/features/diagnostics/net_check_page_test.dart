import 'package:fl_clash/common/common.dart' show system;
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/diagnostics/pages/net_check_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Disconnected extends RunTime {
  @override
  int? build() => null;
}

void main() {
  tearDown(() => system.setTVForTesting(false));

  Future<void> openDiagnostics(WidgetTester tester, {required bool tv}) async {
    system.setTVForTesting(tv);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        runTimeProvider.overrideWith(_Disconnected.new),
        currentGroupsStateProvider
            .overrideWith((ref) => GroupsState(value: [])),
        currentProfileProvider.overrideWith((ref) => null),
      ],
      child: const MaterialApp(
        localizationsDelegates: [AppLocalizations.delegate],
        home: Scaffold(body: NetCheckPage()),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('non-TV clients show the download traffic note without a switch',
      (tester) async {
    await openDiagnostics(tester, tv: false);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.textContaining('may use up to 100 MB of data'), findsOneWidget);
  });

  testWidgets('TV diagnostics omit download speed testing', (tester) async {
    await openDiagnostics(tester, tv: true);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Download speed test'), findsNothing);
    expect(find.textContaining('may use up to 100 MB of data'), findsNothing);
  });
}
