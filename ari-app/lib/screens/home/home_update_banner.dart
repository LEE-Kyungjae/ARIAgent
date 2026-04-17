import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import '../../services/app_update_service.dart';

class HomeUpdateBanner extends StatelessWidget {
  final AppUpdateInfo update;
  final VoidCallback onUpdatePressed;

  const HomeUpdateBanner({
    super.key,
    required this.update,
    required this.onUpdatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = update.mandatory
        ? Colors.orange.shade200
        : const Color(0xFFA7A1FF);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: update.mandatory
            ? const Color(0xFF3A2316)
            : const Color(0xFF241C42),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update_alt_rounded, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              S.of(context).updateAvailable(update.latestVersion, update.mandatory ? S.of(context).updateMandatory : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onUpdatePressed,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: accentColor,
            ),
            child: Text(
              S.of(context).updateButton,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
