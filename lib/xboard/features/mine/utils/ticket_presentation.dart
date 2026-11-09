import 'package:fl_clash/l10n/l10n.dart';

String ticketStatusLabel(AppLocalizations l10n, int status, int replyStatus) {
  if (status != 0) return l10n.xboardTicketClosed;
  return replyStatus == 1
      ? l10n.xboardTicketReplied
      : l10n.xboardTicketPendingProcessing;
}
