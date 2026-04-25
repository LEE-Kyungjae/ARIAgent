import 'package:flutter/material.dart';
import '../../theme/ari_chat_theme.dart';

class ChatDefaultHeader extends StatelessWidget {
  final String headerTitle;
  final String? contextLabel;
  final AriChatTheme theme;
  final VoidCallback? onReset;
  final String? resetTooltip;

  const ChatDefaultHeader({
    super.key,
    required this.headerTitle,
    required this.contextLabel,
    required this.theme,
    this.onReset,
    this.resetTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final headerText = theme.headerTextColor ?? theme.textMain;
    final useGradient = theme.sendButtonGradient != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.headerColor ?? theme.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: theme.primaryColor.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: useGradient ? theme.sendButtonGradient : null,
              color: useGradient
                  ? null
                  : theme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              boxShadow: useGradient
                  ? [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 19,
              color: useGradient ? Colors.white : theme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerTitle,
                  style: TextStyle(
                    color: headerText,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
                if (contextLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    contextLabel!,
                    style: TextStyle(
                      color: headerText.withValues(alpha: 0.65),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onReset != null) ...[
            Tooltip(
              message: resetTooltip ?? 'Reset session',
              child: InkWell(
                onTap: onReset,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: headerText.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: theme.primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
