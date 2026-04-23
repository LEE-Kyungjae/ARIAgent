import 'dart:async';

import 'package:ari_plugin/avatar/models/agent_model.dart';
import 'package:ari_plugin/avatar/models/telegram_channel_state.dart';
import 'package:ari_plugin/avatar/repositories/avatar_repository.dart';
import 'package:ari_plugin/bridge/agent/AriAgent.dart';
import 'package:ari_plugin/avatar/models/agent_schedule.dart';
import 'package:ari_plugin/avatar/repositories/task_repository.dart';
import 'package:flutter/foundation.dart';

/// 에이전트 목록과 현재 선택된 에이전트를 관리하는 Provider.
///
/// 각 [AgentModel]은 자신의 런타임 상태(apps, tasks, channels)를 소유하는
/// ChangeNotifier다. [AgentProvider]는 목록 변경과 WS 이벤트 라우팅을 담당하며,
/// 개별 에이전트 상태 변화는 [AgentModel]이 직접 알린다.
///
/// UI는 [agentListNotifier]로 목록 변화를, [currentAgent]로 개별 에이전트 변화를 구독한다.
class AgentProvider extends ChangeNotifier {
  static final AgentProvider _instance = AgentProvider._internal();
  factory AgentProvider() => _instance;
  AgentProvider._internal();

  final AvatarRepository _repository = AvatarRepository();
  final TaskRepository _taskRepository = TaskRepository();

  /// 에이전트 목록 변화를 구독하는 ValueNotifier.
  /// 에이전트 추가/삭제/순서 변경 시 갱신된다.
  final ValueNotifier<List<AgentModel>> agentListNotifier =
      ValueNotifier(const []);

  String _currentAgentId = 'default';

  // ── 초기화 ──────────────────────────────────────────────
  bool _tasksInitialized = false;
  StreamSubscription? _taskResultSub;
  StreamSubscription? _tasksUpdatedSub;
  StreamSubscription? _progressSub;

  Future<void> init() async {
    await _repository.init();
    _currentAgentId = _repository.selectedAgentId;

    // 서버에서 에이전트 목록 수신 → 동기화
    AriAgent.on('/AGENTS.LIST', (data) {
      _currentAgentId = _repository.selectedAgentId;
      _syncAgentsFromRepository();
      unawaited(_reloadAllApps());
    });

    // 에이전트별 연결 앱 상태 변화
    AriAgent.on('/CONNECTED_APPS_CHANGED', (data) {
      final agentId = data['agentId']?.toString() ?? _currentAgentId;
      final ids = data['connectedIds'];
      if (ids is List) {
        _findAgent(agentId)?.setConnectedAppIds(ids.cast<String>().toSet());
      }
    });

    // 앱 설치/삭제 → 전체 재로드
    AriAgent.on('/INSTALLED_APPS_CHANGED', (_) {
      unawaited(_reloadAllApps());
    });

    // 실시간 토큰 누적 — 서버가 appendUsageLog 후 /USAGE.UPDATED를 broadcast하면 동작
    AriAgent.on('/USAGE.UPDATED', (data) {
      final agentId = data['agentId']?.toString();
      final model = data['model']?.toString() ?? 'unknown';
      final usage = data['usage'] as Map<String, dynamic>?;
      if (agentId == null || usage == null) return;
      _findAgent(agentId)?.accumulateTokenUsage(
        input: (usage['input'] as num? ?? 0).toInt(),
        output: (usage['output'] as num? ?? 0).toInt(),
        totalTokens: (usage['totalTokens'] as num? ?? 0).toInt(),
        model: model,
      );
    });

    unawaited(_initTasksWs());
    notifyListeners();
  }

  @override
  void dispose() {
    _taskResultSub?.cancel();
    _tasksUpdatedSub?.cancel();
    _progressSub?.cancel();
    for (final a in agentListNotifier.value) {
      a.dispose();
    }
    agentListNotifier.dispose();
    super.dispose();
  }

