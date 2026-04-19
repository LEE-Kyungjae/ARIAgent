import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class ChatSuggestions extends StatelessWidget {
  final Function(String) onSuggestionTap;
  final bool isSetupMode;

  const ChatSuggestions({
    super.key,
    required this.onSuggestionTap,
    this.isSetupMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final List<String> chips = isSetupMode
        ? <String>[
            s.chatSuggestionSetupGreet,
            s.chatSuggestionSetupHowto,
            s.chatSuggestionSetupApiKey,
            s.chatSuggestionSetupCheapest,
            s.chatSuggestionSetupChatgpt,
            s.chatSuggestionSetupOauth,
          ]
        : <String>[
            s.chatSuggestionNormalGreet,
            s.chatSuggestionNormalDisk,
            s.chatSuggestionNormalFile,
            s.chatSuggestionNormalRemind,
            s.chatSuggestionNormalMusic,
            s.chatSuggestion1,
            s.chatSuggestion2,
          ];

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: chips.map(_suggestionChip).toList(),
      ),
    );
  }

  Widget _suggestionChip(String text) {
    return GestureDetector(
      onTap: () => onSuggestionTap(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
