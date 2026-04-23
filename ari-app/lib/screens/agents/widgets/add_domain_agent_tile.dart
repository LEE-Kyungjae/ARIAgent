import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'agent_store_sheet.dart';

class AddDomainAgentTile extends StatefulWidget {
  const AddDomainAgentTile({super.key});

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openStore,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _hover
                    ? const Color(0xFF6C63FF).withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xFF6C63FF),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    S.of(context).addDomainAgent,
                    style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
