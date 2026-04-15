import 'dart:async';

import 'package:ari_plugin/avatar/models/agent_schedule.dart';
import 'package:ari_plugin/avatar/repositories/task_repository.dart';
import 'package:ari_plugin/bridge/agent/AriAgent.dart';
import 'package:flutter/foundation.dart';

/// 앱별 스케줄 태스크 상태를 관리하는 Provider.
///
/// [AgentProvider]가 에이전트 단위로 태스크를 관리하는 반면,
/// [AriTaskProvider]는 앱 단위로 태스크를 조회·CRUD하는 경량 Provider다.
/// 단일 앱이 자신과 연관된 태스크만 다룰 때 사용한다.
class AriTaskProvider extends ChangeNotifier {
  final TaskRepository _taskRepository = TaskRepository();

  List<AgentSchedule> _tasks = [];
  StreamSubscription? _taskResultSub;
  StreamSubscription? _tasksUpdatedSub;

  List<AgentSchedule> get tasks => List.unmodifiable(_tasks);

  /// appId로 필터링된 태스크 목록 반환
  List<AgentSchedule> tasksForApp(String appId) =>
      _tasks.where((t) => t.appId == appId).toList();

  // ── 초기화 ──────────────────────────────────────────────────
  Future<void> init() async {
    await _refresh();

    _taskResultSub = AriAgent.on('/TASK_RESULT', (data) {
      unawaited(_refresh());
    });

    _tasksUpdatedSub = AriAgent.on('/TASKS.UPDATED', (data) {
      final raw = data['tasks'];
      if (raw is List) {
        _setTasks(raw.map((t) => Map<String, dynamic>.from(t)).toList());
      } else {
        unawaited(_refresh());
      }
    });
  }

  /// 서버에서 전체 태스크 목록을 다시 불러옴
  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    try {
      final raw = await _taskRepository.fetchTasks();
      _setTasks(raw);
    } catch (e) {
      debugPrint('[AriTaskProvider] 태스크 로드 실패: $e');
    }
  }

  void _setTasks(List<Map<String, dynamic>> rawList) {
    _tasks = rawList.map((m) => AgentSchedule.fromMap(m)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();
  }

  // ── CRUD ────────────────────────────────────────────────────
  Future<bool> toggleTask(String id) async {
    final ok = await _taskRepository.toggleTask(id);
    if (ok) await _refresh();
    return ok;
  }

  Future<bool> deleteTask(String id) async {
    final ok = await _taskRepository.deleteTask(id);
    if (ok) await _refresh();
    return ok;
  }

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
    final task = await _taskRepository.addTask(
      prompt: prompt,
      agentId: agentId,
      scheduleSpec: scheduleSpec,
      label: label,
      appId: appId,
      isOneOff: isOneOff,
      startAt: startAt,
      endAt: endAt,
    );
    await _refresh();
    return task;
  }

  Future<String> runTaskNow(String id) async {
    final result = await _taskRepository.runTaskNow(id);
    await _refresh();
    return result;
  }

  @override
  void dispose() {
    _taskResultSub?.cancel();
    _tasksUpdatedSub?.cancel();
    super.dispose();
  }
}
