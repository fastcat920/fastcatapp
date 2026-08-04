import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/payment/widgets/period_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  Future<SliverGridDelegateWithFixedCrossAxisCount> pumpSelector(
    WidgetTester tester,
    double width,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: PeriodSelector(
                periods: const [
                  {
                    'period': 'month_price',
                    'label': '月付',
                    'price': 19.0,
                  },
                  {
                    'period': 'quarter_price',
                    'label': '季付',
                    'price': 51.3,
                  },
                  {
                    'period': 'half_year_price',
                    'label': '半年付',
                    'price': 91.2,
                  },
                  {
                    'period': 'year_price',
                    'label': '年付',
                    'price': 159.6,
                  },
                ],
                selectedPeriod: 'month_price',
                onPeriodSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final grid = tester.widget<GridView>(find.byType(GridView));
    return grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  }

  testWidgets('uses two columns on phone width', (tester) async {
    final delegate = await pumpSelector(tester, 400);

    expect(delegate.crossAxisCount, 2);
    expect(delegate.mainAxisExtent, 80);
  });

  testWidgets('uses three columns on medium content width', (tester) async {
    final delegate = await pumpSelector(tester, 700);

    expect(delegate.crossAxisCount, 3);
    expect(delegate.mainAxisExtent, 80);
  });

  testWidgets('uses four columns on tablet content width', (tester) async {
    final delegate = await pumpSelector(tester, 900);

    expect(delegate.crossAxisCount, 4);
    expect(delegate.mainAxisExtent, 80);
  });
}
