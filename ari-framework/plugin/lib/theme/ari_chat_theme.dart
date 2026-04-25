import 'package:flutter/material.dart';

/// ARI 채팅 위젯의 색상/스타일 커스터마이징 설정.
///
class AriChatTheme {
  final Color primaryColor;
  final Color surfaceColor;
  final Color backgroundColor;
  final Color textMain;
  final Color textSub;
  final Color borderColor;
  final double borderWidth;
  final Color hintColor;

  /// AI 버블 전용 오버라이드. null 이면 surfaceColor/textMain 사용.
  final Color? aiBubbleColor;
  final Color? aiBubbleTextColor;

  /// 채팅 패널 상단 헤더 배경. null 이면 surfaceColor 사용.
  final Color? headerColor;

  /// 채팅 패널 상단 헤더 글자색. null 이면 textMain/textSub 사용.
  final Color? headerTextColor;

  /// 채팅 패널 최외곽 그라디언트. null 이면 surfaceColor 단색 사용.
  final Gradient? panelGradient;

  /// 유저 말풍선 그라디언트. null 이면 primaryColor 단색 사용.
  final Gradient? userBubbleGradient;

  /// AI 말풍선 그라디언트. null 이면 aiBubbleColor/surfaceColor 단색 사용.
  final Gradient? aiBubbleGradient;

  /// 채팅 입력창(TextField 컨테이너) 테두리 색. null 이면 borderColor 사용.
  final Color? inputBorderColor;

  /// 채팅 입력창 입력 글자색. null 이면 textMain 사용.
  final Color? inputTextColor;

  /// 채팅 입력창 힌트 글자색. null 이면 hintColor 사용.
  final Color? inputHintColor;

  /// 전송 버튼 그라디언트. null 이면 primaryColor 단색 사용.
  final Gradient? sendButtonGradient;

  /// 채팅 입력창 외곽(입력 pill + 전송버튼 감싸는 하단 바) 배경색.
  /// 기본값은 투명 — 패널 배경이 그대로 비침.
  final Color inputAreaColor;

  /// 작업 세션(워크 스텝) 카드의 외곽 테두리 색. null 이면 borderColor 사용.
  final Color? workSessionBorderColor;

  /// 채팅 빈 상태(메시지 없음 가이드)의 아이콘 배경색. null 이면 primaryColor @5% 사용.
  final Color? emptyStateIconBackgroundColor;

  /// 채팅 빈 상태의 아이콘 색. null 이면 primaryColor @30% 사용.
  final Color? emptyStateIconColor;

  /// 채팅 빈 상태의 가이드 메세지 텍스트 색. null 이면 textMain 사용.
  final Color? emptyStateTextColor;

  const AriChatTheme({
    this.primaryColor = const Color(0xFF3182F6),
    this.surfaceColor = const Color(0xFFFFFFFF),
    this.backgroundColor = const Color(0xFFF2F4F6),
    this.textMain = const Color(0xFF191F28),
    this.textSub = const Color(0xFF4E5968),
    this.borderColor = const Color(0x1A191F28),
    this.borderWidth = 1.0,
    this.hintColor = const Color(0x61191F28),
    this.aiBubbleColor,
    this.aiBubbleTextColor,
    this.headerColor,
    this.headerTextColor,
    this.panelGradient,
    this.userBubbleGradient,
    this.aiBubbleGradient,
    this.inputBorderColor,
    this.inputTextColor,
    this.inputHintColor,
    this.sendButtonGradient,
    this.inputAreaColor = const Color(0x00000000),
    this.workSessionBorderColor,
    this.emptyStateIconBackgroundColor,
    this.emptyStateIconColor,
    this.emptyStateTextColor,
  });
}
