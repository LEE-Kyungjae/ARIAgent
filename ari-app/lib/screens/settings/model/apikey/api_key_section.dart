import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/provider_item.dart';
import '../providers_notifier.dart';
import '../../../../l10n/app_localizations.dart';

class ApiKeySection extends StatelessWidget {
  final ProviderItem item;

  const ApiKeySection({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<ProvidersNotifier>();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111122),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: item.apiKeyController,
              obscureText: item.apiKeyObscured,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: S.of(context).modelApiKeyHint,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onTap: () {
                if (item.apiKeyController.text.contains('••')) {
                  item.apiKeyController.clear();
                }
              },
              onChanged: (_) => notifier.markDirty(),
              onSubmitted: (_) => notifier.persist(),
            ),
          ),
          IconButton(
            icon: Icon(
              item.apiKeyObscured ? Icons.visibility_off : Icons.visibility,
              color: Colors.white.withValues(alpha: 0.3),
              size: 16,
            ),
            onPressed: () => item.apiKeyObscured = !item.apiKeyObscured,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => notifier.persist(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 7,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  S.of(context).save,
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
