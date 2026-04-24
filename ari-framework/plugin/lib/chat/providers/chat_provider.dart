import 'dart:async';
import 'package:flutter/material.dart';
import '../../bridge/agent/AriAgent.dart';
import '../../sessions/models/ari_work_session.dart';
import '../../sessions/models/ari_work_step.dart';
import '../models/ari_chat_item.dart';
import '../models/ari_chat_message.dart';
import '../models/ari_queued_follow_up.dart';
import '../repositories/chat_repository.dart';

export '../models/ari_chat_item.dart';
export '../models/ari_chat_message.dart';
export '../../sessions/models/ari_work_session.dart';
export '../../sessions/models/ari_work_step.dart';

/// ARI 에이전트 스트림을 구독하여 채팅 메시지 상태를 관리하는 Provider.
class AriChatProvider extends ChangeNotifier {
  final ChatRepository _repository = ChatRepository();

  final List<AriChatMessage> _messages = [];
  final Map<String, AriWorkSession> _workSessions = {};
  StreamSubscription? _agentPushSub;
  StreamSubscription? _agentRequestSub;
  StreamSubscription? _progressSub;
  StreamSubscription? _followUpSub;
  StreamSubscription? _cancelSub;
  StreamSubscription? _taskResultSub;
  StreamSubscription? _noticeSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _workCommandSub;
  final List<StreamSubscription> _customSubs = [];
  final Set<String> _inFlightRequestIds = {};
  final Set<String> _backgroundRequestIds = {};
  final List<AriQueuedFollowUp> _queuedFollowUps = [];

  bool _isLoading = false;
  String? _activeRequestId;
  String? _filterAgentId; // 현재 표시 중인 에이전트 ID 필터

  /// 아바타 전환 시 호출 — 이 ID와 다른 에이전트 메시지는 무시
  void setFilterAgentId(String agentId) {
    _filterAgentId = agentId;
  }

  bool get isLoading => _isLoading;
  String? get activeRequestId => _activeRequestId;
  String? get latestFollowUpMessage =>
      _queuedFollowUps.isEmpty ? null : _queuedFollowUps.last.message;
  int get queuedFollowUpCount => _queuedFollowUps.length;

  void _syncLoadingState() {
    _isLoading =
        _inFlightRequestIds.isNotEmpty || _backgroundRequestIds.isNotEmpty;
  }

  void _clearPendingSystemMessages() {
    final pendingRequestIds = {
      ..._inFlightRequestIds,
      ..._backgroundRequestIds,
      if (_activeRequestId != null) _activeRequestId!,
    };
    if (pendingRequestIds.isEmpty) return;
    _messages.removeWhere(
      (m) => m.isSystem && pendingRequestIds.contains(m.requestId),
    );
  }

  bool _removeFollowUpByRequestId(String requestId) {
    if (requestId.isEmpty) return false;
    final index =
        _queuedFollowUps.indexWhere((item) => item.requestId == requestId);
    if (index == -1) return false;
    _queuedFollowUps.removeAt(index);
    return true;
  }

  // 추가 이벤트 핸들러 주입
  final Map<String, void Function(dynamic data, AriChatProvider provider)>?
      customEventHandlers;

  AriChatProvider({
    this.customEventHandlers,
  }) {
    _initListeners();

    // 주입된 커스텀 이벤트 핸들러 등록
    customEventHandlers?.forEach((event, handler) {
      _customSubs.add(AriAgent.on(event, (data) => handler(data, this)));
    });
  }

