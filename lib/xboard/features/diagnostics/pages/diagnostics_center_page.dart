import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/diagnostics/pages/net_check_page.dart';
import 'package:fl_clash/xboard/features/shared/widgets/connection_health_dialog.dart';
import 'package:flutter/material.dart';

class DiagnosticsCenterPage extends StatelessWidget {
  const DiagnosticsCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              tabs: [
                Tab(
                  icon: const Icon(Icons.network_check_outlined),
                  text: l10n.xboardDiagnosticNetworkConnectivity,
                ),
                Tab(
                  icon: const Icon(Icons.health_and_safety_outlined),
                  text: l10n.xboardDiagnosticServiceStatus,
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                NetCheckPage(showVpnStatus: false),
                ConnectionHealthView(showHeader: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
