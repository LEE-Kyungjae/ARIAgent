import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/ari_chat_theme.dart';

class ChatInputArea extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final AriChatTheme theme;
  final String hintText;
  final bool isLoading;
  final VoidCallback? onCancel;
  final Widget Function(
    BuildContext context,
    Widget textField,
    Widget actionButton,
  )? layoutBuilder;
  final Widget Function(
    BuildContext context,
    VoidCallback? onPressed,
    bool isLoading,
  )? actionButtonBuilder;

  const ChatInputArea({
    super.key,
    required this.controller,
    required this.onSend,
    required this.theme,
    this.hintText = 'Type a message...',
    this.isLoading = false,
    this.onCancel,
    this.layoutBuilder,
    this.actionButtonBuilder,
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  late final FocusNode _textFocusNode;
  late final TextInputFormatter _leadingNewlineBlocker;

  @override
  void initState() {
    super.initState();
    _textFocusNode = FocusNode();
    _leadingNewlineBlocker = TextInputFormatter.withFunction((
      oldValue,
      newValue,
    ) {
      final isLeadingNewlineOnly = oldValue.text.trim().isEmpty &&
          newValue.text.trim().isEmpty &&
          newValue.text.contains('\n');
      if (isLeadingNewlineOnly) {
        return oldValue;
      }
      return newValue;
    });
  }

  @override
  void dispose() {
    _textFocusNode.dispose();
    super.dispose();
  }

  void _refocusInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _textFocusNode.requestFocus();
    });
  }

  void _handleSend() {
    widget.onSend();
    widget.controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    _refocusInput();
  }

  @override
  Widget build(BuildContext context) {
    final textField = Focus(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey != LogicalKeyboardKey.enter) {
          return KeyEventResult.ignored;
        }
        if (HardwareKeyboard.instance.isShiftPressed) {
          return KeyEventResult.ignored;
        }

        _handleSend();
        return KeyEventResult.handled;
      },
      child: TextField(
        controller: widget.controller,
        focusNode: _textFocusNode,
        style: TextStyle(color: widget.theme.textMain, fontSize: 13),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: widget.theme.hintColor,
            fontSize: 13,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        minLines: 1,
        maxLines: 3,
        textInputAction: TextInputAction.newline,
        inputFormatters: [_leadingNewlineBlocker],
        onTap: _refocusInput,
        onSubmitted: (_) => _handleSend(),
      ),
    );

    // 한글 IME composition 보호: 컨트롤러 변화에 의한 rebuild 가
    // 액션 버튼 영역에만 닿도록 ValueListenableBuilder 로 좁힘.
    final actionButton = ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        final showCancelAction = widget.isLoading && !hasText;
        final onPressed = showCancelAction ? widget.onCancel : _handleSend;

        if (widget.actionButtonBuilder != null) {
          return widget.actionButtonBuilder!(
              context, onPressed, showCancelAction);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: showCancelAction
                  ? widget.theme.primaryColor.withValues(alpha: 0.5)
                  : widget.theme.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: onPressed,
              icon: Icon(
                showCancelAction ? Icons.stop_rounded : Icons.send_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );

    if (widget.layoutBuilder != null) {
      return widget.layoutBuilder!(context, textField, actionButton);
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: widget.theme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: widget.theme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.theme.borderColor),
              ),
              child: textField,
            ),
          ),
          const SizedBox(width: 12),
          actionButton,
        ],
      ),
    );
  }
}