  void _initListeners() {
    _agentRequestSub = AriAgent.on('/AGENT.REQUEST', (data) {
      final requestId = data['requestId']?.toString() ?? '';
      final message = data['message']?.toString() ?? '';
      final msgAgent = data['agentId']?.toString() ?? 'default';
      final from = data['from']?.toString() ?? '';
      final to = data['to']?.toString() ?? '';
      final senderName = data['senderName']?.toString() ?? '';
      final isInterAgent = from.isNotEmpty && to.isNotEmpty && from != to;

      if (message.isEmpty) return;
      if (_filterAgentId != null && msgAgent != _filterAgentId) return;
      if (requestId.isNotEmpty &&
          _messages.any((m) => m.isUser && m.requestId == requestId)) return;

      _messages.add(AriChatMessage(
        text: message,
        isUser: true,
        createdAt: DateTime.now(),
        requestId: requestId,
        appId: isInterAgent ? from : null,
        senderName: senderName.isNotEmpty ? senderName : null,
      ));
      notifyListeners();
    });

    _agentPushSub = AriAgent.on('/APP.PUSH', (data) {
      final payload = data['data'] is Map ? data['data'] as Map : data;
      final response = payload['response']?.toString() ?? '';
      final requestId = payload['requestId']?.toString() ?? '';
      final msgAgent = payload['agentId']?.toString() ?? 'default';
      final from = payload['from']?.toString() ?? '';
      final to = payload['to']?.toString() ?? '';
      final senderName = payload['senderName']?.toString() ?? '';
      final isInterAgent = from.isNotEmpty && to.isNotEmpty && from != to;

      if (response.isEmpty) return;
      // inter-agent push 는 발신측 agentId 가 다르므로 filter 우회.
      // (서버는 to 가 내 채팅창인 경우만 보내므로 추가 검증 불필요.)
      if (!isInterAgent &&
          _filterAgentId != null &&
          msgAgent != _filterAgentId) return;

      if (requestId.isNotEmpty) removeSystemMessage(requestId);
      final removedFollowUp = _removeFollowUpByRequestId(requestId);
      onResponseReceived(requestId);

      if (requestId.isNotEmpty &&
          _messages.any(
            (m) => !m.isUser && !m.isSystem && m.requestId == requestId,
          )) {
        return;
      }

      _messages.add(AriChatMessage(
        text: response,
        isUser: false,
        createdAt: DateTime.now(),
        requestId: requestId,
        appId: isInterAgent ? from : null,
        senderName: senderName.isNotEmpty ? senderName : null,
      ));

      notifyListeners();
      if (removedFollowUp) {
        notifyListeners();
      }
    });

    _progressSub = AriAgent.on('/AGENT.PROGRESS', (data) {
      final payload = data['data'] is Map ? data['data'] as Map : data;
      final progressMessage = payload['message']?.toString() ?? '';
      final requestId = payload['requestId']?.toString() ?? '';
      final msgAgent = payload['agentId']?.toString() ?? 'default';
      final from = payload['from']?.toString() ?? '';
      final to = payload['to']?.toString() ?? '';
      final senderName = payload['senderName']?.toString() ?? '';
      final isInterAgent = from.isNotEmpty && to.isNotEmpty && from != to;

      if (progressMessage.isEmpty) return;
      // inter-agent (ari 방 팬아웃 thinking 등) 은 발신측 agentId 가 다르므로 filter 우회.
      if (!isInterAgent &&
          _filterAgentId != null &&
          msgAgent != _filterAgentId) return;

      if (requestId.isNotEmpty) {
        _inFlightRequestIds.add(requestId);
      }
      if (requestId.startsWith('report-') || requestId.startsWith('sys-')) {
        _backgroundRequestIds.add(requestId);
      }
      _syncLoadingState();
      final removedFollowUp = _removeFollowUpByRequestId(requestId);

      // 발신자 라벨 prefix.
      final label = senderName.isNotEmpty ? senderName : from;
      final displayText = label.isNotEmpty ? '[$label] $progressMessage' : progressMessage;

      upsertSystemMessage(displayText, requestId);
      if (removedFollowUp) {
        notifyListeners();
      }
    });

    _followUpSub = AriAgent.on('/AGENT.FOLLOW_UP', (data) {
      final payload = data['data'] is Map ? data['data'] as Map : data;
      final requestId = payload['requestId']?.toString() ?? '';
      final message = payload['message']?.toString() ?? '';

      if (message.isEmpty || requestId.isEmpty) return;
      if (_queuedFollowUps.any((item) => item.requestId == requestId)) return;

      _messages.removeWhere((m) => m.isUser && m.requestId == requestId);
      _inFlightRequestIds.remove(requestId);
      _backgroundRequestIds.remove(requestId);
      if (_activeRequestId == requestId) {
        _activeRequestId = null;
      }
      _syncLoadingState();

      _queuedFollowUps.add(AriQueuedFollowUp(
        requestId: requestId,
        message: message,
      ));
      notifyListeners();
    });

    _cancelSub = AriAgent.on('/AGENT.CANCEL', (data) {
      final payload = data['data'] is Map ? data['data'] as Map : data;
      final cancelledRequestId = payload['requestId']?.toString() ?? '';

      // 특정 requestId 만 취소된 경우 그 요청 관련 상태만 정리.
      // (유저가 cancel 후 즉시 새 메시지를 보내면 서버의 늦은 취소 브로드캐스트가
      //  새 _activeRequestId 를 잘못 비우는 레이스를 막기 위함.)
      if (cancelledRequestId.isNotEmpty) {
        _messages.removeWhere(
          (m) => m.isSystem && m.requestId == cancelledRequestId,
        );
        _removeFollowUpByRequestId(cancelledRequestId);
        _inFlightRequestIds.remove(cancelledRequestId);
        _backgroundRequestIds.remove(cancelledRequestId);
        if (_activeRequestId == cancelledRequestId) {
          _activeRequestId = null;
        }
      } else {
        // requestId 없는 취소 (레거시/광역) 는 전체 정리.
        _clearPendingSystemMessages();
        _queuedFollowUps.clear();
        _backgroundRequestIds.clear();
        _inFlightRequestIds.clear();
        _activeRequestId = null;
      }
      _syncLoadingState();
      notifyListeners();
    });

    _noticeSub = AriAgent.on('/APP.NOTICE', (data) {
      final payload = data['data'] is Map ? data['data'] as Map : data;
      final message = payload['message']?.toString() ?? '';
      final noticeId = payload['noticeId']?.toString();
      final agentId = payload['agentId']?.toString();

      if (message.isEmpty) return;
      if (_filterAgentId != null &&
          agentId != null &&
          agentId != _filterAgentId) return;
      if (noticeId != null &&
          _messages.any((m) => m.isNotice && m.requestId == noticeId)) return;

      _messages.add(AriChatMessage(
        text: message,
        isUser: false,
        isNotice: true,
        createdAt: DateTime.now(),
        requestId: noticeId,
      ));
      notifyListeners();
    });

    _errorSub = AriAgent.on('/APP.ERROR', (data) {
      final payload = data['data'] is Map ? data['data'] as Map : data;
      final message = payload['message']?.toString() ?? '';
      final requestId = payload['requestId']?.toString() ?? '';
      final msgAgent = payload['agentId']?.toString() ?? 'default';

      if (message.isEmpty) return;
      if (_filterAgentId != null && msgAgent != _filterAgentId) return;

      if (requestId.isNotEmpty) removeSystemMessage(requestId);
      onResponseReceived(requestId);

      _messages.add(AriChatMessage(
        text: message,
        isUser: false,
        isError: true,
        createdAt: DateTime.now(),
        requestId: requestId.isNotEmpty ? requestId : null,
      ));
      notifyListeners();
    });

    _taskResultSub = AriAgent.on('/TASK_RESULT', (data) {
      final taskId = data['taskId']?.toString() ?? 'unknown';
      final requestId = data['requestId']?.toString() ?? '';
      if (taskId != 'unknown') {
        if (requestId.isNotEmpty) {
          _inFlightRequestIds.remove(requestId);
          _backgroundRequestIds.remove(requestId);
          removeSystemMessage(requestId);
        }
        _inFlightRequestIds.remove(taskId);
        _backgroundRequestIds.remove(taskId);
        removeSystemMessage(taskId);
        _syncLoadingState();
        notifyListeners();
      }
    });

    _workCommandSub = AriAgent.on('/APP.COMMAND', _handleWorkCommand);
  }

