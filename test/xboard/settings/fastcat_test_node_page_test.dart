import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/settings/pages/fastcat_test_node_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyProfiles extends Profiles {
  @override
  List<Profile> build() => [];
}

class _EmptyCurrent extends CurrentProfileId {
  @override
  String? build() => null;
}

void main() {
  testWidgets(
      'prefills the verified endpoint and rejects an empty secret without switching profiles',
      (tester) async {
    final container = ProviderContainer(overrides: [
      profilesProvider.overrideWith(_EmptyProfiles.new),
      currentProfileIdProvider.overrideWith(_EmptyCurrent.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FastCatTestNodePage())));
    await tester.pumpAndSettle();
    expect(find.text('zlhk.fastcat.ink'), findsOneWidget);
    expect(find.text('8443'), findsOneWidget);
    final fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(
        tester.widgetList<TextField>(find.byType(TextField)).last.obscureText,
        isTrue);
    expect(fields.last.controller!.text, isEmpty);
    await tester.ensureVisible(find.text('Save node'));
    await tester.tap(find.text('Save node'));
    await tester.pumpAndSettle();
    expect(
        find.text('Use at least 24 characters without spaces'), findsOneWidget);
    expect(container.read(currentProfileIdProvider), isNull);
    expect(container.read(profilesProvider), isEmpty);
  });

  testWidgets(
      'switching to HTTP/2 selects its own port and starts with a blank token',
      (tester) async {
    final container = ProviderContainer(overrides: [
      profilesProvider.overrideWith(_EmptyProfiles.new),
      currentProfileIdProvider.overrideWith(_EmptyCurrent.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FastCatTestNodePage())));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).last, 'dummy-v1-token-for-this-widget-test');
    await tester.tap(find.text('HTTP/2'));
    await tester.pumpAndSettle();
    expect(find.text('18444'), findsOneWidget);
    final token = tester.widgetList<TextField>(find.byType(TextField)).last;
    expect(token.controller!.text, isEmpty);
    expect(token.obscureText, isTrue);
    expect(find.text('Enter the HTTP/2 server token'), findsOneWidget);
    expect(container.read(currentProfileIdProvider), isNull);
  },
      variant: TargetPlatformVariant(
          <TargetPlatform>{TargetPlatform.android, TargetPlatform.iOS}));
}
