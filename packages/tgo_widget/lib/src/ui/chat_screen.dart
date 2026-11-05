import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/tgo_config.dart';
import '../state/chat_provider.dart';
import '../tgo_widget_impl.dart';
import 'theme/tgo_theme.dart';
import 'widgets/header.dart';
import 'widgets/message_list.dart';
import 'widgets/message_input.dart';
import 'widgets/chat_overlay_host.dart';

/// Main chat screen widget
class ChatScreen extends StatefulWidget {
  final ChatProvider provider;
  final TgoWidgetConfig config;
  final VoidCallback? onClose;
  final bool fullScreen;

  const ChatScreen({
    super.key,
    required this.provider,
    required this.config,
    this.onClose,
    this.fullScreen = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ChatProvider get provider => widget.provider;
  TgoWidgetConfig get config => widget.config;
  bool get fullScreen => widget.fullScreen;
  VoidCallback? get onClose => widget.onClose;

  @override
  void initState() {
    super.initState();
    // Run after mounting so synchronous test/cache results cannot notify while
    // ancestors are building. Each new screen instance refreshes exactly once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        provider.refreshDisplayConfig();
        provider.refreshReadReceipt();
        provider.refreshStaffProfiles();
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: provider,
        builder: (context, _) => _buildChat(context),
      );

  Widget _buildChat(BuildContext context) {
    // Determine theme mode
    final isDark = config.darkMode ??
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    final theme = TgoTheme(
      primaryColor: provider.config.themeColor,
      isDark: isDark,
    );

    // Calculate height for bottom sheet
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = fullScreen ? screenHeight : screenHeight * 0.85;

    Widget content = ChatOverlayHost(
      child: TgoThemeProvider(
        theme: theme,
        child: ChangeNotifierProvider.value(
          value: provider,
          child: Container(
            height: fullScreen ? null : sheetHeight,
            decoration: BoxDecoration(
              color: theme.bgPrimary,
              borderRadius: fullScreen
                  ? null
                  : const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: ClipRRect(
              borderRadius: fullScreen
                  ? BorderRadius.zero
                  : const BorderRadius.vertical(top: Radius.circular(16)),
              child: Scaffold(
                backgroundColor: theme.bgPrimary,
                resizeToAvoidBottomInset: false, // 必须为 false 才能实现无缝切换
                body: GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Column(
                    children: [
                      // Drag handle for bottom sheet
                      if (!fullScreen && !config.embedded)
                        _buildDragHandle(theme),

                      // Header
                      ChatHeader(
                        title: provider.config.title,
                        logoUrl: provider.config.logoUrl,
                        onClose: onClose,
                        showClose: false,
                        soundEnabled: provider.soundEnabled,
                        locale: provider.config.locale ?? 'en',
                        onToggleSound: provider.toggleSound,
                      ),

                      // Message list
                      Expanded(
                        child: MessageList(provider: provider),
                      ),

                      // Bottom area
                      MessageInput(
                        provider: provider,
                        fullScreen: fullScreen,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    {
      content = Theme(
        data: theme.toThemeData(),
        child: content,
      );
    }

    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop) {
          provider.onUIClosed();
        }
      },
      child: content,
    );
  }

  Widget _buildDragHandle(TgoTheme theme) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: theme.borderPrimary,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Embedded chat widget (for inline use)
class TgoWidgetChat extends StatelessWidget {
  final TgoWidgetConfig? config;

  const TgoWidgetChat({
    super.key,
    this.config,
  });

  @override
  Widget build(BuildContext context) {
    // This widget requires TgoWidget to be initialized
    final provider = TgoWidget.chatProvider;
    if (provider == null) {
      return const Center(
        child: Text('TgoWidget not initialized'),
      );
    }

    final cfg = config ?? TgoWidget.config;

    return ChatScreen(
      provider: provider,
      config: cfg,
      fullScreen: true,
    );
  }
}
