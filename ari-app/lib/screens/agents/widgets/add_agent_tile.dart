import 'package:ari_plugin/ari_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';

class AddAgentTile extends StatefulWidget {
  final bool compact;
  const AddAgentTile({super.key, this.compact = false});

  @override
  State<AddAgentTile> createState() => _AddAgentTileState();
}

class _AddAgentTileState extends State<AddAgentTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final id = 'agent_${DateTime.now().millisecondsSinceEpoch}';
          await context.read<AgentProvider>().createAndSwitchAvatar(
            id,
            S.of(context).defaultAvatarName,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(compact ? 14 : 20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: compact ? 13 : 16,
              ),
              SizedBox(width: compact ? 4 : 6),
              Text(
                S.of(context).newAvatar,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: compact ? 10.5 : 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (compact) return button;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(child: button),
    );
  }
}