  // ── 에이전트 목록 동기화 ─────────────────────────────────
  void _syncAgentsFromRepository() {
    final profiles = _repository.getAllAgents(); // 프로필 맵 기반의 새 인스턴스들
    final existing = {for (final a in agentListNotifier.value) a.id: a};
    final updated = <AgentModel>[];

    for (final profile in profiles) {
      if (existing.containsKey(profile.id)) {
        // 기존 인스턴스 유지 + 프로필만 갱신 (런타임 상태 보존)
        existing[profile.id]!.updateFromMap(profile.toMap());
        updated.add(existing[profile.id]!);
      } else {
        updated.add(profile);
      }
    }

    // 삭제된 에이전트 정리
    for (final a in agentListNotifier.value) {
      if (!updated.contains(a)) {
        a.dispose();
      }
    }

    agentListNotifier.value = updated;
    notifyListeners();
  }

  AgentModel? _findAgent(String id) {
    for (final a in agentListNotifier.value) {
      if (a.id == id) return a;
    }
    return null;
  }

  AgentModel? _findAgentByTaskId(String taskId) {
    for (final a in agentListNotifier.value) {
      if (a.tasks.any((t) => t.id == taskId)) return a;
    }
    return null;
  }

  // ── 에이전트 목록 게터 ────────────────────────────────────
  List<AgentModel> get allAvatars => agentListNotifier.value;
  String get currentAvatarId => _currentAgentId;

  AgentModel get currentAgent {
    final found = _findAgent(_currentAgentId);
    if (found != null) return found;
    if (agentListNotifier.value.isNotEmpty)
      return agentListNotifier.value.first;
    // 목록이 비어있으면 임시 더미 (init 전 상태)
    return AgentModel(id: 'default');
  }

  // ── 현재 에이전트 프로필 헬퍼 게터 ───────────────────────
  String get name => currentAgent.name;
  String get imagePath => currentAgent.imagePath;
  String get persona => currentAgent.persona;

  // ── 현재 에이전트 앱 헬퍼 게터 ───────────────────────────
  List<Map<String, dynamic>> get currentAgentApps => currentAgent.installedApps;
  bool isAppConnected(String appId) => currentAgent.isAppConnected(appId);

  // ── 특정 에이전트 앱 헬퍼 게터 ───────────────────────────
  List<Map<String, dynamic>> appsForAgent(String agentId) =>
      _findAgent(agentId)?.installedApps ?? [];
  Set<String> connectedAppIdsForAgent(String agentId) =>
      _findAgent(agentId)?.connectedAppIds ?? {};
  bool isAgentAppsLoaded(String agentId) =>
      (_findAgent(agentId)?.installedApps.isNotEmpty) ?? false;

  // ── 태스크 헬퍼 게터 ─────────────────────────────────────
  List<AgentSchedule> get tasks => currentAgent.tasks;
  List<AgentSchedule> tasksForAgent(String agentId) =>
      _findAgent(agentId)?.tasks ?? [];
  List<String> progressFor(String taskId) => currentAgent.progressFor(taskId);

  // ── 채널 헬퍼 게터 ───────────────────────────────────────
  TelegramChannelState get telegram => currentAgent.telegram;
  bool get channelLoading => currentAgent.channelLoading;
  String? get channelError => currentAgent.channelError;

  // ── 앱 캐시 로드 ─────────────────────────────────────────
  Future<void> _reloadAllApps() async {
    for (final agent in agentListNotifier.value) {
      await agent.loadApps();
    }
    await _refreshConnectedApps();
    notifyListeners();
  }

  Future<void> _refreshConnectedApps() async {
    try {
      final res = await AriAgent.call('/GET_CONNECTED_APPS', {});
      final ids = (res['connectedIds'] as List? ?? [])
          .whereType<String>()
          .toSet();
      for (final agent in agentListNotifier.value) {
        agent.setConnectedAppIds(ids);
      }
    } catch (e) {
      debugPrint('[AgentProvider] refreshConnectedApps failed: $e');
    }
  }

  // ── 에이전트 액션 ─────────────────────────────────────────
  Future<void> refreshAvatars() async {
    await _repository.refreshFromServer();
    _currentAgentId = _repository.selectedAgentId;
    _syncAgentsFromRepository();
    await _reloadAllApps();
  }

  Future<void> switchAvatar(String agentId) async {
    if (_repository.hasAgent(agentId)) {
      _currentAgentId = agentId;
      await _repository.setSelectedAgentId(agentId);
      // 앱 캐시가 없으면 즉시 로드
      final agent = _findAgent(agentId);
      if (agent != null && agent.installedApps.isEmpty) {
        unawaited(agent.loadApps());
      }
      notifyListeners();
    }
  }

