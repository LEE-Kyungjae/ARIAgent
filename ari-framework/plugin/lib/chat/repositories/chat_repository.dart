import '../../bridge/agent/AriAgent.dart';
import '../models/ari_chat_message.dart';

/// 채팅 서버 통신 전담 Repository.
/// 상태 관리 없음 — 액션만.
class ChatRepository {
  static final ChatRepository _instance = ChatRepository._internal();
  factory ChatRepository() => _instance;
  ChatRepository._internal();

  /// 서버 히스토리 조회 → [AriChatMessage] 목록 반환
  Future<List<AriChatMessage>> fetchHistory(
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
    final history = <AriChatMessage>[];

    for (final log in logs.reversed) {
      if (log['type'] == 'chat') {
        history.add(AriChatMessage(
          text: log['message']?.toString() ?? '',
          isUser: log['isUser'] == true,
          isError: log['isError'] == true,
          createdAt: DateTime.now(),
          requestId: log['requestId']?.toString(),
        ));
      } else if (log['type'] == 'notice') {
        history.add(AriChatMessage(
          text: log['message']?.toString() ?? '',
          isUser: false,
          isNotice: true,
          createdAt: DateTime.now(),
          requestId: log['noticeId']?.toString(),
        ));
      } else if (log['type'] == 'task') {
        final label = log['label'] ?? 'Scheduled task';
        final result = log['result'] ?? '';
        history.add(AriChatMessage(
          text: '🕒 [$label] Execution result:\n$result',
          isUser: false,
          createdAt: DateTime.now(),
        ));
      }
    }

    return history;
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
