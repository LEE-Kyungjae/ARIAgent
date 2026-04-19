import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class HelpSection extends StatelessWidget {
  const HelpSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C63FF).withValues(alpha: 0.1),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFF6C63FF)),
              const SizedBox(width: 8),
              Text(
                S.of(context).helpGuideTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildHelpRow(
            S.of(context).helpOAuthTitle,
            S.of(context).helpOAuth,
          ),
          const SizedBox(height: 10),
          _buildHelpRow(
            S.of(context).helpApiKeyTitle,
            S.of(context).helpApiKey,
          ),
          const SizedBox(height: 10),
          _buildHelpRow(
            S.of(context).helpPriorityTitle,
            S.of(context).helpPriority,
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          Text(
            S.of(context).helpKeyIssue,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            '• OpenAI: [platform.openai.com]\n'
            '• Anthropic: [console.anthropic.com]\n'
            '• Gemini: [aistudio.google.com]',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpRow(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF6C63FF),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
