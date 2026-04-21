import 'package:flutter/material.dart';
import '../provider_meta.dart';
import '../../../../l10n/app_localizations.dart';

class ApiKeySection extends StatefulWidget {
  final ProviderItem item;
  final VoidCallback onSave;
  final VoidCallback onMarkDirty;

  const ApiKeySection({
    super.key,
    required this.item,
    required this.onSave,
    required this.onMarkDirty,
  });

  @override
  State<ApiKeySection> createState() => _ApiKeySectionState();
}

class _ApiKeySectionState extends State<ApiKeySection> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
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
              onChanged: (_) => widget.onMarkDirty(),
              onSubmitted: (_) => widget.onSave(),
            ),
          ),
          IconButton(
            icon: Icon(
              item.apiKeyObscured ? Icons.visibility_off : Icons.visibility,
              color: Colors.white.withValues(alpha: 0.3),
              size: 16,
            ),
            onPressed: () {
              setState(() => item.apiKeyObscured = !item.apiKeyObscured);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: widget.onSave,
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
