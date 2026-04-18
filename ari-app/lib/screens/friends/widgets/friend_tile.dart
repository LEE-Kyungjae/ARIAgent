import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'friend_action_icon.dart';
import 'friend_avatar.dart';
import 'friend_status_row.dart';

class FriendTile extends StatefulWidget {
  final dynamic agent;
  final bool isActive;
  final bool isSelected;
  final String status;
  final int scheduleCount;
  final DateTime? nextRunAt;
  final VoidCallback onListSelect;
  final VoidCallback onOpenChat;
  final VoidCallback onDelete;

  const FriendTile({
    super.key,
    required this.agent,
    required this.isActive,
    required this.isSelected,
    required this.status,
    required this.scheduleCount,
    required this.nextRunAt,
    required this.onListSelect,
    required this.onOpenChat,
    required this.onDelete,
  });

  @override
  State<FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends State<FriendTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isSelected
        ? const Color(0xFF6C63FF).withValues(alpha: 0.16)
        : _hover
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onListSelect,
        onDoubleTap: widget.onOpenChat,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              FriendAvatar(
                imagePath: widget.agent.imagePath?.toString() ?? '',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.agent.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.88),
                              fontSize: 13.5,
                              fontWeight: widget.isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if ((widget.agent.persona?.toString() ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.agent.persona.toString().trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    FriendStatusRow(
                      status: widget.status,
                      scheduleCount: widget.scheduleCount,
                      nextRunAt: widget.nextRunAt,
                    ),
                  ],
                ),
              ),
              if (widget.isSelected) ...[
                const SizedBox(width: 8),
                FriendActionIcon(
                  icon: Icons.chat_bubble_rounded,
                  tooltip: S.of(context).tabChat,
                  onTap: widget.onOpenChat,
                ),
                const SizedBox(width: 4),
                if (widget.agent.id != 'default')
                  FriendActionIcon(
                    icon: Icons.delete_outline_rounded,
                    tooltip: S.of(context).delete,
                    danger: true,
                    onTap: widget.onDelete,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
