import 'dart:io';

import 'package:ari_plugin/ari_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../place/providers/place_agent_status_provider.dart';

class FriendsView extends StatefulWidget {
  final VoidCallback onOpenChat;

  const FriendsView({super.key, required this.onOpenChat});

  @override
  State<FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<FriendsView> {
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
        _Header(count: agents.length),
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
                return const _AddFriendTile();
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
                  .map((t) => _nextRunOf(t, now))
                  .whereType<DateTime>()
                  .fold<DateTime?>(
                    null,
                    (a, b) => a == null || b.isBefore(a) ? b : a,
                  );
              return _FriendTile(
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

class _Header extends StatelessWidget {
  final int count;

  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            S.of(context).agentSelect,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '$count',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatefulWidget {
  final dynamic agent;
  final bool isActive;
  final bool isSelected;
  final String status;
  final int scheduleCount;
  final DateTime? nextRunAt;
  final VoidCallback onListSelect;
  final VoidCallback onOpenChat;
  final VoidCallback onDelete;

  const _FriendTile({
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
  State<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends State<_FriendTile> {
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
              _Avatar(
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
                    _StatusRow(
                      status: widget.status,
                      scheduleCount: widget.scheduleCount,
                      nextRunAt: widget.nextRunAt,
                    ),
                  ],
                ),
              ),
              if (widget.isSelected) ...[
                const SizedBox(width: 8),
                _ActionIcon(
                  icon: Icons.chat_bubble_rounded,
                  tooltip: S.of(context).tabChat,
                  onTap: widget.onOpenChat,
                ),
                const SizedBox(width: 4),
                if (widget.agent.id != 'default')
                  _ActionIcon(
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

String _formatUntil(DateTime t) {
  final diff = t.difference(DateTime.now());
  if (diff.isNegative) return '곧';
  if (diff.inMinutes < 1) return '곧';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 후';
  if (diff.inHours < 24) return '${diff.inHours}시간 후';
  if (diff.inDays < 7) return '${diff.inDays}일 후';
  final m = t.minute.toString().padLeft(2, '0');
  return '${t.month}/${t.day} ${t.hour}:$m';
}

DateTime? _nextRunOf(dynamic task, DateTime now) {
  try {
    if (task.endAt != null && (task.endAt as DateTime).isBefore(now)) {
      return null;
    }
    if (task.isOneOff == true) {
      final start = task.startAt as DateTime?;
      if (start == null || start.isBefore(now)) return null;
      return start;
    }
    final spec = task.scheduleSpec;
    if (spec is! Map) return null;
    final type = spec['type'] as String?;
    switch (type) {
      case 'every_n_minutes':
        final every = (spec['every'] as num?)?.toInt() ?? 1;
        return now.add(Duration(minutes: every));
      case 'every_n_hours':
        final every = (spec['every'] as num?)?.toInt() ?? 1;
        return now.add(Duration(hours: every));
      case 'daily':
        final h = (spec['hour'] as num?)?.toInt() ?? 0;
        final m = (spec['minute'] as num?)?.toInt() ?? 0;
        var next = DateTime(now.year, now.month, now.day, h, m);
        if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
        return next;
      case 'weekly':
        final h = (spec['hour'] as num?)?.toInt() ?? 0;
        final m = (spec['minute'] as num?)?.toInt() ?? 0;
        final rawDays = spec['days'];
        final days = rawDays is List
            ? rawDays.map((d) => (d as num).toInt()).toList()
            : const <int>[];
        if (days.isEmpty) return null;
        for (var i = 0; i < 14; i++) {
          final cand = DateTime(now.year, now.month, now.day, h, m)
              .add(Duration(days: i));
          final weekday = cand.weekday % 7;
          if (days.contains(weekday) && cand.isAfter(now)) return cand;
        }
        return null;
      case 'monthly':
        final h = (spec['hour'] as num?)?.toInt() ?? 0;
        final m = (spec['minute'] as num?)?.toInt() ?? 0;
        final day = (spec['day'] as num?)?.toInt() ?? 1;
        var next = DateTime(now.year, now.month, day, h, m);
        if (!next.isAfter(now)) {
          next = DateTime(now.year, now.month + 1, day, h, m);
        }
        return next;
      case 'yearly':
        final h = (spec['hour'] as num?)?.toInt() ?? 0;
        final m = (spec['minute'] as num?)?.toInt() ?? 0;
        final day = (spec['day'] as num?)?.toInt() ?? 1;
        final month = (spec['month'] as num?)?.toInt() ?? 1;
        var next = DateTime(now.year, month, day, h, m);
        if (!next.isAfter(now)) {
          next = DateTime(now.year + 1, month, day, h, m);
        }
        return next;
    }
  } catch (_) {}
  return null;
}

class _StatusRow extends StatelessWidget {
  final String status;
  final int scheduleCount;
  final DateTime? nextRunAt;

  const _StatusRow({
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
                      ? '$scheduleCount · ${_formatUntil(nextRunAt!)}'
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

class _ActionIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool danger;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
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

class _Avatar extends StatelessWidget {
  final String imagePath;

  const _Avatar({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final trimmed = imagePath.trim();
    final isAsset = trimmed.startsWith('assets/');
    final file = trimmed.isNotEmpty && !isAsset ? File(trimmed) : null;
    final hasImage = isAsset || (file != null && file.existsSync());

    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF1A1A2E),
      child: ClipOval(
        child: hasImage
            ? (isAsset
                  ? Image.asset(
                      trimmed,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(),
                    )
                  : Image.file(
                      file!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(),
                    ))
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Image.asset(
    'assets/images/avatar.png',
    width: 48,
    height: 48,
    fit: BoxFit.cover,
  );
}

class _AddFriendTile extends StatefulWidget {
  const _AddFriendTile();

  @override
  State<_AddFriendTile> createState() => _AddFriendTileState();
}

class _AddFriendTileState extends State<_AddFriendTile> {
  bool _hover = false;

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
            onTap: () async {
              final id = 'agent_${DateTime.now().millisecondsSinceEpoch}';
              await context.read<AgentProvider>().createAndSwitchAvatar(
                id,
                S.of(context).defaultAvatarName,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _hover
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
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
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    S.of(context).newAvatar,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
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
