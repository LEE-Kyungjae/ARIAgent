import 'package:flutter/material.dart';
import '../../theme/ari_chat_theme.dart';

class ChatEmptyState extends StatelessWidget {
  final AriChatTheme theme;
  final String message;
  final IconData icon;

  const ChatEmptyState({
    super.key,
    required this.theme,
    this.message = 'How can I help you?',
    this.icon = Icons.forum_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final iconBg = theme.emptyStateIconBackgroundColor ??
        theme.primaryColor.withValues(alpha: 0.05);
    final iconColor = theme.emptyStateIconColor ??
        theme.primaryColor.withValues(alpha: 0.3);
    final textColor = theme.emptyStateTextColor ?? theme.textMain;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
