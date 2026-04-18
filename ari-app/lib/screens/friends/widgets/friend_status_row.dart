import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../friends_schedule.dart';

class FriendStatusRow extends StatelessWidget {
  final String status;
  final int scheduleCount;
  final DateTime? nextRunAt;

  const FriendStatusRow({
    super.key,
    required this.status,
    required this.scheduleCount,
    required this.nextRunAt,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final String label;
    final Color dotColor;
    switch (status) {
      case 'working':
        label = l10n.placeWorking;
        dotColor = const Color(0xFF6C63FF);
        break;
      case 'idle':
        label = l10n.placeIdle;
        dotColor = const Color(0xFF4ADE80);
        break;
      case 'resting':
      default:
        label = l10n.placeResting;
        dotColor = Colors.white.withValues(alpha: 0.35);
        break;
    }
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (scheduleCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 10,
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.9),
                ),
                const SizedBox(width: 3),
                Text(
                  nextRunAt != null
                      ? '$scheduleCount · ${formatUntil(nextRunAt!)}'
                      : '$scheduleCount',
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
