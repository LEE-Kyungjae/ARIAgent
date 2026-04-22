import 'package:ari_plugin/avatar/models/agent_token_usage.dart';
import 'package:ari_plugin/avatar/models/telegram_channel_state.dart';
import 'package:ari_plugin/bridge/agent/AriAgent.dart';
import 'package:ari_plugin/avatar/models/agent_schedule.dart';
import 'package:flutter/foundation.dart';

/// 에이전트 한 인스턴스의 프로필과 런타임 상태를 모두 소유하는 ChangeNotifier.
/// - 프로필(name, imagePath 등): 영속 데이터, 서버에 저장됨
/// - 런타임(apps, connectedIds, tasks, channels): WS 이벤트로만 갱신, 재시작 시 초기화
class AgentModel extends ChangeNotifier {
  final String id;

  // ── 프로필 (영속) ────────────────────────────────────────
  String _name;
  String _imagePath;
  String _description;
  String _persona;
  List<String> _skillNames;
  List<String> _appIds;

  // ── 런타임: 앱 ───────────────────────────────────────────
  List<Map<String, dynamic>> _installedApps = [];
  Set<String> _connectedAppIds = {};
  Set<String> _pinnedAppIds = {};

  // ── 런타임: 태스크 ───────────────────────────────────────
  List<AgentSchedule> _tasks = [];
  final Map<String, List<String>> _progressMessages = {};

  // ── 런타임: 토큰 사용량 (실시간 누적, /USAGE.UPDATED 이벤트로 갱신) ──
  AgentTokenUsage _tokenUsage = const AgentTokenUsage();

  // ── 런타임: 채널 ─────────────────────────────────────────
  TelegramChannelState _telegram = const TelegramChannelState();
  bool _channelLoading = false;
  String? _channelError;

  AgentModel({
    required this.id,
    String name = 'ARI',
    String imagePath = '',
    String description = '',
    String persona = '',
    List<String> skillNames = const [],
    List<String> appIds = const [],
  })  : _name = name,
        _imagePath = imagePath,
        _description = description,
        _persona = persona,
        _skillNames = skillNames,
        _appIds = appIds;

  // ── 프로필 게터 ──────────────────────────────────────────
  String get name => _name;
  String get imagePath => _imagePath;
  String get description => _description;
  String get persona => _persona;
  List<String> get skillNames => List.unmodifiable(_skillNames);
  List<String> get appIds => List.unmodifiable(_appIds);
  Set<String> get allowedSkillNames =>
      _skillNames.map((n) => n.trim()).where((n) => n.isNotEmpty).toSet();
  Set<String> get allowedAppIds =>
      _appIds.map((a) => a.trim()).where((a) => a.isNotEmpty).toSet();

  // ── 앱 게터 ──────────────────────────────────────────────
  List<Map<String, dynamic>> get installedApps =>
      List.unmodifiable(_installedApps);
  Set<String> get connectedAppIds => Set.unmodifiable(_connectedAppIds);
  bool isAppConnected(String appId) => _connectedAppIds.contains(appId);
  Set<String> get pinnedAppIds => Set.unmodifiable(_pinnedAppIds);
  bool isAppPinned(String appId) => _pinnedAppIds.contains(appId);

  // ── 태스크 게터 ──────────────────────────────────────────
  List<AgentSchedule> get tasks => List.unmodifiable(_tasks);
  List<String> progressFor(String taskId) =>
      List.unmodifiable(_progressMessages[taskId] ?? []);

  // ── 토큰 사용량 게터 ─────────────────────────────────────
  AgentTokenUsage get tokenUsage => _tokenUsage;

  // ── 채널 게터 ────────────────────────────────────────────
  TelegramChannelState get telegram => _telegram;
  bool get channelLoading => _channelLoading;
  String? get channelError => _channelError;

  // ── 프로필 뮤테이터 (AgentProvider가 저장 후 호출) ────────
  void updateName(String v) {
    _name = v;
    notifyListeners();
  }

  void updateImagePath(String v) {
    _imagePath = v;
    notifyListeners();
  }

  void updateDescription(String v) {
    _description = v;
    notifyListeners();
  }

  void updatePersona(String v) {
    _persona = v;
    notifyListeners();
  }

  void updateSkillNames(List<String> v) {
    _skillNames = v;
    notifyListeners();
  }

  void updateAppIds(List<String> v) {
    _appIds = v;
    notifyListeners();
  }

  /// 서버에서 받은 프로필 맵으로 필드 일괄 갱신 (id는 변경 불가)
  void updateFromMap(Map<String, dynamic> map) {
    _name = map['name'] as String? ?? _name;
    _imagePath = map['imagePath'] as String? ?? _imagePath;
    _description = map['description'] as String? ?? _description;
    _persona = map['persona'] as String? ?? _persona;
    _skillNames = (map['skillNames'] as List<dynamic>? ?? _skillNames)
        .whereType<String>()
        .toList();
    _appIds = (map['appIds'] as List<dynamic>? ?? _appIds)
        .whereType<String>()
        .toList();
    notifyListeners();
  }

