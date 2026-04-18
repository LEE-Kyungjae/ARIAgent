import 'package:ari_plugin/ari_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../place/providers/place_agent_status_provider.dart';
import 'friends_schedule.dart';
import 'widgets/add_friend_tile.dart';
import 'widgets/friend_tile.dart';
import 'widgets/friends_header.dart';

class FriendsTab extends StatefulWidget {
  final VoidCallback onOpenChat;

  const FriendsTab({super.key, required this.onOpenChat});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = AgentProvider().currentAvatarId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AgentProvider().refreshAvatars();
      AgentProvider().refreshTasks();
    });
  }

  Future<void> _confirmDelete(BuildContext context, dynamic agent) async {
    final agentProv = context.read<AgentProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2A),
        title: Text(
          S.of(ctx).settingsDeleteAvatar,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          S.of(ctx).settingsDeleteAvatarConfirm(agent.name.toString()),
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
    if (confirmed == true) {
      if (agentProv.currentAvatarId != agent.id) {
        await agentProv.switchAvatar(agent.id);
      }
      await agentProv.deleteAvatar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentProv = context.watch<AgentProvider>();
    final statusProv = context.watch<PlaceAgentStatusProvider>();
    final agents = agentProv.allAvatars;
    final currentId = agentProv.currentAvatarId;

    return Column(
      children: [
        FriendsHeader(count: agents.length),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: agents.length + 1,
            separatorBuilder: (_, index) {
              if (index >= agents.length - 1) return const SizedBox(height: 8);
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              );
            },
            itemBuilder: (context, index) {
              if (index == agents.length) {
                return const AddFriendTile();
              }
              final agent = agents[index];
              final isActive = agent.id == currentId;
              final isSelected = agent.id == _selectedId;
              final allTasks = agent.tasks.toList();
              final enabledTasks = allTasks
                  .where((t) => t.enabled)
                  .toList();
              final now = DateTime.now();
              final nextRun = enabledTasks
                  .map((t) => nextRunOf(t, now))
                  .whereType<DateTime>()
                  .fold<DateTime?>(
                    null,
                    (a, b) => a == null || b.isBefore(a) ? b : a,
                  );
              return FriendTile(
                agent: agent,
                isActive: isActive,
                isSelected: isSelected,
                status: statusProv.statusFor(
                  agent.id.toString(),
                  isSelected: isActive,
                ),
                scheduleCount: allTasks.length,
                nextRunAt: nextRun,
                onListSelect: () =>
                    setState(() => _selectedId = agent.id.toString()),
                onOpenChat: () {
                  context.read<AgentProvider>().switchAvatar(agent.id);
                  widget.onOpenChat();
                },
                onDelete: () => _confirmDelete(context, agent),
              );
            },
          ),
        ),
      ],
    );
  }
}
