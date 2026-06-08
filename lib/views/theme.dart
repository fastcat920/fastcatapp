// ignore_for_file: deprecated_member_use

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeModeItem {
  final ThemeMode themeMode;
  final IconData iconData;
  final String label;

  const ThemeModeItem({
    required this.themeMode,
    required this.iconData,
    required this.label,
  });
}

class ThemeView extends StatelessWidget {
  const ThemeView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        spacing: 24,
        children: [
          _ThemeModeItem(),
          _PrueBlackItem(),
          _TextScaleFactorItem(),
          const SizedBox(
            height: 64,
          ),
        ],
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final Widget child;
  final Info info;
  final List<Widget> actions;

  const ItemCard({
    super.key,
    required this.info,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 16,
      children: [
        InfoHeader(
          info: info,
          actions: actions,
        ),
        child,
      ],
    );
  }
}

class _ThemeModeItem extends ConsumerWidget {
  const _ThemeModeItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(themeSettingProvider.select((state) => state.themeMode));
    List<ThemeModeItem> themeModeItems = [
      ThemeModeItem(
        iconData: Icons.auto_mode,
        label: appLocalizations.auto,
        themeMode: ThemeMode.system,
      ),
      ThemeModeItem(
        iconData: Icons.light_mode,
        label: appLocalizations.light,
        themeMode: ThemeMode.light,
      ),
      ThemeModeItem(
        iconData: Icons.dark_mode,
        label: appLocalizations.dark,
        themeMode: ThemeMode.dark,
      ),
    ];
    return ItemCard(
      info: Info(
        label: appLocalizations.themeMode,
        iconData: Icons.brightness_high,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: themeModeItems.length,
          itemBuilder: (_, index) {
            final themeModeItem = themeModeItems[index];
            return CommonCard(
              isSelected: themeModeItem.themeMode == themeMode,
              onPressed: () {
                ref.read(themeSettingProvider.notifier).updateState(
                      (state) => state.copyWith(
                        themeMode: themeModeItem.themeMode,
                      ),
                    );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Icon(themeModeItem.iconData),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Flexible(
                      child: Text(
                        themeModeItem.label,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (_, __) {
            return const SizedBox(
              width: 16,
            );
          },
        ),
      ),
    );
  }
}

class _PrueBlackItem extends ConsumerWidget {
  const _PrueBlackItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prueBlack = ref.watch(
      themeSettingProvider.select(
        (state) => state.pureBlack,
      ),
    );
    return ListItem.switchItem(
      leading: Icon(
        Icons.contrast,
      ),
      horizontalTitleGap: 12,
      title: Text(
        appLocalizations.pureBlackMode,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
      ),
      delegate: SwitchDelegate(
        value: prueBlack,
        onChanged: (value) {
          ref.read(themeSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  pureBlack: value,
                ),
              );
        },
      ),
    );
  }
}

class _TextScaleFactorItem extends ConsumerWidget {
  const _TextScaleFactorItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = ref.watch(
      themeSettingProvider.select(
        (state) => state.textScale,
      ),
    );
    final String process = "${((textScale.scale * 100) as double).round()}%";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: ListItem.switchItem(
            leading: Icon(
              Icons.text_fields,
            ),
            horizontalTitleGap: 12,
            title: Text(
              appLocalizations.textScale,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
            ),
            delegate: SwitchDelegate(
              value: textScale.enable,
              onChanged: (value) {
                ref.read(themeSettingProvider.notifier).updateState(
                      (state) => state.copyWith.textScale(
                        enable: value,
                      ),
                    );
              },
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            spacing: 32,
            children: [
              Expanded(
                child: DisabledMask(
                  status: !textScale.enable,
                  child: ActivateBox(
                    active: textScale.enable,
                    child: SliderTheme(
                      data: _SliderDefaultsM3(context),
                      child: Slider(
                        min: minTextScale,
                        max: maxTextScale,
                        value: textScale.scale,
                        onChanged: (value) {
                          ref.read(themeSettingProvider.notifier).updateState(
                                (state) => state.copyWith.textScale(
                                  scale: value,
                                ),
                              );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text(
                  process,
                  style: context.textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SliderDefaultsM3 extends SliderThemeData {
  _SliderDefaultsM3(this.context) : super(trackHeight: 16.0);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color? get activeTrackColor => _colors.primary;

  @override
  Color? get inactiveTrackColor => _colors.secondaryContainer;

  @override
  Color? get secondaryActiveTrackColor => _colors.primary.withOpacity(0.54);

  @override
  Color? get disabledActiveTrackColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get disabledInactiveTrackColor => _colors.onSurface.withOpacity(0.12);

  @override
  Color? get disabledSecondaryActiveTrackColor =>
      _colors.onSurface.withOpacity(0.38);

  @override
  Color? get activeTickMarkColor => _colors.onPrimary.withOpacity(1.0);

  @override
  Color? get inactiveTickMarkColor =>
      _colors.onSecondaryContainer.withOpacity(1.0);

  @override
  Color? get disabledActiveTickMarkColor => _colors.onInverseSurface;

  @override
  Color? get disabledInactiveTickMarkColor => _colors.onSurface;

  @override
  Color? get thumbColor => _colors.primary;

  @override
  Color? get disabledThumbColor => _colors.onSurface.withOpacity(0.38);

  @override
  Color? get overlayColor =>
      WidgetStateColor.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.dragged)) {
          return _colors.primary.withOpacity(0.1);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.primary.withOpacity(0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.primary.withOpacity(0.1);
        }

        return Colors.transparent;
      });

  @override
  TextStyle? get valueIndicatorTextStyle =>
      Theme.of(context).textTheme.labelLarge!.copyWith(
            color: _colors.onInverseSurface,
          );

  @override
  Color? get valueIndicatorColor => _colors.inverseSurface;

  @override
  SliderComponentShape? get valueIndicatorShape =>
      const RectangularSliderValueIndicatorShape();

  @override
  SliderComponentShape? get thumbShape => const RoundSliderThumbShape();

  @override
  SliderTrackShape? get trackShape => const RectangularSliderTrackShape();

  @override
  SliderComponentShape? get overlayShape => const RoundSliderOverlayShape();

  @override
  SliderTickMarkShape? get tickMarkShape =>
      const RoundSliderTickMarkShape(tickMarkRadius: 4.0 / 2);

  WidgetStateProperty<Size?>? get thumbSize {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return const Size(4.0, 44.0);
      }
      if (states.contains(WidgetState.hovered)) {
        return const Size(4.0, 44.0);
      }
      if (states.contains(WidgetState.focused)) {
        return const Size(2.0, 44.0);
      }
      if (states.contains(WidgetState.pressed)) {
        return const Size(2.0, 44.0);
      }
      return const Size(4.0, 44.0);
    });
  }

  double? get trackGap => 6.0;
}
