import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';

/// 支付方式选择对话框
class PaymentMethodSelectorDialog extends StatefulWidget {
  final List<DomainPaymentMethod> paymentMethods;
  final DomainPaymentMethod? selectedMethod;

  const PaymentMethodSelectorDialog({
    super.key,
    required this.paymentMethods,
    this.selectedMethod,
  });

  @override
  State<PaymentMethodSelectorDialog> createState() =>
      _PaymentMethodSelectorDialogState();

  /// 显示支付方式选择对话框
  static Future<DomainPaymentMethod?> show(
    BuildContext context, {
    required List<DomainPaymentMethod> paymentMethods,
    DomainPaymentMethod? selectedMethod,
  }) async {
    return await showDialog<DomainPaymentMethod>(
      context: context,
      builder: (context) => PaymentMethodSelectorDialog(
        paymentMethods: paymentMethods,
        selectedMethod: selectedMethod,
      ),
    );
  }
}

class _PaymentMethodSelectorDialogState
    extends State<PaymentMethodSelectorDialog> {
  DomainPaymentMethod? _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.selectedMethod;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: XbUiDialog.shape(),
      backgroundColor: XbUiDialog.background(context),
      title: Text(
        AppLocalizations.of(context).xboardSelectPaymentMethod,
        style: XbUiText.sectionTitle(context).copyWith(fontSize: 20),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < widget.paymentMethods.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _buildPaymentMethodTile(widget.paymentMethods[i]),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: XbUiButton.outlinedNeutral(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: _selectedMethod == null
              ? null
              : () => Navigator.of(context).pop(_selectedMethod),
          style: XbUiButton.filledPrimary(context),
          child: Text(AppLocalizations.of(context).confirm),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(DomainPaymentMethod method) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final isSelected = _selectedMethod?.id == method.id;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark
                  ? theme.colorScheme.outline.withValues(alpha: 0.3)
                  : const Color(0xFFEEF0F4)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A1565C0),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: method.iconUrl != null && method.iconUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: method.iconUrl!,
                width: 32,
                height: 32,
                errorWidget: (context, url, error) =>
                    const Icon(Icons.payment, size: 32),
              )
            : const Icon(Icons.payment, size: 32),
        title: Text(
          method.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.colorScheme.primary : null,
          ),
        ),
        subtitle: method.feePercentage > 0
            ? Text(
                '${AppLocalizations.of(context).xboardHandlingFee}: ${method.feePercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              )
            : null,
        trailing: Radio<int>(
          value: method.id,
          // ignore: deprecated_member_use
          groupValue: _selectedMethod?.id,
          // ignore: deprecated_member_use
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedMethod = method;
            });
          },
          activeColor: theme.colorScheme.primary,
        ),
        onTap: () {
          setState(() {
            _selectedMethod = method;
          });
        },
      ),
    );
  }
}