  // ── 앱 상태 세터 (AgentProvider의 WS 핸들러가 호출) ──────
  void setInstalledApps(List<Map<String, dynamic>> apps) {
    _installedApps = apps;
    notifyListeners();
  }

  void setConnectedAppIds(Set<String> ids) {
    _connectedAppIds = ids;
    notifyListeners();
  }

  void setPinnedAppIds(Set<String> ids) {
    _pinnedAppIds = ids;
    notifyListeners();
  }

  void applyPinnedAppId(String appId, bool pinned) {
    if (pinned) {
      _pinnedAppIds = {..._pinnedAppIds, appId};
    } else {
      _pinnedAppIds = {..._pinnedAppIds}..remove(appId);
    }
    notifyListeners();
  }

  // ── 태스크 상태 세터 ──────────────────────────────────────
  void setTasks(List<AgentSchedule> tasks) {
    _tasks = tasks;
    notifyListeners();
  }

  void addProgress(String taskId, String message) {
    _progressMessages.putIfAbsent(taskId, () => []).add(message);
    notifyListeners();
  }

  void clearProgress(String taskId) {
    _progressMessages.remove(taskId);
    notifyListeners();
  }

  // ── 채널 상태 세터 ───────────────────────────────────────
  void setTelegramState(TelegramChannelState state) {
    _telegram = state;
    notifyListeners();
  }

  void setChannelLoading(bool v) {
    _channelLoading = v;
    notifyListeners();
  }

  void setChannelError(String? v) {
    _channelError = v;
    notifyListeners();
  }

  void clearChannelError() {
    _channelError = null;
    notifyListeners();
  }

  // ── 앱 로드 (자기 자신 호출) ─────────────────────────────
  Future<void> loadApps() async {
    try {
      final res = await AriAgent.call('/PLUGINS.APPS', {'agentId': id});
      _installedApps = (res['apps'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      _pinnedAppIds = (res['pinnedAppIds'] as List? ?? [])
          .whereType<String>()
          .toSet();
      notifyListeners();
    } catch (e) {
      debugPrint('[AgentModel($id)] loadApps failed: $e');
    }
  }

  // ── 토큰 사용량 세터 ─────────────────────────────────────
  /// 단일 응답의 사용량을 누적 (서버 /USAGE.UPDATED 이벤트)
  void accumulateTokenUsage({
    required int input,
    required int output,
    required int totalTokens,
    required String model,
  }) {
    _tokenUsage = _tokenUsage.accumulate(
      input: input,
      output: output,
      totalTokens: totalTokens,
      model: model,
    );
    notifyListeners();
  }

  /// 서버 /USAGE.GET 전체 집계로 교체 (초기 로드 or 새로고침)
  void setTokenUsageFromSummary(Map<String, dynamic> data) {
    _tokenUsage = AgentTokenUsage.fromSummary(data);
    notifyListeners();
  }

  // ── 채널 액션 (자기 자신 호출) ───────────────────────────
  Future<void> loadTelegram() async {
    _channelLoading = true;
    _channelError = null;
    notifyListeners();
    try {
      final data = await AriAgent.call('/CHANNEL.GET', {
        'type': 'telegram',
        'agentId': id,
      });
      _telegram = TelegramChannelState(
        enabled: data['enabled'] == true,
        botTokenMasked: data['botToken'] as String? ?? '',
        agentId: data['agentId'] as String?,
        isPolling: data['isPolling'] == true,
      );
    } catch (e) {
      _channelError = e.toString();
      debugPrint('[AgentModel($id)] loadTelegram failed: $e');
    } finally {
      _channelLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveTelegram({String? botToken}) async {
    try {
      await AriAgent.call('/CHANNEL.SAVE', {
        'type': 'telegram',
        'agentId': id,
        if (botToken != null) 'botToken': botToken,
      });
      await loadTelegram();
      return true;
    } catch (e) {
      _channelError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleTelegram(bool enabled) async {
    try {
      final data = await AriAgent.call('/CHANNEL.TOGGLE', {
        'type': 'telegram',
        'enabled': enabled,
        'agentId': id,
      });
      _telegram = _telegram.copyWith(
        enabled: data['enabled'] == true,
        isPolling: data['isPolling'] == true,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _channelError = e.toString();
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
        'message': null,
      };
    } catch (e) {
      return {'ok': false, 'botName': null, 'message': e.toString()};
    }
  }

  // ── 직렬화 (프로필만 저장) ────────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': _name,
        'imagePath': _imagePath,
        'description': _description,
        'persona': _persona,
        'skillNames': _skillNames,
        'appIds': _appIds,
      };

  factory AgentModel.fromMap(Map<String, dynamic> map) => AgentModel(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? 'ARI',
        imagePath: map['imagePath'] as String? ?? '',
        description: map['description'] as String? ?? '',
        persona: map['persona'] as String? ?? '',
        skillNames: (map['skillNames'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        appIds: (map['appIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
      );
}
