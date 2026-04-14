import 'dart:async';

import 'package:ari_plugin/avatar/models/agent_model.dart';
import 'package:ari_plugin/avatar/models/telegram_channel_state.dart';
import 'package:ari_plugin/avatar/repositories/avatar_repository.dart';
import 'package:ari_plugin/bridge/ws/AriAgent.dart';
import 'package:ari_plugin/tasks/models/ari_scheduled_task.dart';
import 'package:flutter/foundation.dart';

/// 에이전트 목록 전체 및 현재 선택된 단일 에이전트의 상태를 관리하는 Provider.
/// 목록 CRUD, 프로필 조회/수정, 에이전트 전환, 메모리, 앱/스킬/툴, 채널, 태스크를 담당합니다.
class AgentProvider extends ChangeNotifier {
  static final AgentProvider _instance = AgentProvider._internal();
  factory AgentProvider() => _instance;
  AgentProvider._internal();

  final AvatarRepository _repository = AvatarRepository();
  String _currentAgentId = 'default';

  // ── 앱 실시간 상태 ────────────────────────────────────────
  List<String> _connectedAppIds = [];
  List<String> get connectedAppIds => _connectedAppIds;

  int _installedAppsVersion = 0;
  int get installedAppsVersion => _installedAppsVersion;

  // ── 초기화 ──────────────────────────────────────────────
  Future<void> init() async {
    await _repository.init();
    _currentAgentId = _repository.selectedAgentId;

    AriAgent.on('/AGENTS.LIST', (_) {
      _currentAgentId = _repository.selectedAgentId;
      _installedAppsVersion++;
      notifyListeners();
    });

    AriAgent.on('/CONNECTED_APPS_CHANGED', (data) {
      final ids = data['connectedIds'];
      if (ids is List) {
        _connectedAppIds = ids.cast<String>();
        debugPrint('[AgentProvider] Connected Apps Changed: $_connectedAppIds');
        notifyListeners();
      }
    });

    AriAgent.on('/INSTALLED_APPS_CHANGED', (data) {
      debugPrint('[AgentProvider] Installed Apps Changed: $data');
      _installedAppsVersion++;
      notifyListeners();
    });

    unawaited(_initTasks());

    notifyListeners();
  }

  @override
  void dispose() {
    _taskResultSub?.cancel();
    _tasksUpdatedSub?.cancel();
    _progressSub?.cancel();
    super.dispose();
  }

  // ── 에이전트 목록 ─────────────────────────────────────────
  List<AgentModel> get allAvatars => _repository.getAllAgents();

  Future<void> refreshAvatars() async {
    await _repository.refreshFromServer();
    _currentAgentId = _repository.selectedAgentId;
    notifyListeners();
  }

  Future<void> createAndSwitchAvatar(String id, String newName) async {
    final newAgent = AgentModel(id: id, name: newName, imagePath: '');
    await _repository.saveAgent(newAgent);
    await switchAvatar(id);
  }

  Future<void> deleteAvatar() async {
    final idToDelete = _currentAgentId;
    if (idToDelete == 'default') return;
    await _repository.deleteAgent(idToDelete);
    _currentAgentId = _repository.selectedAgentId;
    notifyListeners();
  }

  // ── 현재 에이전트 접근자 ─────────────────────────────────
  String get currentAvatarId => _currentAgentId;
  AgentModel get currentAvatar => _repository.getAgent(_currentAgentId);
  String get name => currentAvatar.name;
  String get imagePath => currentAvatar.imagePath;
  String get persona => currentAvatar.persona;

  // ── 에이전트 전환 ────────────────────────────────────────
  Future<void> switchAvatar(String agentId) async {
    if (_repository.hasAgent(agentId)) {
      _currentAgentId = agentId;
      _telegram = const TelegramChannelState();
      await _repository.setSelectedAgentId(agentId);
      notifyListeners();
    }
  }

  // ── 프로필 수정 ──────────────────────────────────────────
  Future<void> updateName(String newName) async {
    await _repository.saveAgent(currentAvatar.copyWith(name: newName));
    notifyListeners();
  }

  Future<void> updateImagePath(String path) async {
    await _repository.saveAgent(currentAvatar.copyWith(imagePath: path));
    notifyListeners();
  }

  Future<void> updatePersona(String newPersona) async {
    await _repository.saveAgent(currentAvatar.copyWith(persona: newPersona));
    notifyListeners();
  }

