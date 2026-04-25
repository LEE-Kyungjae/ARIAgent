import 'dart:ui' show ImageFilter;

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

class _SendMessageIntent extends Intent {
  const _SendMessageIntent();
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
    final theme = widget.theme;
    final inputTextColor = theme.inputTextColor ?? theme.textMain;
    final inputHintColor = theme.inputHintColor ?? theme.hintColor;
    final inputBorderColor = theme.inputBorderColor ?? theme.borderColor;

    // 한글 IME 보호: Focus.onKeyEvent 로 모든 KeyDown 을 가로채면 macOS IME 의
    // marked text 처리가 깨져 자모가 분해 입력됨 (ㅇㅏㄴㄴㅕㅇ).
    // Shortcuts 는 매칭된 키 조합만 인터셉트하므로 일반 입력은 IME 로 그대로 전달.
    // shift+enter 는 SingleActivator 가 매칭 안 함 → 기본 동작 (줄바꿈) 유지.
    final textField = Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): _SendMessageIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SendMessageIntent: CallbackAction<_SendMessageIntent>(
            onInvoke: (_) {
              // IME 조합 중인 enter 는 한글 확정용 — 무시.
              if (widget.controller.value.composing.isValid) return null;
              _handleSend();
              return null;
            },
          ),
        },
        child: TextField(
          controller: widget.controller,
          focusNode: _textFocusNode,
          style: TextStyle(color: inputTextColor, fontSize: 13),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: inputHintColor,
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

        final useGradient =
            theme.sendButtonGradient != null && !showCancelAction;

        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: useGradient ? theme.sendButtonGradient : null,
              color: useGradient
                  ? null
                  : (showCancelAction
                      ? theme.primaryColor.withValues(alpha: 0.5)
                      : theme.primaryColor),
              borderRadius: BorderRadius.circular(14),
              boxShadow: useGradient
                  ? [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
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

    final areaIsOpaque = theme.inputAreaColor.a > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.inputAreaColor,
        boxShadow: areaIsOpaque
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, -5),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: inputBorderColor,
                        width: theme.borderWidth,
                      ),
                    ),
                    child: textField,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          actionButton,
        ],
      ),
    );
  }
}
