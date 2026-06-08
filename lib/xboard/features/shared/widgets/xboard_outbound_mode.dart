import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/l10n/l10n.dart';

// 初始化文件级日志器
final _logger = FileLogger('xboard_outbound_mode.dart');

class XBoardOutboundMode extends StatelessWidget {
  const XBoardOutboundMode({super.key});

  void _handleModeChange(WidgetRef ref, Mode modeOption) {
    _logger.debug('[XBoardOutboundMode] 切换模式到: $modeOption');
    globalState.appController.changeMode(modeOption);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer(
      builder: (context, ref, child) {
        final mode = ref.watch(
            patchClashConfigProvider.select((state) => state.mode));
        final selectedMode = mode == Mode.global ? Mode.global : Mode.rule;
        final l10n = AppLocalizations.of(context);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).colorScheme.surfaceContainer
                    : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(19),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: _SegmentItem(
                      label: l10n.xboardSmartRouting,
                      isSelected: selectedMode == Mode.rule,
                      isDark: isDark,
                      onTap: () => _handleModeChange(ref, Mode.rule),
                    ),
                  ),
                  Expanded(
                    child: _SegmentItem(
                      label: l10n.xboardGlobalProxy,
                      isSelected: selectedMode == Mode.global,
                      isDark: isDark,
                      onTap: () => _handleModeChange(ref, Mode.global),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _SegmentItem({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Colors.white)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSelected && !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.45),
        ),
      ),
    );

    if (system.isTV) {
      return TVFocusable(
        onPressed: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: content,
    );
  }
}