  void _handleWorkCommand(Map<String, dynamic> data) {
    final command = data['command']?.toString() ?? '';
    if (!command.startsWith('WORK.')) return;

    final rawParams = data['params'];
    final params = rawParams is Map
        ? Map<String, dynamic>.from(rawParams)
        : const <String, dynamic>{};
    final sessionId = params['id']?.toString();
    if (sessionId == null || sessionId.isEmpty) return;

    final appId = data['appId']?.toString() ?? '';

    if (command == 'WORK.START') {
      _workSessions[sessionId] = AriWorkSession(
        id: sessionId,
        appId: appId,
        startedAt: DateTime.now(),
        status: AriWorkStatus.running,
        steps: const <AriWorkStep>[],
        summary: params['summary']?.toString(),
        context: params['context'] is Map
            ? Map<String, dynamic>.from(params['context'] as Map)
            : null,
      );
    } else if (command == 'WORK.STEP') {
      final existing = _workSessions[sessionId];
      if (existing == null) return;
      final step = AriWorkStep(
        label: params['label']?.toString() ?? '',
        status: AriStepStatus.fromString(params['status']?.toString()),
        detail: params['detail']?.toString(),
        createdAt: DateTime.now(),
      );
      _workSessions[sessionId] = existing.copyWith(
        steps: [...existing.steps, step],
      );
    } else if (command == 'WORK.END') {
      final existing = _workSessions[sessionId];
      if (existing == null) return;
      _workSessions[sessionId] = existing.copyWith(
        completedAt: DateTime.now(),
        status: AriWorkStatus.fromString(params['status']?.toString()),
        summary: params['summary']?.toString() ?? existing.summary,
      );
    } else {
      return;
    }
    notifyListeners();
  }

  List<AriChatMessage> get messages => List.unmodifiable(_messages);

