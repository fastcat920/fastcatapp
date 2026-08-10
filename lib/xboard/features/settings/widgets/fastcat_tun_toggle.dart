import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FastCatTunToggle extends ConsumerWidget {
  const FastCatTunToggle({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled =
        ref.watch(patchClashConfigProvider.select((state) => state.tun.enable));
    return SwitchListTile(
      title: Text(l10n.tun),
      subtitle: Text(l10n.tunDesc),
      value: enabled,
      onChanged: (value) {
        ref.read(patchClashConfigProvider.notifier).updateState(
              (state) => state.copyWith.tun(enable: value),
            );
        onChanged?.call();
      },
    );
  }
}