  // ── 메모리 ───────────────────────────────────────────────
  Future<void> initializeMemory() async {
    await _repository.initializeMemory(_currentAgentId);
    notifyListeners();
  }

  Future<Map<String, dynamic>> getMemory() async {
    return await _repository.getMemory(_currentAgentId);
  }

  Future<void> updateMemory(String content) async {
    await _repository.updateMemory(_currentAgentId, content);
  }

  Future<Map<String, dynamic>> getMemoryStats() async {
    return await _repository.getMemoryStats(_currentAgentId);
  }

  // ── 앱 ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getApps({String? agentId}) async {
    try {
      final payload = agentId != null
          ? {'agentId': agentId}
          : <String, dynamic>{};
      final res = await AriAgent.call('/PLUGINS.APPS', payload);
      return (res['apps'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('[AgentProvider] getApps failed: $e');
      return [];
    }
  }

  Future<List<String>> getConnectedApps() async {
    try {
      final res = await AriAgent.call('/GET_CONNECTED_APPS');
      final ids = res['connectedIds'];
      if (ids is List) {
        _connectedAppIds = ids.cast<String>();
        notifyListeners();
        return _connectedAppIds;
      }
      return [];
    } catch (e) {
      debugPrint('[AgentProvider] getConnectedApps failed: $e');
      return [];
    }
  }

  Future<bool> launchApp(String appId) async {
    try {
      await AriAgent.call('/LAUNCH_APP', {'appId': appId});
      return true;
    } catch (e) {
      debugPrint('[AgentProvider] launchApp failed: $e');
      return false;
    }
  }

  Future<bool> deleteApp(String name, {String? agentId}) async {
    try {
      await AriAgent.call('/DELETE_APP', {
        'name': name,
        'agentId': agentId ?? _currentAgentId,
      });
      return true;
    } catch (e) {
      debugPrint('[AgentProvider] deleteApp failed: $e');
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

  // ── 채널 ─────────────────────────────────────────────────
  TelegramChannelState _telegram = const TelegramChannelState();
  bool _channelLoading = false;
  String? _channelError;

  TelegramChannelState get telegram => _telegram;
  bool get channelLoading => _channelLoading;
  String? get channelError => _channelError;

  Future<void> loadTelegram() async {
    _channelLoading = true;
    _channelError = null;
    notifyListeners();
    try {
      final data = await AriAgent.call('/CHANNEL.GET', {
        'type': 'telegram',
        'agentId': _currentAgentId,
      });
      _telegram = TelegramChannelState(
        enabled: data['enabled'] == true,
        botTokenMasked: data['botToken'] as String? ?? '',
        agentId: data['agentId'] as String?,
        isPolling: data['isPolling'] == true,
      );
    } catch (e) {
      _channelError = e.toString();
      debugPrint('[AgentProvider] loadTelegram failed: $e');
    } finally {
      _channelLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveTelegram({String? botToken}) async {
    try {
      await AriAgent.call('/CHANNEL.SAVE', {
        'type': 'telegram',
        'agentId': _currentAgentId,
        if (botToken != null) 'botToken': botToken,
      });
      await loadTelegram();
      return true;
    } catch (e) {
      _channelError = e.toString();
      debugPrint('[AgentProvider] saveTelegram failed: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleTelegram(bool enabled) async {
    try {
      final data = await AriAgent.call('/CHANNEL.TOGGLE', {
        'type': 'telegram',
        'enabled': enabled,
        'agentId': _currentAgentId,
      });
      _telegram = _telegram.copyWith(
        enabled: data['enabled'] == true,
        isPolling: data['isPolling'] == true,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _channelError = e.toString();
      debugPrint('[AgentProvider] toggleTelegram failed: $e');
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> testTelegram(String botToken) async {
    try {
      final data = await AriAgent.call('/CHANNEL.TEST', {
        'type': 'telegram',
        if (botToken.isNotEmpty) 'botToken': botToken,
      });
      return {
        'ok': true,
        'botName': data['botName'] as String?,
        'message': null
      };
    } catch (e) {
      return {'ok': false, 'botName': null, 'message': e.toString()};
    }
  }

  void clearChannelError() {
    _channelError = null;
    notifyListeners();
  }

  // ── 태스크 ────────────────────────────────────────────────
  List<Map<String, dynamic>> _tasksCache = [];
  final Map<String, List<String>> _progressMessages = {};
  bool _tasksInitialized = false;
  StreamSubscription? _taskResultSub;
  StreamSubscription? _tasksUpdatedSub;
  StreamSubscription? _progressSub;

  List<AriScheduledTask> get tasks =>
      _tasksCache.map((m) => AriScheduledTask.fromMap(m)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<String> progressFor(String taskId) =>
      List.unmodifiable(_progressMessages[taskId] ?? []);

  List<AriScheduledTask> tasksForAgent(String agentId) =>
      tasks.where((t) {
        final aid = (t.agentId?.trim().isEmpty ?? true) ? 'default' : t.agentId!.trim();
        return aid == agentId;
      }).toList();

  List<AriScheduledTask> tasksForApp(String appId) =>
      tasks.where((t) => t.appId == appId).toList();

  Future<void> _initTasks() async {
    if (_tasksInitialized) return;
    await refreshTasks();

    _taskResultSub = AriAgent.on('/TASK_RESULT', (data) {
      final taskId = data['taskId']?.toString();
      if (taskId != null) _progressMessages.remove(taskId);
      refreshTasks();
    });

    _tasksUpdatedSub = AriAgent.on('/TASKS.UPDATED', (data) {
      final raw = data['tasks'] as List?;
      if (raw != null) {
        _tasksCache = raw.map((t) => Map<String, dynamic>.from(t)).toList();
        notifyListeners();
      } else {
        refreshTasks();
      }
    });

    _progressSub = AriAgent.on('/AGENT.PROGRESS', (data) {
      final payload = data['data'] ?? data;
      final taskId = payload['requestId']?.toString();
      final message = payload['message']?.toString();
      if (taskId == null || message == null) return;
      _progressMessages.putIfAbsent(taskId, () => []).add(message);
      notifyListeners();
    });

    _tasksInitialized = true;
  }

  Future<void> refreshTasks() async {
    try {
      final res = await AriAgent.call('/TASKS');
      final parsed = res['tasks'] as List? ?? [];
      _tasksCache = parsed.map((t) => Map<String, dynamic>.from(t)).toList();
    } catch (e) {
      debugPrint('[AgentProvider] refreshTasks 실패: $e');
    }
    notifyListeners();
  }

  Future<AriScheduledTask?> addTask({
    required String prompt,
    Map<String, dynamic>? scheduleSpec,
    String? label,
    String? agentId,
    String? appId,
    bool isOneOff = false,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    try {
      final res = await AriAgent.call('/TASKS.ADD', {
        'prompt': prompt,
        if (scheduleSpec != null) 'scheduleSpec': scheduleSpec,
        'label': label ?? (prompt.length <= 20 ? prompt : '${prompt.substring(0, 20)}...'),
        'agentId': agentId ?? _currentAgentId,
        if (appId != null) 'appId': appId,
        'isOneOff': isOneOff,
        'startAt': (startAt ?? DateTime.now()).toIso8601String(),
        if (endAt != null) 'endAt': endAt.toIso8601String(),
      });
      await refreshTasks();
      final taskData = res['task'];
      if (taskData != null) {
        return AriScheduledTask.fromMap(Map<String, dynamic>.from(taskData));
      }
    } catch (e) {
      debugPrint('[AgentProvider] addTask 실패: $e');
    }
    return null;
  }

  Future<bool> deleteTask(String id) async {
    try {
      await AriAgent.call('/TASKS.DELETE', {'taskId': id});
      await refreshTasks();
      return true;
    } catch (e) {
      debugPrint('[AgentProvider] deleteTask 실패: $e');
      return false;
    }
  }

  Future<bool> toggleTask(String id) async {
    try {
      await AriAgent.call('/TASKS.TOGGLE', {'taskId': id});
      await refreshTasks();
      return true;
    } catch (e) {
      debugPrint('[AgentProvider] toggleTask 실패: $e');
      return false;
    }
  }

  Future<String> runTaskNow(String id) async {
    try {
      final res = await AriAgent.call('/TASKS.RUN', {'taskId': id});
      await refreshTasks();
      return res['started'] == true ? '실행 완료' : '실행되지 않음';
    } catch (e) {
      return '❌ 실행 실패: $e';
    }
  }
}