  /// 채팅 메시지와 작업 세션을 시간순으로 병합한 단일 아이템 목록.
  /// 채팅 패널이 렌더링하는 대상이다.
  List<AriChatItem> get items {
    final result = <AriChatItem>[..._messages, ..._workSessions.values];
    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return List.unmodifiable(result);
  }

  // 자식 클래스 오버라이드를 위한 훅 또는 내부 호출
  void onResponseReceived(String requestId) {
    if (requestId == _activeRequestId) _activeRequestId = null;
    if (requestId.isNotEmpty) _inFlightRequestIds.remove(requestId);
    if (requestId.isNotEmpty) {
      _backgroundRequestIds.remove(requestId);
    }
    _syncLoadingState();
  }

  // ── 페이지네이션 히스토리 ────────────────────────────────────
  String? _lastHistoryAgentId;
  String? _lastHistoryAppId;
  int _historyOffset = 0;
  bool _hasMoreHistory = true;
  bool _loadingOlderHistory = false;
  static const int _historyPageSize = 20;

  /// 더 로드할 과거 히스토리가 있는지
  bool get hasMoreHistory => _hasMoreHistory;

  /// 과거 히스토리 프리펜드 진행 중인지 (스크롤 유지용)
  bool get isLoadingOlderHistory => _loadingOlderHistory;

