/// Resolve the same default for the visible checkmark, fee and payment request.
/// Never silently replace a previously selected method that became unavailable.
String? resolvePaymentMethodId(
    Iterable<String> availableIds, String? selectedId) {
  final ids = availableIds.where((id) => id.trim().isNotEmpty).toList();
  final preferred = selectedId?.trim();
  if (preferred != null && preferred.isNotEmpty) {
    return ids.contains(preferred) ? preferred : null;
  }
  return ids.isEmpty ? null : ids.first;
}
