part of '../pages/login_page.dart';

class _QrLoginCard extends StatefulWidget {
  const _QrLoginCard({
    required this.enabled,
    required this.refreshFocusNode,
    required this.onRefreshKeyEvent,
    required this.onAuthorized,
  });
  final bool enabled;

  final FocusNode refreshFocusNode;
  final FocusOnKeyEventCallback onRefreshKeyEvent;
  final Future<bool> Function(QrLoginResult result) onAuthorized;

  @override
  State<_QrLoginCard> createState() => _QrLoginCardState();
}

class _QrLoginCardState extends State<_QrLoginCard> {
  static const _refreshCooldown = Duration(seconds: 5);

  QrLoginChallenge? _challenge;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  bool _loading = false;
  bool _expired = false;
  Duration _remaining = Duration.zero;
  DateTime? _refreshAvailableAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  @override
  void didUpdateWidget(covariant _QrLoginCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) {
      final challenge = _challenge;
      if (challenge == null) {
        _create();
      } else if (_hasExpired(challenge)) {
        _markExpired();
      } else {
        _startTimers(challenge);
      }
    }
    if (oldWidget.enabled && !widget.enabled) _stopTimers();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _pollTimer = null;
    _countdownTimer = null;
  }

  bool _hasExpired(QrLoginChallenge challenge) {
    return !DateTime.now().toUtc().isBefore(challenge.expiresAt);
  }

  void _startTimers(QrLoginChallenge challenge) {
    _stopTimers();
    _refreshAvailableAt = DateTime.now().add(_refreshCooldown);
    _updateCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  void _updateCountdown() {
    if (!mounted) return;
    final challenge = _challenge;
    if (challenge == null) return;
    final milliseconds =
        challenge.expiresAt.difference(DateTime.now().toUtc()).inMilliseconds;
    final seconds = milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;
    final expired = seconds == 0;
    setState(() {
      _remaining = Duration(seconds: seconds);
      _expired = expired;
    });
    if (expired) _stopTimers();
  }

  void _markExpired() {
    if (!mounted) return;
    _stopTimers();
    setState(() {
      _remaining = Duration.zero;
      _expired = true;
    });
  }

  Future<void> _create({bool invalidateCurrent = false}) async {
    if (_loading || !widget.enabled) return;
    final previous = _challenge;
    final previousWasExpired = previous != null && _hasExpired(previous);
    var previousInvalidated = previous == null;
    setState(() {
      _loading = true;
      _error = null;
      if (previousWasExpired) {
        _challenge = null;
        _remaining = Duration.zero;
        _expired = false;
      }
    });
    try {
      if (invalidateCurrent && previous != null) {
        await QrLoginService.cancel(previous);
        previousInvalidated = true;
      }
      if (invalidateCurrent && previous != null && previousInvalidated) {
        _stopTimers();
        if (!mounted) return;
        setState(() {
          _challenge = null;
          _remaining = Duration.zero;
          _expired = false;
        });
      }
      final challenge = await QrLoginService.create();
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _loading = false;
        _expired = false;
        _error = null;
      });
      _startTimers(challenge);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (previousWasExpired) {
            _challenge = previous;
            _remaining = Duration.zero;
            _expired = true;
          } else if (previousInvalidated) {
            _challenge = null;
          }
          _error = invalidateCurrent
              ? AppLocalizations.of(context).xboardQrRefreshFailed
              : AppLocalizations.of(context).xboardQrLoadFailed;
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (_loading || !widget.enabled) return;
    final availableAt = _refreshAvailableAt;
    if (!_expired &&
        availableAt != null &&
        DateTime.now().isBefore(availableAt)) {
      return;
    }
    // Expired challenges are already unusable and do not need a cancellation
    // round-trip. Skipping it prevents a failed cancel request from blocking
    // creation of the replacement QR code.
    await _create(invalidateCurrent: !_expired);
  }

  Future<void> _poll() async {
    final challenge = _challenge;
    if (!widget.enabled || challenge == null || _loading || _expired) return;
    try {
      final result = await QrLoginService.poll(challenge);
      if (result == null) return;
      _stopTimers();
      if (!mounted) return;
      setState(() => _loading = true);
      final success = await widget.onAuthorized(result);
      if (mounted && !success) {
        setState(() {
          _loading = false;
          _error = AppLocalizations.of(context).xboardQrLoginFailed;
          _remaining = Duration.zero;
          _expired = true;
        });
      }
    } on QrLoginExpiredException {
      _markExpired();
    } catch (_) {
      // An expired/consumed challenge is replaced explicitly so transient
      // polling failures do not make the login page flicker.
    }
  }

  String get _countdownText {
    final l10n = AppLocalizations.of(context);
    if (_loading && _challenge == null) return l10n.xboardQrGenerating;
    if (_expired) return _error ?? l10n.xboardQrExpired;
    if (_challenge == null) return _error ?? l10n.xboardQrUnavailable;
    if (_error != null) return _error!;
    final minutes =
        _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return l10n.xboardQrExpiresIn('$minutes:$seconds');
  }

  Widget _buildQrSurface(
    BuildContext context,
    ThemeData theme,
    double qrSize,
  ) {
    final challenge = _challenge;
    final canInteract = widget.enabled;
    final radius = BorderRadius.circular(12);
    final l10n = AppLocalizations.of(context);
    final minutes =
        _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Semantics(
      button: true,
      label: _expired
          ? l10n.xboardQrExpiredSemantics
          : l10n.xboardQrReadySemantics('$minutes:$seconds'),
      child: TVFocusable(
        focusNode: widget.refreshFocusNode,
        borderRadius: radius,
        onPressed: canInteract ? _refresh : null,
        onKeyEvent: widget.onRefreshKeyEvent,
        child: SizedBox.square(
          dimension: qrSize,
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (challenge != null)
                  ColoredBox(
                    color: Colors.white,
                    child: QrImageView(
                      data: challenge.qrData,
                      size: qrSize,
                      backgroundColor: Colors.white,
                    ),
                  )
                else
                  ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Text(
                        _error ?? l10n.xboardQrUnavailable,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                if (_loading)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.42),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                else if (_expired && challenge != null)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.52),
                    child: Center(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ).copyWith(
                          overlayColor: const WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                        ),
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(l10n.xboardQrRefresh),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final qrSize = system.isTV ? 160.0 : 180.0;
    return Container(
      // 与账号密码表单使用同一父级最大宽度，内容高度仍由二维码区域决定。
      width: double.infinity,
      padding: EdgeInsets.all(system.isTV ? 12 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      // 卡片按内容收紧，等高差额由外层 IndexedStack 留在边框外。
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l10n.xboardQrLogin,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          l10n.xboardQrLoginDescription,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _buildQrSurface(context, theme, qrSize),
        const SizedBox(height: 8),
        Text(
          _countdownText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: _expired
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: _expired ? XbFontWeight.semibold : FontWeight.normal,
          ),
        ),
      ]),
    );
  }
}
