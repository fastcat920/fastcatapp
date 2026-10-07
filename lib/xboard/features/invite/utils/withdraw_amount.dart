/// Parse a yuan amount into integer cents without floating-point rounding.
/// Reject extra decimal places instead of silently changing the user's amount.
int? parseWithdrawAmountInCents(String text) {
  final value = text.trim();
  if (!RegExp(r'^\d+(?:\.\d{0,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final whole = BigInt.tryParse(parts.first);
  if (whole == null) return null;
  final fraction = parts.length == 1 ? '00' : parts.last.padRight(2, '0');
  final cents = whole * BigInt.from(100) + BigInt.from(int.parse(fraction));
  // Keep the amount exactly representable by every supported Dart target.
  if (cents <= BigInt.zero || cents > BigInt.from(9007199254740991)) {
    return null;
  }
  return cents.toInt();
}
