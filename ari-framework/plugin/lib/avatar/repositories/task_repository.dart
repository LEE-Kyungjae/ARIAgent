import 'package:ari_plugin/bridge/agent/AriAgent.dart';
import 'package:ari_plugin/avatar/models/agent_schedule.dart';
import 'package:flutter/foundation.dart';

/// 태스크 CRUD 액션을 담당하는 레포지토리.
/// WS 구독 없이 서버 호출만 처리하며, 상태는 저장하지 않는다.
class TaskRepository {
  static final TaskRepository _instance = TaskRepository._internal();
  factory TaskRepository() => _instance;
  TaskRepository._internal();

  // ── 조회 ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchTasks() async {
    final res = await AriAgent.call('/TASKS');
    return (res['tasks'] as List? ?? [])
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
  }

  // ── CRUD ──────────────────────────────────────────────────
  Future<AgentSchedule?> addTask({
    required String prompt,
    required String agentId,
    Map<String, dynamic>? scheduleSpec,
    String? label,
    String? appId,
    bool isOneOff = false,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    try {
      final res = await AriAgent.call('/TASKS.ADD', {
        'prompt': prompt,
        if (scheduleSpec != null) 'scheduleSpec': scheduleSpec,
        'label': label ??
            (prompt.length <= 20 ? prompt : '${prompt.substring(0, 20)}...'),
        'agentId': agentId,
        if (appId != null) 'appId': appId,
        'isOneOff': isOneOff,
        'startAt': (startAt ?? DateTime.now()).toIso8601String(),
        if (endAt != null) 'endAt': endAt.toIso8601String(),
      });
      final taskData = res['task'];
      if (taskData != null) {
        return AgentSchedule.fromMap(Map<String, dynamic>.from(taskData));
      }
    } catch (e) {
      debugPrint('[TaskRepository] addTask 실패: $e');
    }
    return null;
  }

  Future<bool> deleteTask(String id) async {
    try {
      await AriAgent.call('/TASKS.DELETE', {'taskId': id});
      return true;
    } catch (e) {
      debugPrint('[TaskRepository] deleteTask 실패: $e');
      return false;
    }
  }

  Future<bool> toggleTask(String id) async {
    try {
      await AriAgent.call('/TASKS.TOGGLE', {'taskId': id});
      return true;
    } catch (e) {
      debugPrint('[TaskRepository] toggleTask 실패: $e');
      return false;
    }
  }

  Future<String> runTaskNow(String id) async {
    try {
      final res = await AriAgent.call('/TASKS.RUN', {'taskId': id});
      return res['started'] == true ? '실행 완료' : '실행되지 않음';
    } catch (e) {
      return '❌ 실행 실패: $e';
    }
  }
}
