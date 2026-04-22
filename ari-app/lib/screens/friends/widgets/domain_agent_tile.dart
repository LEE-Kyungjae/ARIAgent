import 'dart:io';

import 'package:ari_plugin/ari_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import 'friend_action_icon.dart';

class DomainAgentTile extends StatefulWidget {
  final Map<String, dynamic> app;
  final bool isConnected;

  const DomainAgentTile({
    super.key,
    required this.app,
    required this.isConnected,
  });

  @override
  State<DomainAgentTile> createState() => _DomainAgentTileState();
}

class _DomainAgentTileState extends State<DomainAgentTile> {
  bool _hover = false;

  Widget _buildIcon() {
    final iconPath = widget.app['iconPath'] as String?;
    final iconName = widget.app['icon'] as String?;
    if (iconPath != null) {
      final file = File(iconPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(file, width: 44, height: 44, fit: BoxFit.cover),
        );
      }
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: iconName != null
            ? Text(iconName, style: const TextStyle(fontSize: 20))
            : Icon(
                Icons.extension_rounded,
                size: 20,
                color: const Color(0xFF6C63FF).withValues(alpha: 0.7),
              ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String appId) async {
    final title = (widget.app['title'] as String?) ?? appId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          S.of(ctx).appsDeleteTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          S.of(ctx).appsDeleteConfirm(title),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              S.of(ctx).cancel,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              S.of(ctx).delete,
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AgentProvider>().deleteApp(appId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appId = widget.app['name'] as String;
    final title = (widget.app['title'] as String?) ?? appId;
    final description = widget.app['description'] as String?;

    final bg = _hover
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
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
            _buildIcon(),
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
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isConnected
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.isConnected
                              ? S.of(context).appsConnected
                              : S.of(context).appsOffline,
                          style: TextStyle(
                            color: widget.isConnected
                                ? const Color(0xFF4CAF50)
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_hover) ...[
              const SizedBox(width: 8),
              if (!widget.isConnected)
                FriendActionIcon(
                  icon: Icons.play_circle_outline_rounded,
                  tooltip: S.of(context).appsOffline,
                  onTap: () =>
                      context.read<AgentProvider>().launchApp(appId),
                ),
              if (!widget.isConnected) const SizedBox(width: 4),
              FriendActionIcon(
                icon: Icons.delete_outline_rounded,
                tooltip: S.of(context).delete,
                danger: true,
                onTap: () => _confirmDelete(context, appId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