  /// 표준 서버 히스토리 불러오기 (최신 [_historyPageSize] 개).
  /// 기존 messages/workSessions 는 초기화된다.
  Future<void> loadServerHistory(String agentId, {String? appId}) async {
    if (!AriAgent.isConnected) return;
    try {
      final history = await _repository.fetchHistory(
        agentId,
        appId: appId,
        index: 0,
        size: _historyPageSize,
      );
      _lastHistoryAgentId = agentId;
      _lastHistoryAppId = appId;
      _historyOffset = history.length;
      _hasMoreHistory = history.length == _historyPageSize;
      _messages.clear();
      _workSessions.clear();
      for (final item in history) {
        if (item is AriChatMessage) {
          _messages.add(item);
        } else if (item is AriWorkSession) {
          _workSessions[item.id] = item;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AriChatProvider] 히스토리 로드 실패: $e');
    }
  }

  /// 다음 페이지(더 오래된) 히스토리를 불러와 앞쪽으로 prepend 한다.
  /// 이미 로드 중이거나 더 남은 페이지가 없으면 no-op.
  Future<void> loadOlderHistory() async {
    if (_loadingOlderHistory || !_hasMoreHistory) return;
    final agentId = _lastHistoryAgentId;
    if (agentId == null) return;

    _loadingOlderHistory = true;
    notifyListeners();
    try {
      final older = await _repository.fetchHistory(
        agentId,
        appId: _lastHistoryAppId,
        index: _historyOffset,
        size: _historyPageSize,
      );
      if (older.isEmpty) {
        _hasMoreHistory = false;
        return;
      }
      if (older.length < _historyPageSize) _hasMoreHistory = false;
      _historyOffset += older.length;

      // 기존 messages 앞쪽으로 오래된 아이템 prepend.
      final existing = List<AriChatMessage>.from(_messages);
      _messages.clear();
      for (final item in older) {
        if (item is AriChatMessage) {
          _messages.add(item);
        } else if (item is AriWorkSession) {
          // 이미 로드된 세션은 그대로 두고, 새 id 만 추가 (페이지 경계 partial 방어).
          _workSessions.putIfAbsent(item.id, () => item);
        }
      }
      _messages.addAll(existing);
      notifyListeners();
    } catch (e) {
      debugPrint('[AriChatProvider] 이전 히스토리 로드 실패: $e');
    } finally {
      _loadingOlderHistory = false;
      notifyListeners();
    }
  }

  /// 표준 에이전트 메시지 송신 API
  Future<void> sendAgentMessage(
    String text, {
    String? agentId,
    String? persona,
    String? avatarName,
    String? appId,
    Map<String, dynamic>? details,
    String platform = 'Client',
  }) async {
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    _activeRequestId = requestId;
    _inFlightRequestIds.add(requestId);
    _syncLoadingState();
    addUserMessage(text, requestId: requestId);
    notifyListeners();

    try {
      await _repository.sendMessage(
        message: text,
        requestId: requestId,
        agentId: agentId,
        persona: persona,
        avatarName: avatarName,
        appId: appId,
        details: details,
        platform: platform,
      );
    } catch (e, st) {
      debugPrint('[AriChatProvider] sendAgentMessage 오류: $e\n$st');
      _inFlightRequestIds.remove(requestId);
      _backgroundRequestIds.remove(requestId);
      final removedFollowUp = _removeFollowUpByRequestId(requestId);
      removeSystemMessage(requestId);
      if (_activeRequestId != requestId) {
        _syncLoadingState();
        if (removedFollowUp) {
          notifyListeners();
        }
        return;
      }
      addMessage(AriChatMessage(
        text: 'Cannot connect to agent. ($e)',
        isUser: false,
        isError: true,
        createdAt: DateTime.now(),
      ));
      _activeRequestId = null;
      _syncLoadingState();
    }
  }

  /// 송신 취소
  void cancelAgentMessage({String? agentId}) {
    if (!_isLoading) return;
    _repository.cancelMessage(agentId: agentId);
    _clearPendingSystemMessages();
    if (_activeRequestId != null) {
      _inFlightRequestIds.remove(_activeRequestId);
    }
    _backgroundRequestIds.clear();
    _queuedFollowUps.clear();
    _activeRequestId = null;
    _syncLoadingState();
    notifyListeners();
  }

  void upsertSystemMessage(String text, String requestId) {
    bool isMyRequest =
        _activeRequestId != null && requestId == _activeRequestId;
    bool isBackgroundRequest =
        requestId.startsWith('report-') || requestId.startsWith('sys-');
    // ari 방 팬아웃 sub-request (`${activeRequestId}-<appId>`) 도 같은 활성
    // 대화의 일부이므로 시스템 메시지로 표시 (PM·SARI thinking 동시 표기).
    bool isAriBroadcastSub = _activeRequestId != null &&
        requestId.startsWith('${_activeRequestId}-');
    if (!isMyRequest && !isBackgroundRequest && !isAriBroadcastSub) return;

    final idx = _messages.lastIndexWhere(
      (m) => m.isSystem && m.requestId == requestId,
    );
    final msg = AriChatMessage(
      text: text,
      isUser: false,
      isSystem: true,
      requestId: requestId,
      createdAt: DateTime.now(),
    );
    if (idx >= 0) {
      _messages[idx] = msg;
    } else {
      _messages.add(msg);
    }
    notifyListeners();
  }

  void removeSystemMessage(String requestId) {
    _messages.removeWhere((m) => m.isSystem && m.requestId == requestId);
    notifyListeners();
  }

  void addNoticeMessage(String text, {String? noticeId}) {
    if (noticeId != null &&
        _messages.any((m) => m.isNotice && m.requestId == noticeId)) return;
    _messages.add(AriChatMessage(
      text: text,
      isUser: false,
      isNotice: true,
      createdAt: DateTime.now(),
      requestId: noticeId,
    ));
    notifyListeners();
  }

  void addAiMessage(String text, {String? requestId}) {
    if (requestId != null &&
        _messages.any((m) => !m.isUser && m.requestId == requestId)) return;
    _messages.add(AriChatMessage(
      text: text,
      isUser: false,
      createdAt: DateTime.now(),
      requestId: requestId,
    ));
    notifyListeners();
  }

  void addUserMessage(String text, {String? requestId}) {
    if (requestId != null &&
        _messages.any((m) => m.isUser && m.requestId == requestId)) return;
    _messages.add(AriChatMessage(
      text: text,
      isUser: true,
      createdAt: DateTime.now(),
      requestId: requestId,
    ));
    notifyListeners();
  }

  void addMessage(AriChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  void setMessages(List<AriChatMessage> newMessages) {
    _messages.clear();
    _messages.addAll(newMessages);
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _workSessions.clear();
    _inFlightRequestIds.clear();
    _backgroundRequestIds.clear();
    _queuedFollowUps.clear();
    _activeRequestId = null;
    _syncLoadingState();
    notifyListeners();
  }

  Future<void> resetAgentSession({String? agentId}) async {
    try {
      await _repository.resetSession(agentId: agentId);
    } catch (e) {
      debugPrint('[AriChatProvider] 세션 리셋 실패: $e');
    }

    clearMessages();
  }

  /// 서버의 대화 이력을 삭제하고 로컬 메시지도 초기화합니다.
  Future<void> clearServerHistory(String agentId, {String? appId}) async {
    _repository.clearHistory(agentId, appId: appId);
    clearMessages();
  }

  @override
  void dispose() {
    _agentPushSub?.cancel();
    _agentRequestSub?.cancel();
    _progressSub?.cancel();
    _followUpSub?.cancel();
    _cancelSub?.cancel();
    _taskResultSub?.cancel();
    _noticeSub?.cancel();
    _errorSub?.cancel();
    _workCommandSub?.cancel();
    for (final sub in _customSubs) {
      sub.cancel();
    }
    super.dispose();
  }
}
