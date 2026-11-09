import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/common/cached_cupertino_page.dart';

const _theme = PageTransitionsTheme(
    builders: {TargetPlatform.iOS: CupertinoPageTransitionsBuilder()});
Future<void> _size(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _swipe(WidgetTester tester, Offset from, Offset delta) async {
  final gesture = await tester.startGesture(from);
  for (var i = 0; i < 5; i++) {
    await gesture.moveBy(delta / 5);
    await tester.pump(const Duration(milliseconds: 40));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester,
    {bool cupertino = false, bool protected = false}) async {
  await _size(tester);
  Widget detail(BuildContext _) => PopScope(
      canPop: !protected,
      child: Scaffold(
          body: ListView(
              children: List.generate(80,
                  (i) => SizedBox(height: 60, child: Text('article $i'))))));
  await tester.pumpWidget(MaterialApp(
      theme:
          ThemeData(platform: TargetPlatform.iOS, pageTransitionsTheme: _theme),
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => Navigator.of(context).push(cupertino
                      ? CupertinoPageRoute<void>(builder: detail)
                      : MaterialPageRoute<void>(builder: detail)),
                  child: const Text('open'))))));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('vertical reading at the left edge wins before standard back',
      (tester) async {
    await _open(tester, cupertino: true);
    await _swipe(tester, const Offset(5, 550), const Offset(16, -260));
    expect(find.text('open'), findsNothing);
    expect(find.text('article 0'), findsNothing);
    await _swipe(tester, const Offset(5, 300), const Offset(270, 0));
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('reopening during the pop animation restores the same chat',
      (tester) async {
    await _size(tester);
    final key = GlobalKey<_DraftState>();
    late CachedCupertinoPage page;
    late BuildContext homeContext;
    page = CachedCupertinoPage(
        child: _Draft(key: key, onClose: () => page.hide(), onDisposed: () {}),
        onHidden: () {});
    addTearDown(() {
      page.dispose();
    });
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            platform: TargetPlatform.iOS, pageTransitionsTheme: _theme),
        home: Builder(builder: (context) {
          homeContext = context;
          return Scaffold(
              body: TextButton(
                  onPressed: () => page.show(context),
                  child: const Text('support')));
        })));
    await tester.tap(find.text('support'));
    await tester.pumpAndSettle();
    final state = key.currentState;
    state!.text.text = 'retained';
    page.hide();
    page.show(homeContext);
    await tester.pumpAndSettle();
    expect(key.currentState, same(state));
    expect(find.text('retained'), findsOneWidget);
  });

  for (final cupertino in [false, true]) {
    testWidgets(
        '${cupertino ? 'document' : 'ordinary page'} uses standard left edge only',
        (tester) async {
      await _open(tester, cupertino: cupertino);
      await _swipe(tester, const Offset(140, 300), const Offset(230, 0));
      expect(find.text('article 0'), findsOneWidget);
      await _swipe(tester, const Offset(385, 300), const Offset(-230, 0));
      expect(find.text('article 0'), findsOneWidget);
      await _swipe(tester, const Offset(5, 300), const Offset(270, 0));
      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('document scrolling and pop interception are preserved',
      (tester) async {
    await _open(tester, cupertino: true, protected: true);
    await _swipe(tester, const Offset(5, 300), const Offset(270, 0));
    expect(find.text('open'), findsNothing);
    await _swipe(tester, const Offset(140, 550), const Offset(15, -260));
    expect(find.text('article 0'), findsNothing);
    expect(find.text('open'), findsNothing);
  });
  testWidgets('cancelled standard back keeps route and navigator usable',
      (tester) async {
    await _open(tester, cupertino: true);
    final gesture = await tester.startGesture(const Offset(5, 300));
    await gesture.moveBy(const Offset(90, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(find.text('article 0'), findsOneWidget);
    await _swipe(tester, const Offset(5, 300), const Offset(270, 0));
    expect(find.text('open'), findsOneWidget);
  });
  testWidgets(
      'chat retains state, draft and scroll across standard back and reopen',
      (tester) async {
    await _size(tester);
    final key = GlobalKey<_DraftState>();
    var hidden = 0;
    var disposed = 0;
    late CachedCupertinoPage page;
    page = CachedCupertinoPage(
        child: _Draft(
            key: key, onClose: () => page.hide(), onDisposed: () => disposed++),
        onHidden: () => hidden++);
    addTearDown(page.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            platform: TargetPlatform.iOS, pageTransitionsTheme: _theme),
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => page.show(context),
                    child: const Text('support'))))));
    await tester.tap(find.text('support'));
    await tester.pumpAndSettle();
    final state = key.currentState!;
    await tester.enterText(find.byKey(const Key('draft')), 'unsent draft');
    state.scroll.jumpTo(300);
    await tester.pump();
    await _swipe(tester, const Offset(5, 300), const Offset(270, 0));
    expect(hidden, 1);
    expect(disposed, 0);
    expect(key.currentState, same(state));
    await tester.tap(find.text('support'));
    await tester.pumpAndSettle();
    expect(key.currentState, same(state));
    expect(state.text.text, 'unsent draft');
    expect(state.scroll.offset, 300);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(hidden, 2);
    expect(disposed, 0);
    page.dispose();
    await tester.pumpAndSettle();
    expect(disposed, 1);
  });
  testWidgets('chat cancellation and attachment return do not hide its session',
      (tester) async {
    await _size(tester);
    var hidden = 0;
    late CachedCupertinoPage page;
    page = CachedCupertinoPage(
        child: _Draft(onClose: () => page.hide(), onDisposed: () {}),
        onHidden: () => hidden++);
    addTearDown(page.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            platform: TargetPlatform.iOS, pageTransitionsTheme: _theme),
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => page.show(context),
                    child: const Text('support'))))));
    await tester.tap(find.text('support'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(5, 300));
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(hidden, 0);
    await tester.tap(find.text('image'));
    await tester.pumpAndSettle();
    await _swipe(tester, const Offset(5, 300), const Offset(270, 0));
    expect(find.text('image'), findsOneWidget);
    expect(hidden, 0);
    await _swipe(tester, const Offset(5, 300), const Offset(270, 0));
    expect(hidden, 1);
  });
}

class _Draft extends StatefulWidget {
  const _Draft({super.key, required this.onClose, required this.onDisposed});
  final VoidCallback onClose, onDisposed;
  @override
  State<_Draft> createState() => _DraftState();
}

class _DraftState extends State<_Draft> {
  final text = TextEditingController();
  final scroll = ScrollController();
  @override
  void dispose() {
    widget.onDisposed();
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: widget.onClose)),
      body: Column(children: [
        TextField(key: const Key('draft'), controller: text),
        TextButton(
            onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('attachment')))),
            child: const Text('image')),
        Expanded(
            child: ListView(
                controller: scroll,
                children: List.generate(80,
                    (i) => SizedBox(height: 60, child: Text('message $i')))))
      ]));
}
