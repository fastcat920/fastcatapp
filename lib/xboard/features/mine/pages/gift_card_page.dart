import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/mine/services/gift_card_redeem_service.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/tv_deferred_input.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GiftCardPage extends ConsumerStatefulWidget {
  const GiftCardPage({super.key});

  @override
  ConsumerState<GiftCardPage> createState() => _GiftCardPageState();
}

class _GiftCardPageState extends ConsumerState<GiftCardPage> {
  final _codeCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingRecords = true;
  String? _recordsError;
  List<GiftCardRedemptionRecord> _records = const [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final l10n = AppLocalizations.of(context);
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      XBoardNotification.showError(l10n.xboardPleaseEnterGiftCardCode);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final result = await GiftCardRedeemService.redeem(
        ref: ref,
        l10n: l10n,
        code: code,
      );
      if (!mounted) return;
      if (result.success) {
        _codeCtrl.clear();
        await _loadRecords(showLoading: false);
        XBoardNotification.showSuccess(result.message);
      } else {
        XBoardNotification.showError(result.message);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : XbUiTokens.pageBackgroundLight,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).xboardGiftCardRedeem),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshPage,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: XbUiTokens.pagePadding,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    children: [
                      _GiftCardSurface(
                        child: _GiftCardForm(
                          controller: _codeCtrl,
                          isSubmitting: _isSubmitting,
                          onRedeem: _redeem,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _GiftCardSurface(
                        child: const _GiftCardUsageGuide(),
                      ),
                      const SizedBox(height: 16),
                      _GiftCardSurface(
                        child: _GiftCardRecords(
                          records: _records,
                          isLoading: _isLoadingRecords,
                          errorMessage: _recordsError,
                          onRetry: _loadRecords,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshPage() async {
    await Future.wait([
      ref.read(xboardUserAuthProvider.notifier).refreshUserInfo(),
      _loadRecords(showLoading: false),
    ]);
  }

  Future<void> _loadRecords({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoadingRecords = true;
        _recordsError = null;
      });
    }
    try {
      final records = await GiftCardRedeemService.fetchRedemptions(ref: ref);
      if (!mounted) return;
      setState(() {
        _records = records;
        _recordsError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _recordsError =
            AppLocalizations.of(context).xboardGiftCardRedemptionsLoadFailed);
      }
    } finally {
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }
}

class _GiftCardSurface extends StatelessWidget {
  const _GiftCardSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      elevation: isDark ? 0 : 1,
      margin: EdgeInsets.zero,
      shadowColor: isDark ? null : Colors.black.withValues(alpha: 0.08),
      color: isDark ? null : Colors.white,
      shape: XbUiCardStyle.shape(context),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _GiftCardRecords extends StatelessWidget {
  const _GiftCardRecords({
    required this.records,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });
  final List<GiftCardRedemptionRecord> records;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.history_outlined,
              color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.of(context).xboardGiftCardRedemptionRecords,
            style: XbUiText.sectionTitle(context),
          ),
        ]),
        const SizedBox(height: 12),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (errorMessage != null)
          Center(
              child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_outlined),
            label: Text(errorMessage!),
          ))
        else if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(
                child: Text(
                    AppLocalizations.of(context).xboardNoGiftCardRedemptions,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ))),
          )
        else
          ...records.map(_GiftCardRecordTile.new),
      ],
    );
  }
}

class _GiftCardRecordTile extends StatelessWidget {
  const _GiftCardRecordTile(this.record);
  final GiftCardRedemptionRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = record.redeemedAt <= 0
        ? '--'
        : DateTime.fromMillisecondsSinceEpoch(record.redeemedAt * 1000)
            .toLocal()
            .toString()
            .substring(0, 16);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  record.giftCardName?.isNotEmpty == true
                      ? record.giftCardName!
                      : record.codeMasked,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: XbFontWeight.semibold)),
              const SizedBox(height: 3),
              Text(record.codeMasked,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          )),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_valueLabel(context),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: XbFontWeight.semibold)),
              const SizedBox(height: 3),
              Text(date,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
        ]),
      ),
    );
  }

  String _valueLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (record.type) {
      1 => l10n.xboardGiftCardBalanceValue(
          (record.value / 100).toStringAsFixed(2),
        ),
      2 => l10n.xboardGiftCardSubscriptionDuration(record.value),
      3 => l10n.xboardGiftCardPlanTraffic(record.value),
      4 => l10n.xboardGiftCardResetPlanTraffic,
      5 => record.planName?.isNotEmpty == true
          ? l10n.xboardGiftCardPlanDuration(record.planName!, record.value)
          : l10n.xboardGiftCardPlanDurationFallback(record.value),
      _ => '--',
    };
  }
}

class _GiftCardUsageGuide extends StatelessWidget {
  const _GiftCardUsageGuide();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(l10n.xboardUsageInstructions,
              style: XbUiText.sectionTitle(context)),
        ]),
        const SizedBox(height: 12),
        _GuideItem(l10n.xboardGiftCardUsageGuideItem1),
        const SizedBox(height: 8),
        _GuideItem(l10n.xboardGiftCardUsageGuideItem2),
        const SizedBox(height: 8),
        _GuideItem(l10n.xboardGiftCardUsageGuideItem3),
      ],
    );
  }
}

class _GuideItem extends StatelessWidget {
  const _GuideItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
          ));
}

class _GiftCardForm extends StatelessWidget {
  const _GiftCardForm({
    required this.controller,
    required this.isSubmitting,
    required this.onRedeem,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).xboardGiftCardRedeem,
          style: XbUiText.sectionTitle(context),
        ),
        const SizedBox(height: 12),
        TVDeferredInput(
          borderRadius: BorderRadius.circular(10),
          builder: (context, focusNode, readOnly, showCursor, beginEditing) =>
              TextField(
            focusNode: focusNode,
            readOnly: readOnly,
            showCursor: showCursor,
            onTap: beginEditing,
            controller: controller,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).xboardGiftCardCode,
              hintText: AppLocalizations.of(context).xboardEnterGiftCardCode,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: const Icon(Icons.card_giftcard_outlined),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isSubmitting ? null : onRedeem,
            style: XbUiButton.filledPrimary(
              context,
              busy: isSubmitting,
            ),
            child: isSubmitting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.card_giftcard_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).xboardRedeemNow),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
