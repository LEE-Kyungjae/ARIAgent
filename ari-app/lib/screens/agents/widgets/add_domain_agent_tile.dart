import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'agent_store_sheet.dart';

class AddDomainAgentTile extends StatefulWidget {
  final bool compact;
  const AddDomainAgentTile({super.key, this.compact = false});

  @override
  State<AddDomainAgentTile> createState() => _AddDomainAgentTileState();
}

class _AddDomainAgentTileState extends State<AddDomainAgentTile> {
  bool _hover = false;

  void _openStore() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AgentStoreSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openStore,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hover
                ? const Color(0xFF6C63FF).withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(compact ? 14 : 20),
            border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.storefront_rounded,
                color: const Color(0xFF6C63FF),
                size: compact ? 13 : 16,
              ),
              SizedBox(width: compact ? 4 : 6),
              Text(
                S.of(context).addDomainAgent,
                style: TextStyle(
                  color: const Color(0xFF6C63FF),
                  fontSize: compact ? 10.5 : 12.5,
                  fontWeight: FontWeight.w600,
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
