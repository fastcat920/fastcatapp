part of '../pages/xboard_home_page.dart';

class _TokenExpiredDialog extends StatefulWidget {
  final String title;
  final String content;
  final String actionLabel;
  final Future<void> Function() onRelogin;

  const _TokenExpiredDialog({
    required this.title,
    required this.content,
    required this.actionLabel,
    required this.onRelogin,
  });

  @override
  State<_TokenExpiredDialog> createState() => _TokenExpiredDialogState();
}

class _TokenExpiredDialogState extends State<_TokenExpiredDialog> {
  bool _isProcessing = false;

  Future<void> _handleRelogin() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await widget.onRelogin();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Text(widget.content),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : _handleRelogin,
          child: _isProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.actionLabel),
        ),
      ],
    );
  }
}

class _HomeBrandHeader extends ConsumerWidget {
  const _HomeBrandHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final configuredLocale = ref.watch(
      appSettingProvider.select((setting) => setting.locale),
    );
    final brandName = localizedAppNameForLocale(
      configuredLocale ?? Localizations.localeOf(context).toLanguageTag(),
    );
    final connectivityState = ref.watch(serviceConnectivityProvider);
    final userState = ref.watch(xboardUserProvider);
    final showServiceBadge = userState.isAuthenticated &&
        !connectivityState.isOnline &&
        (!connectivityState.isDegraded ||
            connectivityState.consecutiveFailures >= 2) &&
        (!connectivityState.isRecovering ||
            connectivityState.consecutiveFailures >= 2);
    final badgeLabel = switch (connectivityState.status) {
      ServiceConnectivityStatus.degraded =>
        l10n.xboardServiceConnectionDegraded,
      ServiceConnectivityStatus.recovering => l10n.xboardServiceRecovering,
      ServiceConnectivityStatus.offline => switch (connectivityState.cause) {
          ServiceConnectivityCause.noNetwork => l10n.xboardServiceNoNetwork,
          ServiceConnectivityCause.networkRestricted =>
            l10n.xboardServiceNetworkRestricted,
          _ => l10n.xboardServiceOfflineCacheMode,
        },
      ServiceConnectivityStatus.online => '',
    };
    final tooltipMessage = switch (connectivityState.status) {
      ServiceConnectivityStatus.degraded => l10n.xboardServiceDegradedTooltip,
      ServiceConnectivityStatus.recovering =>
        l10n.xboardServiceRecoveringTooltip,
      ServiceConnectivityStatus.offline => switch (connectivityState.cause) {
          ServiceConnectivityCause.noNetwork =>
            l10n.xboardServiceNoNetworkTooltip,
          ServiceConnectivityCause.networkRestricted =>
            l10n.xboardServiceNetworkRestrictedTooltip,
          _ => l10n.xboardServiceOfflineCacheTooltip,
        },
      ServiceConnectivityStatus.online => '',
    };
    final badgeIcon = switch (connectivityState.status) {
      ServiceConnectivityStatus.recovering => Icons.sync_outlined,
      ServiceConnectivityStatus.degraded => Icons.cloud_off_outlined,
      ServiceConnectivityStatus.offline => switch (connectivityState.cause) {
          ServiceConnectivityCause.noNetwork => Icons.wifi_off_outlined,
          ServiceConnectivityCause.networkRestricted =>
            Icons.signal_wifi_statusbar_connected_no_internet_4_outlined,
          _ => Icons.cloud_off_outlined,
        },
      ServiceConnectivityStatus.online => Icons.cloud_done_outlined,
    };
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLocalNetworkFailure = connectivityState.isOffline &&
        (connectivityState.cause == ServiceConnectivityCause.noNetwork ||
            connectivityState.cause ==
                ServiceConnectivityCause.networkRestricted);
    final badgeForeground = isDark
        ? theme.colorScheme.onSurface
        : isLocalNetworkFailure
            ? const Color(0xFFB3261E)
            : const Color(0xFF8A5A00);
    final badgeBackground = isDark
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.28)
        : isLocalNetworkFailure
            ? const Color(0xFFFFEDEA)
            : const Color(0xFFFFF4E5);
    final badgeBorder = isDark
        ? theme.colorScheme.error.withValues(alpha: 0.45)
        : isLocalNetworkFailure
            ? const Color(0xFFFFB4AB)
            : const Color(0xFFFFD08A);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/icon.png',
            width: 30,
            height: 30,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          brandName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: XbFontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (showServiceBadge) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: tooltipMessage,
            triggerMode: TooltipTriggerMode.tap,
            preferBelow: false,
            waitDuration: const Duration(milliseconds: 300),
            showDuration: const Duration(seconds: 6),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBackground,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: badgeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeForeground),
                    const SizedBox(width: 4),
                    Text(
                      badgeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: badgeForeground,
                        fontWeight: XbFontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 15,
                      height: 15,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: badgeForeground.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: badgeForeground.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Icon(
                        Icons.question_mark_rounded,
                        size: 9,
                        color: badgeForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeNoticeCard extends ConsumerStatefulWidget {
  const _HomeNoticeCard();

  @override
  ConsumerState<_HomeNoticeCard> createState() => _HomeNoticeCardState();
}

class _HomeNoticeCardState extends ConsumerState<_HomeNoticeCard> {
  Timer? _timer;
  late final PageController _pageController;
  int _index = 0;
  int _noticeCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _syncTimer(int count) {
    if (_noticeCount == count) return;
    _noticeCount = count;
    if (_index >= count) _index = 0;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_index);
    }
    _timer?.cancel();
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final nextIndex = (_index + 1) % count;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else {
        setState(() => _index = nextIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final noticeState = ref.watch(noticeProvider);
    final notices = noticeState.visibleNotices;
    _syncTimer(notices.length);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    void openCurrentNotice() {
      if (notices.isEmpty) return;
      final notice = notices[_index];
      showDialog(
        context: context,
        builder: (_) => NoticeDetailDialog(notices: [notice]),
      );
    }

    final card = Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withValues(alpha: 0.18)
              : const Color(0xFFEEF0F4),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withAlpha(15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: XbPointerCursor(
        enabled: notices.isNotEmpty,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: notices.isEmpty ? null : openCurrentNotice,
            child: SizedBox(
              height: 136,
              child: Stack(
                children: [
                  notices.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: _NoticeCardContent(
                            title: '暂无公告',
                            content: '当前没有最新公告',
                            isLoading: noticeState.isLoading,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        )
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: notices.length,
                          onPageChanged: (index) =>
                              setState(() => _index = index),
                          itemBuilder: (context, index) {
                            final notice = notices[index];
                            return Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: _NoticeCardContent(
                                title: notice.title.trim().isNotEmpty
                                    ? notice.title
                                    : '暂无公告',
                                content: _plainNoticeContent(notice.content),
                                dateText: _formatNoticeDate(notice.createdAt),
                                colorScheme: colorScheme,
                                theme: theme,
                              ),
                            );
                          },
                        ),
                  if (notices.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: _buildNoticeIndicators(
                        count: notices.length,
                        activeIndex: _index,
                        colorScheme: colorScheme,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final focusedCard = system.isTV
        ? TVFocusable(
            borderRadius: BorderRadius.circular(XbUiTokens.radiusCard),
            onPressed: notices.isEmpty ? null : openCurrentNotice,
            child: ExcludeFocus(child: card),
          )
        : card;

    return SizedBox(
      height: isDesktop ? 136 : 148,
      child: focusedCard,
    );
  }

  String _plainNoticeContent(String content) {
    final normalized = content
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.isEmpty ? '点击查看公告详情' : normalized;
  }

  String _formatNoticeDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildNoticeIndicators({
    required int count,
    required int activeIndex,
    required ColorScheme colorScheme,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: index == activeIndex ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: index == activeIndex
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _NoticeCardContent extends StatelessWidget {
  final String title;
  final String content;
  final String dateText;
  final bool isLoading;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _NoticeCardContent({
    required this.title,
    required this.content,
    required this.colorScheme,
    required this.theme,
    this.dateText = '',
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.campaign_outlined,
                color: colorScheme.primary,
                size: 15,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: XbFontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (dateText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                dateText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: XbFontWeight.semibold,
                ),
              ),
            ] else if (isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          content,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
