import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/adapter/state/ticket_state.dart';
import 'package:fl_clash/xboard/adapter/initialization/sdk_provider.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/features/shared/styles/styles.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/features/shared/widgets/tv_deferred_input.dart';
import 'package:fl_clash/xboard/features/mine/services/imgbb_service.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:image_picker/image_picker.dart';
import 'ticket_detail_page.dart';

class TicketPage extends ConsumerStatefulWidget {
  const TicketPage({super.key});

  @override
  ConsumerState<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends ConsumerState<TicketPage>
    with SingleTickerProviderStateMixin {
  @override
  void activate() {
    super.activate();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

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
if (Platform.isLinux || Platform.isWindows || Platform.isMacOS || system.isTV)
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTicketSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.xboardCreateTicket),
      ),
    );
  }

  void _showCreateTicketSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateTicketSheet(
        onCreated: () => ref.invalidate(getTicketsProvider),
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

// ─── 创建工单底部弹窗 ──────────────────────────────────────────────────────────

class _CreateTicketSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateTicketSheet({required this.onCreated});

  @override
  ConsumerState<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends ConsumerState<_CreateTicketSheet> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  int _level = 1; // 默认中等优先级
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  final List<String> _uploadedImageUrls = [];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final apiKey = XBoardConfig.imgbbApiKey;
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片上传未配置，请联系管理员')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final url = await ImgBBService(apiKey).uploadImage(File(picked.path));
      setState(() => _uploadedImageUrls.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片上传失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    var message = _messageCtrl.text.trim();
    if (subject.isEmpty || message.isEmpty && _uploadedImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题和内容不能为空')),
      );
      return;
    }

    // 追加图片 Markdown
    if (_uploadedImageUrls.isNotEmpty) {
      final imgMarkdown =
          _uploadedImageUrls.map((u) => '![image]($u)').join('\n');
      message = message.isEmpty ? imgMarkdown : '$message\n$imgMarkdown';
    }

    setState(() => _isSubmitting = true);
    try {
      final sdk = await ref.read(xboardSdkProvider.future);
      final ok = await sdk.ticket.createTicket(subject, message, _level);
      if (mounted) {
        if (ok) {
          widget.onCreated();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('工单已提交')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('提交失败，请稍后重试')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasImgbb = XBoardConfig.imgbbApiKey.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              Text(l10n.xboardCreateTicket,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 标题输入
          TVDeferredInput(
            borderRadius: BorderRadius.circular(10),
            builder: (context, focusNode, readOnly, showCursor, beginEditing) =>
                TextField(
              focusNode: focusNode,
              readOnly: readOnly,
              showCursor: showCursor,
              onTap: beginEditing,
              controller: _subjectCtrl,
              decoration: InputDecoration(
                labelText: l10n.xboardTicketTitle,
                hintText: l10n.xboardTicketTitleHint,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 内容输入
          TVDeferredInput(
            borderRadius: BorderRadius.circular(10),
            builder: (context, focusNode, readOnly, showCursor, beginEditing) =>
                TextField(
              focusNode: focusNode,
              readOnly: readOnly,
              showCursor: showCursor,
              onTap: beginEditing,
              controller: _messageCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.xboardTicketDescription,
                hintText: l10n.xboardTicketDescriptionHint,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                alignLabelWithHint: true,
              ),
            ),
          ),
          // 图片预览条
          if (_uploadedImageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _uploadedImageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: _uploadedImageUrls[i],
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _uploadedImageUrls.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(6),
                                topRight: Radius.circular(6)),
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // 优先级 + 图片按钮
          Row(
            children: [
              Text(l10n.xboardPriority, style: theme.textTheme.bodyMedium),
              const SizedBox(width: 12),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(l10n.xboardLow)),
                  ButtonSegment(value: 1, label: Text(l10n.xboardMedium)),
                  ButtonSegment(value: 2, label: Text(l10n.xboardHigh)),
                ],
                selected: {_level},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _level = s.first),
              ),
              if (hasImgbb) ...[
                const Spacer(),
                _isUploadingImage
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.image_outlined),
                        tooltip: l10n.xboardUploadImage,
                        onPressed: _pickAndUploadImage,
                      ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // 提交按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.xboardSubmitTicket),
            ),
          ),
        ],
      ),
    );
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
