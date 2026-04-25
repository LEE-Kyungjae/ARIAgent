import 'package:flutter/material.dart';
import '../../sessions/models/ari_work_session.dart';
import '../../sessions/widgets/ari_work_session_card.dart';
import '../../theme/ari_chat_theme.dart';
import '../models/ari_chat_item.dart';
import '../models/ari_chat_message.dart';
import 'chat_empty_state.dart';
import 'chat_message_item.dart';

class ChatMessageViewport extends StatelessWidget {
  final List<AriChatItem> items;
  final AriChatTheme theme;
  final bool reverseMessages;
  final ScrollController scrollController;
  final Widget? overlayWidget;
  final Widget? emptyStateWidget;
  final String? emptyStateMessage;
  final Widget Function(AriChatMessage)? messageBubbleBuilder;
  final bool showScrollToBottomButton;
  final VoidCallback onScrollToBottom;
  final double listBottomPadding;

  const ChatMessageViewport({
    super.key,
    required this.items,
    required this.theme,
    required this.reverseMessages,
    required this.scrollController,
    required this.overlayWidget,
    required this.emptyStateWidget,
    required this.emptyStateMessage,
    required this.messageBubbleBuilder,
    required this.showScrollToBottomButton,
    required this.onScrollToBottom,
    this.listBottomPadding = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned.fill(
          child: overlayWidget != null
              ? overlayWidget!
              : Container(
                  color: theme.backgroundColor,
                  child: items.isEmpty
                      ? (emptyStateWidget ??
                          ChatEmptyState(
                            theme: theme,
                            message: emptyStateMessage ?? 'How can I help you?',
                          ))
                      : ListView.builder(
                          controller: scrollController,
                          reverse: reverseMessages,
                          padding: EdgeInsets.fromLTRB(
                            20,
                            20,
                            20,
                            listBottomPadding,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = reverseMessages
                                ? items[items.length - 1 - index]
                                : items[index];
                            return _buildItem(item);
                          },
                        ),
                ),
        ),
        Positioned(
          bottom: listBottomPadding - 8,
          child: AnimatedSlide(
            offset:
                showScrollToBottomButton ? Offset.zero : const Offset(0, 0.35),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: showScrollToBottomButton ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !showScrollToBottomButton,
                child: GestureDetector(
                  onTap: onScrollToBottom,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withValues(alpha: 0.24),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItem(AriChatItem item) {
    if (item is AriChatMessage) {
      return messageBubbleBuilder != null
          ? messageBubbleBuilder!(item)
          : AriChatMessageItem(message: item, theme: theme);
    }
    if (item is AriWorkSession) {
      return AriWorkSessionCard(session: item, theme: theme);
    }
    return const SizedBox.shrink();
  }
}
