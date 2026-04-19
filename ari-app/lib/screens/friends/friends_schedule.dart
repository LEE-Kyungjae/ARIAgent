import '../../l10n/app_localizations.dart';

String formatUntil(DateTime t, S s) {
  final diff = t.difference(DateTime.now());
  if (diff.isNegative) return s.relativeSoon;
  if (diff.inMinutes < 1) return s.relativeSoon;
  if (diff.inMinutes < 60) return s.relativeInMinutes(diff.inMinutes);
  if (diff.inHours < 24) return s.relativeInHours(diff.inHours);
  if (diff.inDays < 7) return s.relativeInDays(diff.inDays);
  final m = t.minute.toString().padLeft(2, '0');
  return '${t.month}/${t.day} ${t.hour}:$m';
}

DateTime? nextRunOf(dynamic task, DateTime now) {
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
