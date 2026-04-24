/// 채팅 패널에 시간순으로 표시되는 아이템의 공용 타입.
///
/// 구현체:
/// - [AriChatMessage] — 일반 채팅/시스템 메시지
/// - `AriWorkSession` — 작업 세션 (sessions/ 모듈)
abstract class AriChatItem {
  /// 시간순 정렬용 타임스탬프.
  DateTime get timestamp;
}
