import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../chat/chat_panel.dart';
import '../chat/providers/chat_provider.dart';
import '../theme/ari_chat_theme.dart';
import '../update/widgets/ari_update_banner.dart';
import 'widgets/connection_warning_banner.dart';
import 'widgets/thinking_glow_overlay.dart';

class AriBaseLayout extends StatefulWidget {
  const AriBaseLayout({
    super.key,
    required this.appId,
    required this.appName,
    required this.body,
    this.appBar,
    this.drawer,
    this.backgroundColor,
    this.scaffoldKey,
    this.statusBar,

    // Chat Layout Ops
    this.showChat = false,
    this.chatPanel,

    // Integrated Chat Provider Mode
    this.chatProvider,

    // Individual Chat Options override
    this.onChatSend,
    this.onChatCancel,
    this.chatMessages,
    this.isChatLoading = false,
    this.chatContextLabel,
    this.chatHeaderTitle,
    this.chatHintText,
    this.chatTheme = const AriChatTheme(),
    this.chatFollowUpMessage,
    this.chatFollowUpCount = 0,
    this.chatEmptyStateMessage,

    // BaseLayout 내부 위젯 색상 오버라이드
    this.connectionWarningColor,
    this.updateBannerBackgroundColor,
    this.updateBannerAccentColor,
    this.thinkingGlowColor,

    // Chat header reset button
    this.showChatResetButton = true,
    this.chatAgentId = 'default',
    this.onChatResetOverride,
    this.chatResetDialogTitle,
    this.chatResetDialogMessage,
    this.chatResetConfirmLabel,
    this.chatResetCancelLabel,
    this.chatResetButtonTooltip,
  });

  final String appId;
  final String appName;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Color? backgroundColor;
  final Key? scaffoldKey;
  final Widget? statusBar;

  final AriChatProvider? chatProvider;
  final bool showChat;
  final Widget? chatPanel;

  final Future<void> Function(String)? onChatSend;
  final VoidCallback? onChatCancel;
  final List<AriChatMessage>? chatMessages;
  final bool isChatLoading;
  final String? chatContextLabel;
  final String? chatHeaderTitle;
  final String? chatHintText;
  final AriChatTheme chatTheme;
  final String? chatFollowUpMessage;
  final int chatFollowUpCount;
  final String? chatEmptyStateMessage;

  final Color? connectionWarningColor;
  final Color? updateBannerBackgroundColor;
  final Color? updateBannerAccentColor;
  final Color? thinkingGlowColor;

  final bool showChatResetButton;
  final String chatAgentId;
  final Future<void> Function()? onChatResetOverride;
  final String? chatResetDialogTitle;
  final String? chatResetDialogMessage;
  final String? chatResetConfirmLabel;
  final String? chatResetCancelLabel;
  final String? chatResetButtonTooltip;

  @override
  State<AriBaseLayout> createState() => _AriBaseLayoutState();
}

class _AriBaseLayoutState extends State<AriBaseLayout> {
  double _chatWidth = 360;
  static const double _minChatWidth = 240.0;
  static const double _maxChatWidthRatio = 0.6;

