import '../../bridge/agent/AriAgent.dart';
import '../../sessions/models/ari_work_session.dart';
import '../../sessions/models/ari_work_step.dart';
import '../models/ari_chat_item.dart';
import '../models/ari_chat_message.dart';

/// 채팅 서버 통신 전담 Repository.
/// 상태 관리 없음 — 액션만.
class ChatRepository {
  static final ChatRepository _instance = ChatRepository._internal();
  factory ChatRepository() => _instance;
  ChatRepository._internal();

  /// 서버 히스토리 조회 → [AriChatItem] 목록 반환.
  /// - `chat`/`notice`/`task` → [AriChatMessage]
  /// - `work_start|work_step|work_end` → `sessionId` 로 그루핑된 [AriWorkSession]
  Future<List<AriChatItem>> fetchHistory(
    String agentId, {
    String? appId,
    int index = 0,
    int size = 50,
  }) async {
    final response = await AriAgent.call('/CHAT.GET_HISTORY', {
      'agentId': agentId,
      if (appId != null) 'appId': appId,
      'index': index,
      'size': size,
    });

    final List logs = response['logs'] ?? [];
    final items = <AriChatItem>[];
    final workSessions = <String, _WorkSessionBuilder>{};

    for (final log in logs.reversed) {
      final type = log['type'];
      if (type == 'chat') {
        final from = log['from']?.toString();
        final to = log['to']?.toString();
        final isInterAgent =
            from != null && from.isNotEmpty && to != null && from != to;
        items.add(AriChatMessage(
          text: log['message']?.toString() ?? '',
          isUser: log['isUser'] == true,
          isError: log['isError'] == true,
          createdAt: _parseTimestamp(log['timestamp']),
          requestId: log['requestId']?.toString(),
          appId: isInterAgent ? from : null,
        ));
      } else if (type == 'notice') {
        items.add(AriChatMessage(
          text: log['message']?.toString() ?? '',
          isUser: false,
          isNotice: true,
          createdAt: _parseTimestamp(log['timestamp']),
          requestId: log['noticeId']?.toString(),
        ));
      } else if (type == 'task') {
        final label = log['label'] ?? 'Scheduled task';
        final result = log['result'] ?? '';
        items.add(AriChatMessage(
          text: '🕒 [$label] Execution result:\n$result',
          isUser: false,
          createdAt: _parseTimestamp(log['timestamp']),
        ));
      } else if (type == 'work_start') {
        final sessionId = log['sessionId']?.toString();
        if (sessionId == null) continue;
        final builder = workSessions.putIfAbsent(
          sessionId,
          () => _WorkSessionBuilder(
            id: sessionId,
            appId: log['appId']?.toString() ?? appId ?? '',
          ),
        );
        builder.startedAt = _parseTimestamp(log['timestamp']);
        builder.summary = log['summary']?.toString() ?? builder.summary;
        final ctx = log['context'];
        if (ctx is Map) {
          builder.context = Map<String, dynamic>.from(ctx);
        }
      } else if (type == 'work_step') {
        final sessionId = log['sessionId']?.toString();
        if (sessionId == null) continue;
        final builder = workSessions.putIfAbsent(
          sessionId,
          () => _WorkSessionBuilder(
            id: sessionId,
            appId: log['appId']?.toString() ?? appId ?? '',
          ),
        );
        builder.steps.add(AriWorkStep(
          label: log['label']?.toString() ?? '',
          status: AriStepStatus.fromString(log['status']?.toString()),
          detail: log['detail']?.toString(),
          createdAt: _parseTimestamp(log['timestamp']),
        ));
      } else if (type == 'work_end') {
        final sessionId = log['sessionId']?.toString();
        if (sessionId == null) continue;
        final builder = workSessions.putIfAbsent(
          sessionId,
          () => _WorkSessionBuilder(
            id: sessionId,
            appId: log['appId']?.toString() ?? appId ?? '',
          ),
        );
        builder.completedAt = _parseTimestamp(log['timestamp']);
        builder.status = AriWorkStatus.fromString(log['status']?.toString());
        builder.summary = log['summary']?.toString() ?? builder.summary;
      }
    }

    for (final builder in workSessions.values) {
      items.add(builder.build());
    }

    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return items;
  }

  /// 에이전트에 메시지 송신.
  ///
  /// 원칙: 발신 소켓이 자기 페르소나를 payload 로 동봉한다. 호출자가 명시적으로
  /// `persona`/`avatarName` 을 넘기지 않으면 [AriAgent.ownPersona] 를 사용한다.
  Future<void> sendMessage({
    required String message,
    required String requestId,
    String? agentId,
    String? persona,
    String? avatarName,
    String? appId,
    Map<String, dynamic>? details,
    String platform = 'Client',
  }) async {
    final own = AriAgent.ownPersona;
    final resolvedPersona = persona ?? own?.systemPrompt;
    final resolvedAvatarName = avatarName ?? own?.name;

    await AriAgent.call('/AGENT', {
      'message': message,
      'requestId': requestId,
      if (agentId != null) 'agentId': agentId,
      if (resolvedPersona != null) 'persona': resolvedPersona,
      if (resolvedAvatarName != null) 'avatarName': resolvedAvatarName,
      if (appId != null) 'appId': appId,
      if (details != null) 'details': details,
      'platform': platform,
    });
  }

  /// 진행 중인 요청 취소
  void cancelMessage({String? agentId}) {
    final payload = <String, dynamic>{};
    if (agentId != null) payload['agentId'] = agentId;
    AriAgent.emit('/AGENT.CANCEL', payload);
  }

  /// 에이전트 세션 리셋
  Future<void> resetSession({String? agentId}) async {
    final payload = <String, dynamic>{};
    if (agentId != null) payload['agentId'] = agentId;
    await AriAgent.call('/AGENT.RESET', payload);
  }

  /// 서버 대화 이력 삭제
  void clearHistory(String agentId, {String? appId}) {
    AriAgent.emit('/CHAT.CLEAR', {
      'agentId': agentId,
      if (appId != null) 'appId': appId,
    });
  }
}

DateTime _parseTimestamp(Object? raw) {
  if (raw is String && raw.isNotEmpty) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}

class _WorkSessionBuilder {
  _WorkSessionBuilder({required this.id, required this.appId});

  final String id;
  final String appId;
  DateTime startedAt = DateTime.now();
  DateTime? completedAt;
  AriWorkStatus status = AriWorkStatus.running;
  String? summary;
  Map<String, dynamic>? context;
  final List<AriWorkStep> steps = [];

  AriWorkSession build() => AriWorkSession(
        id: id,
        appId: appId,
        startedAt: startedAt,
        completedAt: completedAt,
        status: status,
        steps: List<AriWorkStep>.from(steps),
        summary: summary,
        context: context,
      );
}
