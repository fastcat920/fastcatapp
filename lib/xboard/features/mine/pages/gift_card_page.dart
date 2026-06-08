import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/features/auth/providers/xboard_user_provider.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/xboard/features/shared/widgets/tv_deferred_input.dart';
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
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).xboardEnterGiftCardCode),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      final isV2Board = XBoardConfig.provider.getPanelType() == 'v2board';
      final endpoint =
          isV2Board ? '/user/redeemgiftcard' : '/user/gift-card/redeem';
      final body = isV2Board ? {'giftcard': code} : {'code': code};
      final resp = await sdk.httpService.postRequest(endpoint, body);
      if (mounted) {
        final data = resp['data'];
        final success = data != null && data != false;
        final msg = resp['message'] as String? ?? (success ? '兑换成功' : '兑换失败');
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('兑换失败: $e')));
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
                : Text(AppLocalizations.of(context).xboardRedeemNow),
          ),
        ),
      ],
    );
  }
}
