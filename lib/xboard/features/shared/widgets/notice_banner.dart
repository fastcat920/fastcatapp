import 'dart:async';
import 'dart:io';
import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_clash/xboard/features/notice/notice.dart';
import '../styles/markdown_styles.dart';
import '../styles/html_styles.dart';

/// 通知内容渲染类型
enum NoticeRenderType {
  /// Markdown 渲染
  markdown,

  /// HTML 渲染
  html,
}

/// 全局配置：选择通知内容的渲染方式
///
/// 可选值：
/// - null: 自动检测内容格式（默认，推荐）
/// - NoticeRenderType.markdown: 强制使用 Markdown 渲染
/// - NoticeRenderType.html: 强制使用 HTML 渲染
///
/// 设置为 null 时，程序会自动判断内容是 HTML 还是 Markdown
const NoticeRenderType? kNoticeRenderType = null;

class NoticeBanner extends ConsumerStatefulWidget {
  const NoticeBanner({super.key});
  @override
  ConsumerState<NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends ConsumerState<NoticeBanner>
    with TickerProviderStateMixin {
  @override
  void activate() {
    super.activate();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  Timer? _autoScrollTimer;
  int _currentIndex = 0;
  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(noticeProvider.notifier).fetchNotices();
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  void _startAutoScroll(List<String> notices) {
    if (notices.isEmpty) return;
    _autoScrollTimer?.cancel();
    if (notices.length == 1) {
      _slideController.forward();
      return;
    }
    _slideController.forward();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        _slideToNext(notices.length);
      }
    });
  }

  void _slideToNext(int totalCount) {
    _slideController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % totalCount;
        });
        _slideController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final noticeState = ref.watch(noticeProvider);
    if (noticeState.isLoading || noticeState.visibleNotices.isEmpty) {
      return const SizedBox.shrink();
    }
    final notices =
        noticeState.visibleNotices.map((notice) => notice.title).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll(notices);
    });
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Platform.isWindows ||
        Platform.isLinux ||
        Platform.isMacOS ||
        system.isTV;

    final double bannerHeight = isDesktop ? 48 : 40;
    final double hMargin = isDesktop ? 4 : 16;
    final double vMargin = isDesktop ? 6 : 8;
    final double iconSize = isDesktop ? 20 : 18;
    final TextStyle? textStyle = isDesktop
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              overflow: TextOverflow.ellipsis,
            )
        : Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              overflow: TextOverflow.ellipsis,
            );

    return Container(
      height: bannerHeight,
      margin: EdgeInsets.symmetric(horizontal: hMargin, vertical: vMargin),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 12 : 20),
        border: Border.all(
          color: isDark
              ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)
              : const Color(0xFFBBDEFB),
          width: 1,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .shadow
                      .withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.campaign_rounded,
              size: iconSize,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _showNoticeDialog(),
              child: ClipRect(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    height: bannerHeight,
                    alignment: Alignment.centerLeft,
                    child: notices.isEmpty
                        ? const SizedBox.shrink()
                        : MarkdownBody(
                            data: notices[_currentIndex % notices.length],
                            styleSheet: MarkdownStyleSheet(
                              p: textStyle,
                              textAlign: WrapAlignment.start,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          // 关闭按钮：仅当只有一条可见公告时显示（多条时用对话框管理）
          if (noticeState.visibleNotices.length == 1)
            SizedBox(
              width: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                tooltip: '关闭',
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: () {
                  final id = noticeState.visibleNotices.first.id;
                  ref.read(noticeProvider.notifier).dismissBanner(id);
                },
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  void _showNoticeDialog() {
    final noticeState = ref.read(noticeProvider);
    if (noticeState.visibleNotices.isEmpty) return;

    // 在打开对话框前移除焦点
    FocusScope.of(context).unfocus();

    showDialog(
      context: context,
      builder: (context) => NoticeDetailDialog(
        notices: noticeState.visibleNotices,
        initialIndex: _currentIndex,
        onPageChanged: (index) {
          // 更新当前索引以便外部知道
        },
      ),
    ).then((_) {
      // 对话框关闭后也确保移除焦点
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    });
  }
}

class NoticeDetailDialog extends StatefulWidget {
  final List<dynamic> notices;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onDismiss;

  const NoticeDetailDialog({
    super.key,
    required this.notices,
    this.initialIndex = 0,
    this.onPageChanged,
    this.onDismiss,
  });

  @override
  State<NoticeDetailDialog> createState() => _NoticeDetailDialogState();
}

class _NoticeDetailDialogState extends State<NoticeDetailDialog>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  dynamic get _currentNotice => widget.notices[_currentIndex];

  Widget _buildDismissButton() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainer
            : Colors.white,
        border: Border(
          top: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton(
            onPressed: () {
              widget.onDismiss?.call();
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(l10n.xboardGotIt, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.notices.length - 1);
    widget.onPageChanged?.call(_currentIndex);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          Future.microtask(() {
            if (context.mounted) {
              FocusScope.of(context).unfocus();
            }
          });
        }
      },
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: screenWidth > 600 ? 560 : double.infinity,
              maxHeight: screenHeight * 0.82,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.3)
                    : Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.1),
                width: isDark ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.1),
                  blurRadius: isDark ? 30 : 20,
                  spreadRadius: isDark ? 2 : 0,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: isDark ? 0.15 : 0.05),
                  blurRadius: 40,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  Flexible(child: _buildSingleNotice()),
                  _buildDismissButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = _currentNotice.title ?? '无标题';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainer
            : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: isDark ? 0.2 : 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                FocusScope.of(context).unfocus();
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Icon(
                  Icons.close_rounded,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleNotice() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: _buildNoticeContent(_currentNotice),
    );
  }

  Widget _buildNoticeContent(dynamic notice) {
    String formatTime(dynamic timeValue) {
      if (timeValue == null) return '未知时间';
      try {
        DateTime dateTime;
        if (timeValue is DateTime) {
          dateTime = timeValue;
        } else if (timeValue is int) {
          final timestamp =
              timeValue > 1000000000000 ? timeValue : timeValue * 1000;
          dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else if (timeValue is String) {
          dateTime = DateTime.parse(timeValue);
        } else {
          return timeValue.toString();
        }
        dateTime = dateTime.toLocal();
        return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      } catch (e) {
        return timeValue.toString();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时间信息
        if (notice.createdAt != null || notice.updatedAt != null) ...[
          Text(
            formatTime(notice.createdAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
          const SizedBox(height: 12),
        ],

        // 内容区域 - 根据配置选择渲染方式
        _buildContentWidget(notice),
      ],
    );
  }

  /// 根据配置构建内容Widget（Markdown或HTML）
  Widget _buildContentWidget(dynamic notice) {
    final content = notice.content ?? '暂无内容';

    // 如果配置为 null，自动检测内容格式
    final renderType = kNoticeRenderType ?? _detectContentType(content);

    switch (renderType) {
      case NoticeRenderType.markdown:
        return _buildMarkdownContent(content);
      case NoticeRenderType.html:
        return _buildHtmlContent(content);
    }
  }

  /// 自动检测内容类型
  ///
  /// 通过检查内容中是否包含 HTML 标签来判断：
  /// - 如果包含常见的 HTML 标签，认为是 HTML
  /// - 否则认为是 Markdown
  NoticeRenderType _detectContentType(String content) {
    // 去除首尾空白
    final trimmedContent = content.trim();

    // 如果内容为空，默认使用 Markdown
    if (trimmedContent.isEmpty) {
      return NoticeRenderType.markdown;
    }

    // 常见的 HTML 标签模式
    final htmlTagPattern = RegExp(
      r'<(p|div|span|h[1-6]|ul|ol|li|br|hr|strong|em|a|img|table|tr|td|th|blockquote|pre|code)[>\s]',
      caseSensitive: false,
    );

    // 如果匹配到 HTML 标签，使用 HTML 渲染
    if (htmlTagPattern.hasMatch(trimmedContent)) {
      return NoticeRenderType.html;
    }

    // 默认使用 Markdown 渲染
    return NoticeRenderType.markdown;
  }

  /// 构建Markdown内容
  Widget _buildMarkdownContent(String content) {
    return MarkdownBody(
      data: _processMarkdownForDialog(content),
      styleSheet: NoticeMarkdownStyles.getNoticeContentStyle(context),
      onTapLink: (text, href, title) => _handleLinkTap(href),
    );
  }

  /// 构建HTML内容
  Widget _buildHtmlContent(String content) {
    return NoticeHtmlStyles.buildNoticeHtml(
      context: context,
      htmlContent: _processHtmlForDialog(content),
      onTapUrl: (url) => _handleLinkTap(url),
    );
  }

  String _processMarkdownForDialog(String markdownText) {
    return markdownText.trim();
  }

  String _processHtmlForDialog(String htmlText) {
    return htmlText.trim();
  }

  /// 处理Markdown/HTML中的链接点击
  void _handleLinkTap(String? href) async {
    if (href == null || href.isEmpty) return;

    try {
      final uri = Uri.parse(href);

      // 检查是否可以启动该链接
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // 在外部浏览器打开
        );
      } else {
        // 如果无法打开，显示提示
        if (mounted) {
          XBoardNotification.showError('无法打开链接: $href');
        }
      }
    } catch (e) {
      // 处理无效URL或其他错误
      if (mounted) {
        XBoardNotification.showError('链接格式错误: $href');
      }
    }
  }
}
