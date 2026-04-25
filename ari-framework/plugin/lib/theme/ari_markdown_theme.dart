import 'package:flutter/material.dart';

/// ARI 마크다운 뷰/편집기/Diff 뷰의 색상 커스터마이징 설정.
class AriMarkdownTheme {
  final Color primaryColor;
  final Color accentGreen;
  final Color accentRed;
  final Color textMain;
  final Color textSub;

  const AriMarkdownTheme({
    this.primaryColor = const Color(0xFF3182F6),
    this.accentGreen = const Color(0xFF2E7D32),
    this.accentRed = const Color(0xFFD32F2F),
    this.textMain = const Color(0xFF191F28),
    this.textSub = const Color(0xFF4E5968),
  });
}