  @override
  Widget build(BuildContext context) {
    final maxChatWidth = MediaQuery.of(context).size.width * _maxChatWidthRatio;
    final themeBackground = Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      children: [
        Scaffold(
          key: widget.scaffoldKey,
          drawer: widget.drawer,
          backgroundColor: widget.backgroundColor ?? themeBackground,
          body: SafeArea(
            child: Column(
              children: [
                ConnectionWarningBanner(
                  backgroundColor: widget.connectionWarningColor,
                ),
                AriUpdateBanner(
                  appId: widget.appId,
                  appName: widget.appName,
                  backgroundColor: widget.updateBannerBackgroundColor,
                  accentColor: widget.updateBannerAccentColor,
                ),
                Expanded(
                  child: Row(
                    children: [
                      // Left Side: Header + Content
                      Expanded(
                        child: Column(
                          children: [
                            if (widget.appBar != null)
                              SizedBox(
                                height: widget.appBar!.preferredSize.height,
                                child: widget.appBar!,
                              ),
                            Expanded(child: widget.body),
                          ],
                        ),
                      ),
                      // Right Side: Chat Panel
                      if (widget.showChat) ...[
                        // Resize Handle
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _chatWidth = (_chatWidth - details.delta.dx).clamp(
                                _minChatWidth,
                                maxChatWidth,
                              );
                            });
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeLeftRight,
                            child: Container(
                              width: 1,
                              height: double.infinity,
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                        // Chat Panel Area
                        SizedBox(
                          width: _chatWidth,
                          child: _buildChatPanel(),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.statusBar != null) widget.statusBar!,
              ],
            ),
          ),
        ),
        // AI Thinking Glow Effect
        _buildThinkingEffect(),
      ],
    );
  }

  Widget _buildThinkingEffect() {
    final isLoading = widget.chatProvider != null
        ? widget.chatProvider!.isLoading
        : widget.isChatLoading;

    final glowColor =
        widget.thinkingGlowColor ?? widget.chatTheme.primaryColor;

    if (widget.chatProvider != null) {
      return ListenableBuilder(
        listenable: widget.chatProvider!,
        builder: (context, _) => ThinkingGlowOverlay(
          isLoading: widget.chatProvider!.isLoading,
          color: glowColor,
        ),
      );
    }

    return ThinkingGlowOverlay(
      isLoading: isLoading,
      color: glowColor,
    );
  }

  Widget _buildChatPanel() {
    if (widget.chatPanel != null) return widget.chatPanel!;

    final headerTitle = widget.chatHeaderTitle ?? 'ARI Assistant';
    final hintText = widget.chatHintText ?? 'Type a message...';

    final p = widget.chatProvider;
    if (p != null) {
      // 앱이 자기 AriChatProvider 를 주입한 경우: value 로 내려보내서
      // AriChatPanel 이 internal 모드로 `items` getter 를 그대로 쓰게 한다.
      return ChangeNotifierProvider<AriChatProvider>.value(
        value: p,
        child: AriChatPanel(
          appId: widget.appId,
          onSend: widget.onChatSend ??
              (text) => p.sendAgentMessage(text, appId: widget.appId),
          onCancel: widget.onChatCancel ?? p.cancelAgentMessage,
          contextLabel: widget.chatContextLabel,
          headerTitle: headerTitle,
          hintText: hintText,
          theme: widget.chatTheme,
          emptyStateMessage: widget.chatEmptyStateMessage,
          showResetButton: widget.showChatResetButton,
          resetAgentId: widget.chatAgentId,
          onResetOverride: widget.onChatResetOverride,
          resetDialogTitle: widget.chatResetDialogTitle,
          resetDialogMessage: widget.chatResetDialogMessage,
          resetConfirmLabel: widget.chatResetConfirmLabel,
          resetCancelLabel: widget.chatResetCancelLabel,
          resetButtonTooltip: widget.chatResetButtonTooltip,
        ),
      );
    }

    return AriChatPanel(
      appId: widget.appId,
      onSend: widget.onChatSend,
      onCancel: widget.onChatCancel,
      messages: widget.chatMessages,
      isLoading: widget.isChatLoading,
      contextLabel: widget.chatContextLabel,
      headerTitle: headerTitle,
      hintText: hintText,
      theme: widget.chatTheme,
      followUpMessage: widget.chatFollowUpMessage,
      followUpCount: widget.chatFollowUpCount,
      emptyStateMessage: widget.chatEmptyStateMessage,
      showResetButton: widget.showChatResetButton,
      resetAgentId: widget.chatAgentId,
      onResetOverride: widget.onChatResetOverride,
      resetDialogTitle: widget.chatResetDialogTitle,
      resetDialogMessage: widget.chatResetDialogMessage,
      resetConfirmLabel: widget.chatResetConfirmLabel,
      resetCancelLabel: widget.chatResetCancelLabel,
      resetButtonTooltip: widget.chatResetButtonTooltip,
    );
  }
}



