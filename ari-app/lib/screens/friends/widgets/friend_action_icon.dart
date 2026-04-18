import 'package:flutter/material.dart';

class FriendActionIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool danger;
  final VoidCallback onTap;

  const FriendActionIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  @override
  State<FriendActionIcon> createState() => _FriendActionIconState();
}

class _FriendActionIconState extends State<FriendActionIcon> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.danger
        ? const Color(0xFFEF4444)
        : const Color(0xFF6C63FF);
    final bg = _hover
        ? baseColor.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.06);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 15,
              color: _hover
                  ? baseColor
                  : Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
