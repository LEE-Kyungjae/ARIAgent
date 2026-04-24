import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../bridge/agent/AriAgent.dart';
import '../../theme/ari_chat_theme.dart';
import '../providers/chat_provider.dart';
import 'chat_default_header.dart';
import 'chat_follow_up_banner.dart';
import 'chat_input_area.dart';
import 'chat_message_viewport.dart';

class AriChatPanelBody extends StatefulWidget {
  final String appId;
  final String? contextLabel;
  final String headerTitle;
  final List<AriChatMessage>? externalMessages;
  final Future<void> Function(String)? onSendExternal;
  final VoidCallback? onCancel;
  final bool externalIsLoading;
  final String? externalFollowUpMessage;
  final int externalFollowUpCount;
  final String hintText;
  final AriChatTheme theme;
  final bool reverseMessages;
  final WidgetBuilder? headerBuilder;
  final Widget? overlayWidget;
  final Widget Function(AriChatMessage)? messageBubbleBuilder;
  final Widget? emptyStateWidget;
  final String? emptyStateMessage;
  final Widget Function(
    Future<void> Function(String) onSend,
    VoidCallback? onCancel,
    bool isLoading,
  )? inputAreaBuilder;
  final double followUpBannerTopOffset;
  final bool isExternalMode;
  final String Function(int count)? followUpSummaryBuilder;

  const AriChatPanelBody({
    super.key,
    required this.appId,
    required this.contextLabel,
    required this.headerTitle,
    required this.externalMessages,
    required this.onSendExternal,
    required this.onCancel,
    required this.externalIsLoading,
    required this.externalFollowUpMessage,
    required this.externalFollowUpCount,
    required this.hintText,
    required this.theme,
    required this.reverseMessages,
    required this.headerBuilder,
    required this.overlayWidget,
    required this.messageBubbleBuilder,
    required this.emptyStateWidget,
    required this.emptyStateMessage,
    required this.inputAreaBuilder,
    required this.followUpBannerTopOffset,
    required this.isExternalMode,
    this.followUpSummaryBuilder,
  });

  @override
  State<AriChatPanelBody> createState() => _AriChatPanelBodyState();
}

class _AriChatPanelBodyState extends State<AriChatPanelBody> {
  static const double _scrollToBottomThreshold = 120;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  AriChatProvider? _internalProvider;
  bool _showScrollToBottomButton = false;

  bool get _isLoading => widget.isExternalMode
      ? widget.externalIsLoading
      : (_internalProvider?.isLoading ?? false);