  Future<void> createAndSwitchAvatar(String id, String newName) async {
    final newAgent = AgentModel(id: id, name: newName);
    await _repository.saveAgent(newAgent);
    agentListNotifier.value = [...agentListNotifier.value, newAgent];
    await switchAvatar(id);
    notifyListeners();
  }

  Future<void> deleteAvatar() async {
    final idToDelete = _currentAgentId;
    if (idToDelete == 'default') return;

    final agent = _findAgent(idToDelete);
    if (agent != null) {
      agent.dispose();
      agentListNotifier.value =
          agentListNotifier.value.where((a) => a.id != idToDelete).toList();
    }

    await _repository.deleteAgent(idToDelete);
    _currentAgentId = _repository.selectedAgentId;
    notifyListeners();
  }

  // ── 프로필 액션 ──────────────────────────────────────────
  Future<void> updateName(String newName) async {
    currentAgent.updateName(newName);
    await _repository.saveAgent(currentAgent);
  }

  Future<void> updateImagePath(String path) async {
    currentAgent.updateImagePath(path);
    await _repository.saveAgent(currentAgent);
  }

  Future<void> updatePersona(String newPersona) async {
    currentAgent.updatePersona(newPersona);
    await _repository.saveAgent(currentAgent);
  }

  // ── 메모리 액션 ──────────────────────────────────────────
  Future<void> initializeMemory() async =>
      _repository.initializeMemory(_currentAgentId);

  Future<Map<String, dynamic>> getMemory() async =>
      _repository.getMemory(_currentAgentId);

  Future<void> updateMemory(String content) async =>
      _repository.updateMemory(_currentAgentId, content);

  Future<Map<String, dynamic>> getMemoryStats() async =>
      _repository.getMemoryStats(_currentAgentId);

  // ── 앱 액션 ──────────────────────────────────────────────
  Future<bool> launchApp(String appId) async {
    try {
      await AriAgent.call('/LAUNCH_APP', {'appId': appId});
      return true;
    } catch (e) {
      debugPrint('[AgentProvider] launchApp failed: $e');
      return false;
    }
  }

