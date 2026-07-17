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
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
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
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Card(
                    elevation: isDark ? 0 : 1,
                    margin: EdgeInsets.zero,
                    shadowColor:
                        isDark ? null : Colors.black.withValues(alpha: 0.08),
                    color: isDark ? null : Colors.white,
                    shape: XbUiCardStyle.shape(context),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _GiftCardForm(
                        controller: _codeCtrl,
                        isSubmitting: _isSubmitting,
                        onRedeem: _redeem,
                      ),
                    ),
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
    ref.read(xboardUserAuthProvider.notifier).refreshUserInfo();
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
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
            child: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
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
