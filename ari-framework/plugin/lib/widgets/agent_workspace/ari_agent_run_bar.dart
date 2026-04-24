import 'package:flutter/material.dart';

/// 워크스페이스 하단의 "1회 실행" 버튼 영역.
/// [hintText] 가 비어있으면 위쪽 힌트 박스는 그리지 않는다.
class AriAgentRunBar extends StatelessWidget {
  const AriAgentRunBar({
    super.key,
    required this.label,
    required this.onStart,
    this.hintText,
    this.primaryColor = const Color(0xFF3182F6),
    this.surfaceColor = const Color(0xFFFFFFFF),
    this.textSubColor = const Color(0xFF4E5968),
    this.borderColor = const Color(0x1A191F28),
  });

  final String label;
  final VoidCallback onStart;
  final String? hintText;
  final Color primaryColor;
  final Color surfaceColor;
  final Color textSubColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final hint = hintText;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hint != null && hint.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 13,
                    color: primaryColor.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      hint,
                      style: TextStyle(
                        fontSize: 11,
                        color: textSubColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