  Future<bool> deleteApp(String name) async {
    try {
      await AriAgent.call('/DELETE_APP', {'name': name});
      return true;
    } catch (e) {
      debugPrint('[AgentProvider] deleteApp failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> installApp({
    required String url,
    String? appId,
    bool force = false,
  }) async {
    try {
      final res = await AriAgent.call('/APP.INSTALL', {
        'url': url,
        if (appId != null) 'appId': appId,
        if (force) 'force': true,
      });
      return {'ok': true, 'data': res};
    } catch (e) {
      debugPrint('[AgentProvider] installApp failed: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<bool> pinApp(String appId) async {
    final agent = currentAgent;
    final wasPinned = agent.isAppPinned(appId);
    agent.applyPinnedAppId(appId, true);
    try {
      await AriAgent.call('/AGENTS.APP.PIN', {
        'agentId': agent.id,
        'appId': appId,
      });
      return true;
    } catch (e) {
      debugPrint('[AgentProvider] pinApp failed: $e');
      agent.applyPinnedAppId(appId, wasPinned);
      return false;
    }
  }

  Future<bool> unpinApp(String appId) async {
    final agent = currentAgent;
    final wasPinned = agent.isAppPinned(appId);
    agent.applyPinnedAppId(appId, false);
    try {
      await AriAgent.call('/AGENTS.APP.UNPIN', {
        'agentId': agent.id,
        'appId': appId,
      });
      return true;
    } catch (e) {
      debugPrint('[AgentProvider] unpinApp failed: $e');
      agent.applyPinnedAppId(appId, wasPinned);
      return false;
    }
  }

  // ── 스킬 / 툴 ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSkills() async {
    try {
      final res = await AriAgent.call('/PLUGINS.SKILLS');
      return (res['skills'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('[AgentProvider] getSkills failed: $e');
      return [];
    }
  }

  Future<bool> deleteSkill(String name) async {
    try {
      await AriAgent.call('/DELETE_SKILL', {'name': name});
      return true;
    } catch (e) {
      debugPrint('[AgentProvider] deleteSkill failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getTools() async {
    try {
      final res = await AriAgent.call('/PLUGINS.TOOLS');
      return (res['tools'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('[AgentProvider] getTools failed: $e');
      return [];
    }
  }

  // ── 채널 액션 (AgentModel에 위임) ────────────────────────
  Future<void> loadTelegram() => currentAgent.loadTelegram();
  Future<bool> saveTelegram({String? botToken}) =>
      currentAgent.saveTelegram(botToken: botToken);
  Future<bool> toggleTelegram(bool enabled) =>
      currentAgent.toggleTelegram(enabled);
  Future<Map<String, dynamic>> testTelegram(String botToken) =>
      currentAgent.testTelegram(botToken);
  void clearChannelError() => currentAgent.clearChannelError();

  // ── 태스크 WS 초기화 ──────────────────────────────────────
  Future<void> _initTasksWs() async {
    if (_tasksInitialized) return;
    await _refreshAllTasks();

    _taskResultSub = AriAgent.on('/TASK_RESULT', (data) {
      final taskId = data['taskId']?.toString();
      if (taskId != null) {
        _findAgentByTaskId(taskId)?.clearProgress(taskId);
      }
      unawaited(_refreshAllTasks());
    });

    _tasksUpdatedSub = AriAgent.on('/TASKS.UPDATED', (data) {
      final raw = data['tasks'];
      if (raw is List) {
        _distributeTasks(raw.map((t) => Map<String, dynamic>.from(t)).toList());
      } else {
        unawaited(_refreshAllTasks());
      }
    });

    _progressSub = AriAgent.on('/AGENT.PROGRESS', (data) {
      final payload = data['data'] ?? data;
      final taskId = payload['requestId']?.toString();
      final message = payload['message']?.toString();
      final agentId = payload['agentId']?.toString();
      if (taskId == null || message == null) return;

      final agent = agentId != null
          ? (_findAgent(agentId) ?? _findAgentByTaskId(taskId))
          : _findAgentByTaskId(taskId);
      (agent ?? currentAgent).addProgress(taskId, message);
    });

    _tasksInitialized = true;
  }

  Future<void> _refreshAllTasks() async {
    try {
      _distributeTasks(await _taskRepository.fetchTasks());
    } catch (e) {
      debugPrint('[AgentProvider] refreshTasks 실패: $e');
    }
  }

  /// 전체 태스크 목록을 agentId별로 분배하여 각 AgentModel에 할당
  void _distributeTasks(List<Map<String, dynamic>> allTasks) {
    final byAgent = <String, List<AgentSchedule>>{};
    for (final raw in allTasks) {
      final task = AgentSchedule.fromMap(raw);
      final aid = (task.agentId?.trim().isEmpty ?? true)
          ? 'default'
          : task.agentId!.trim();
      byAgent.putIfAbsent(aid, () => []).add(task);
    }
    for (final agent in agentListNotifier.value) {
      final agentTasks = byAgent[agent.id] ?? [];
      agentTasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      agent.setTasks(agentTasks);
    }
  }

  // ── 태스크 공개 액션 (TaskRepository에 위임) ─────────────
  Future<void> refreshTasks() => _refreshAllTasks();

  Future<AgentSchedule?> addTask({
    required String prompt,
    Map<String, dynamic>? scheduleSpec,
    String? label,
    String? agentId,
    String? appId,
    bool isOneOff = false,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    final task = await _taskRepository.addTask(
      prompt: prompt,
      agentId: agentId ?? _currentAgentId,
      scheduleSpec: scheduleSpec,
      label: label,
      appId: appId,
      isOneOff: isOneOff,
      startAt: startAt,
      endAt: endAt,
    );
    await _refreshAllTasks();
    return task;
  }

  Future<bool> deleteTask(String id) async {
    final ok = await _taskRepository.deleteTask(id);
    if (ok) await _refreshAllTasks();
    return ok;
  }

  Future<bool> toggleTask(String id) async {
    final ok = await _taskRepository.toggleTask(id);
    if (ok) await _refreshAllTasks();
    return ok;
  }

  Future<String> runTaskNow(String id) async {
    final result = await _taskRepository.runTaskNow(id);
    await _refreshAllTasks();
    return result;
  }
}
