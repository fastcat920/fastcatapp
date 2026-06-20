import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/state/ticket_state.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'ticket_detail_page.dart';

class TicketPage extends ConsumerStatefulWidget {
  const TicketPage({super.key});

  @override
  ConsumerState<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends ConsumerState<TicketPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshAnim;

  @override
  void initState() {
    super.initState();
    _refreshAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _refreshAnim.dispose();
    super.dispose();
  }

  Future<void> _doRefresh() async {
    _refreshAnim.repeat();
    try {
      ref.invalidate(getTicketsProvider);
      await ref.read(getTicketsProvider.future);
    } catch (_) {}
    if (mounted) {
      final remaining = 1.0 - _refreshAnim.value;
      if (remaining > 0.01) {
        await _refreshAnim.animateTo(
          1.0,
          duration: Duration(milliseconds: (remaining * 700).round()),
        );
      }
      _refreshAnim.stop();
      _refreshAnim.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(getTicketsProvider);
    final l10n = AppLocalizations.of(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? null : XbUiTokens.pageBackgroundLight,
      appBar: AppBar(
        title: Text(l10n.xboardMyTickets),
        actions: [
          if (Platform.isLinux ||
              Platform.isWindows ||
              Platform.isMacOS ||
              system.isTV)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _doRefresh,
              ),
            ),
        ],
      ),
      body: ticketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(getTicketsProvider),
        ),
        data: (tickets) => tickets.isEmpty
            ? _EmptyView()
            : RefreshIndicator(
                onRefresh: _doRefresh,
                child: ListView.builder(
                  padding: XbUiTokens.pagePadding,
                  itemCount: tickets.length,
                  itemBuilder: (context, index) => _TicketCard(
                    ticket: tickets[index],
                    onTap: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) =>
                                TicketDetailPage(ticketId: tickets[index].id),
                          ),
                        )
                        .then((_) => ref.invalidate(getTicketsProvider)),
                  ),
                ),
              ),
      ),
    );
  }
}

// ─── 工单列表卡片 ──────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final VoidCallback onTap;
  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(context, ticket.status);
    final statusLabel =
        _statusLabel(context, ticket.status, ticket.replyStatus);
    final priorityLabel = _priorityLabel(context, ticket.level);
    final priorityColor = _priorityColor(context, ticket.level);

    final isDark = theme.brightness == Brightness.dark;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: XbUiTokens.listCardGapBottom10,
      color: isDark ? null : Colors.white,
      shape: XbUiCardStyle.shape(context, radius: XbUiTokens.radiusCardCompact),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题 + 状态
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 优先级 + 更新时间
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      priorityLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: priorityColor, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time_outlined,
                      size: 13, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(
                    _formatDate(ticket.updatedAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, int status) {
    switch (status) {
      case 0:
        return XbUiStatusColor.pending(context); // 待处理
      case 1:
        return XbUiStatusColor.success(context); // 已回复
      case 2:
        return XbUiStatusColor.muted(context); // 已关闭
      default:
        return XbUiStatusColor.muted(context);
    }
  }

  String _statusLabel(BuildContext context, int status, int replyStatus) {
    final l10n = AppLocalizations.of(context);
    if (status == 2) return l10n.xboardTicketClosed;
    if (replyStatus == 0) return l10n.xboardTicketPendingReply;
    return l10n.xboardTicketReplied;
  }

  Color _priorityColor(BuildContext context, int level) {
    switch (level) {
      case 0:
        return XbUiStatusColor.info(context);
      case 1:
        return XbUiStatusColor.pending(context);
      case 2:
        return XbUiStatusColor.error(context);
      default:
        return XbUiStatusColor.muted(context);
    }
  }

  String _priorityLabel(BuildContext context, int level) {
    final l10n = AppLocalizations.of(context);
    switch (level) {
      case 0:
        return l10n.xboardLow;
      case 1:
        return l10n.xboardMedium;
      case 2:
        return l10n.xboardHigh;
      default:
        return l10n.xboardNormal;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// ─── 公共组件 ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).xboardLoadingFailed,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context).xboardRetry)),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.support_agent_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context).xboardNoTicketRecords,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(AppLocalizations.of(context).xboardCreateTicketHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
