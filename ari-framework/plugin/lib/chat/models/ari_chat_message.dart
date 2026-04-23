/// 채팅 메시지 데이터 모델.
class AriChatMessage {
  final String text;
  final bool isUser;
  final bool isSystem;
  final bool isNotice;
  final bool isError;
  final DateTime createdAt;
  final String? requestId;
  /// 메시지 발신자 appId.
  /// - 어시스턴트 메시지: PM 아바타면 null, 도메인 에이전트(inter-agent)는 해당 앱 id.
  /// - 유저 메시지: 다른 앱이 대신 보낸 inter-agent 유저 요청이면 호출자 appId.
  final String? appId;
  /// 발신자 표시 이름(선택). 설치된 앱 메타에서 못 찾을 때의 폴백 라벨.
  final String? senderName;

  AriChatMessage({
    required this.text,
    required this.isUser,
    required this.createdAt,
    this.isSystem = false,
    this.isNotice = false,
    this.isError = false,
    this.requestId,
    this.appId,
    this.senderName,
  });
}