  VoidCallback? get _cancelHandler => widget.isExternalMode
      ? widget.onCancel
      : () => _internalProvider?.cancelAgentMessage();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScrollChanged);
    if (!widget.isExternalMode) {
      _internalProvider = context.read<AriChatProvider>();
      _lastMessageCount = _internalProvider!.items.length;
      _internalProvider!.addListener(_onMessagesChanged);
    } else {
      _lastMessageCount = widget.externalMessages!.length;
    }
  }

  @override
  void didUpdateWidget(AriChatPanelBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExternalMode) {
      final newCount = widget.externalMessages!.length;
      if (newCount > _lastMessageCount) {
        _lastMessageCount = newCount;
        _scrollToBottom();
      }
    }
  }

  @override
  void dispose() {
    _internalProvider?.removeListener(_onMessagesChanged);
    _scrollController.removeListener(_handleScrollChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessagesChanged() {
    if (!mounted) return;
    final provider = _internalProvider!;
    final items = provider.items;
    if (items.length > _lastMessageCount) {
      final wasPrepend = provider.isLoadingOlderHistory;
      final wasEmpty = _lastMessageCount == 0;
      _lastMessageCount = items.length;
      if (!wasPrepend) _scrollToBottom(immediate: wasEmpty);
    }
  }

  // inputAreaBuilder에서 호출하는 외부용 — 텍스트를 직접 전달
  Future<void> _sendText(String text) async {
    _controller.text = text;
    await _sendMessage();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (widget.isExternalMode) {
      _controller.clear();
      _scrollToBottom();
      await widget.onSendExternal!(text);
    } else {
      if (!AriAgent.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The AI agent is not connected.')),
        );
        return;
      }
      _controller.clear();
      _scrollToBottom();
      await _internalProvider?.sendAgentMessage(
        text,
        appId: widget.appId,
      );
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    // 항상 다음 프레임(레이아웃 완료 후)에 스크롤한다.
    // 히스토리 초기 로드처럼 비동기로 아이템이 들어올 때,
    // 즉시 실행하면 ListView 가 아직 새 아이템을 렌더하기 전이라 maxScrollExtent 가 stale.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final target = widget.reverseMessages
          ? _scrollController.position.minScrollExtent
          : _scrollController.position.maxScrollExtent;

      if (immediate) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _handleScrollChanged() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final distanceFromBottom = widget.reverseMessages
        ? (position.pixels - position.minScrollExtent).abs()
        : (position.maxScrollExtent - position.pixels).abs();
    final shouldShow = distanceFromBottom > _scrollToBottomThreshold;

    if (shouldShow != _showScrollToBottomButton && mounted) {
      setState(() {
        _showScrollToBottomButton = shouldShow;
      });
    }

    // 상단 근처 → 더 오래된 히스토리 페이지 로드
    if (!widget.isExternalMode) {
      final distanceFromTop = widget.reverseMessages
          ? (position.maxScrollExtent - position.pixels).abs()
          : (position.pixels - position.minScrollExtent).abs();
      if (distanceFromTop < 80) {
        _internalProvider?.loadOlderHistory();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<AriChatItem> items = widget.isExternalMode
        ? List<AriChatItem>.from(widget.externalMessages!)
        : context.watch<AriChatProvider>().items;
    final provider =
        widget.isExternalMode ? null : context.watch<AriChatProvider>();
    final theme = widget.theme;
    final followUpMessage = widget.isExternalMode
        ? widget.externalFollowUpMessage
        : provider?.latestFollowUpMessage;
    final followUpCount = widget.isExternalMode
        ? widget.externalFollowUpCount
        : (provider?.queuedFollowUpCount ?? 0);
    final inputArea = widget.inputAreaBuilder != null
        ? widget.inputAreaBuilder!(
            _sendText,
            _cancelHandler,
            _isLoading,
          )
        : ChatInputArea(
            controller: _controller,
            onSend: _sendMessage,
            theme: theme,
            hintText: widget.hintText,
            isLoading: _isLoading,
            onCancel: _cancelHandler,
          );

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        border: theme.borderWidth > 0
            ? Border(
                left: BorderSide(
                    color: theme.borderColor, width: theme.borderWidth))
            : null,
      ),
      child: Column(
        children: [
          // ── 헤더 ──────────────────────────────────────────────────────────
          widget.headerBuilder != null
              ? widget.headerBuilder!(context)
              : ChatDefaultHeader(
                  headerTitle: widget.headerTitle,
                  contextLabel: widget.contextLabel,
                  theme: theme,
                ),

          // ── 메시지 영역 ────────────────────────────────────────────────────
          Expanded(
            child: ChatMessageViewport(
              items: items,
              theme: theme,
              reverseMessages: widget.reverseMessages,
              scrollController: _scrollController,
              overlayWidget: widget.overlayWidget,
              emptyStateWidget: widget.emptyStateWidget,
              emptyStateMessage: widget.emptyStateMessage,
              messageBubbleBuilder: widget.messageBubbleBuilder,
              showScrollToBottomButton: _showScrollToBottomButton,
              onScrollToBottom: () => _scrollToBottom(immediate: true),
            ),
          ),

          // ── 입력창 ─────────────────────────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              inputArea,
              if (followUpMessage != null && followUpMessage.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  top: widget.followUpBannerTopOffset,
                  child: IgnorePointer(
                    ignoring: true,
                    child: AnimatedSlide(
                      offset: Offset.zero,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: 1,
                        duration: const Duration(milliseconds: 180),
                        child: ChatFollowUpBanner(
                          theme: theme,
                          message: followUpMessage,
                          count: followUpCount,
                          summaryBuilder: widget.followUpSummaryBuilder,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
