import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../tasks/task_provider.dart';

/// [appId] 로 필터된 AriTask 중 가장 빠른 다음 실행 시각을 카운트다운으로 보여준다.
/// 등록된 태스크가 없으면 빈 위젯.
class AriAgentNextScheduleFooter extends StatefulWidget {
  const AriAgentNextScheduleFooter({
    super.key,
    required this.appId,
    this.textSubColor = const Color(0xFF4E5968),
    this.labelBuilder,
  });

  final String appId;
  final Color textSubColor;

  /// 커스텀 라벨 빌더: (remainingText, taskLabel) → display string.
  /// 미제공 시 "다음 스케줄 <remaining> 전 · <taskLabel>" 형식.
  final String Function(String remainingText, String taskLabel)? labelBuilder;

  @override
  State<AriAgentNextScheduleFooter> createState() =>
      _AriAgentNextScheduleFooterState();
}

class _AriAgentNextScheduleFooterState
    extends State<AriAgentNextScheduleFooter> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime? _computeNextRun(dynamic task, DateTime now) {
    if (!task.enabled) return null;
    if (task.endAt != null && !now.isBefore(task.endAt!)) return null;

    if (task.isOneOff) {
      return task.startAt.isAfter(now) ? task.startAt : null;
    }

    final spec = task.scheduleSpec;
    if (spec == null) return null;
    final type = spec['type'] as String?;

    DateTime clampToStart(DateTime candidate) =>
        task.startAt.isAfter(candidate) ? task.startAt : candidate;

    switch (type) {
      case 'every_n_minutes':
        {
          final every = (spec['every'] as num?)?.toInt() ?? 1;
          if (every <= 0) return null;
          var next = task.lastRunAt != null
              ? task.lastRunAt!.add(Duration(minutes: every))
              : task.startAt;
          if (next.isBefore(now)) {
            final diff = now.difference(next).inMinutes;
            final skips = (diff ~/ every) + 1;
            next = next.add(Duration(minutes: every * skips));
          }
          return clampToStart(next);
        }
      case 'every_n_hours':
        {
          final every = (spec['every'] as num?)?.toInt() ?? 1;
          if (every <= 0) return null;
          var next = task.lastRunAt != null
              ? task.lastRunAt!.add(Duration(hours: every))
              : task.startAt;
          if (next.isBefore(now)) {
            final diff = now.difference(next).inHours;
            final skips = (diff ~/ every) + 1;
            next = next.add(Duration(hours: every * skips));
          }
          return clampToStart(next);
        }
      case 'daily':
        {
          final h = (spec['hour'] as num?)?.toInt() ?? 0;
          final m = (spec['minute'] as num?)?.toInt() ?? 0;
          var next = DateTime(now.year, now.month, now.day, h, m);
          if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
          return clampToStart(next);
        }
      case 'weekly':
        {
          final h = (spec['hour'] as num?)?.toInt() ?? 0;
          final m = (spec['minute'] as num?)?.toInt() ?? 0;
          final rawDays = spec['days'];
          if (rawDays is! List || rawDays.isEmpty) return null;
          final days = rawDays.map((d) => (d as num).toInt()).toSet();
          for (var i = 0; i < 8; i++) {
            final d = now.add(Duration(days: i));
            final dayIdx = d.weekday % 7;
            if (!days.contains(dayIdx)) continue;
            final cand = DateTime(d.year, d.month, d.day, h, m);
            if (cand.isAfter(now)) return clampToStart(cand);
          }
          return null;
        }
      default:
        return null;
    }
  }

  String _formatRemaining(Duration d) {
    if (d.inSeconds <= 0) return '곧';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    final secs = d.inSeconds % 60;
    if (days > 0) return '$days일 $hours시간';
    if (hours > 0) return '$hours시간 $mins분';
    if (mins > 0) return '$mins분';
    return '$secs초';
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<AriTaskProvider>();
    final now = DateTime.now();

    DateTime? soonest;
    dynamic soonestTask;
    for (final t in taskProvider.tasksForApp(widget.appId)) {
      final next = _computeNextRun(t, now);
      if (next == null) continue;
      if (soonest == null || next.isBefore(soonest)) {
        soonest = next;
        soonestTask = t;
      }
    }

    if (soonest == null || soonestTask == null) {
      return const SizedBox.shrink();
    }

    final remaining = soonest.difference(now);
    final label = soonestTask.label.isEmpty
        ? soonestTask.scheduleDescription
        : soonestTask.label;

    final remainingText = _formatRemaining(remaining);
    final displayText = widget.labelBuilder != null
        ? widget.labelBuilder!(remainingText, label)
        : '다음 스케줄 $remainingText 전 · $label';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 13, color: widget.textSubColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              displayText,
              style: TextStyle(fontSize: 11, color: widget.textSubColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
