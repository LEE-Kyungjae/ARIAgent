import 'package:flutter/material.dart';

import 'agent_profile_icon.dart';

/// 에이전트 리스트/타일용 48px 원형 프로필 래퍼.
/// 실제 이미지 로드/폴백은 [AgentProfileIcon] 에 위임.
class AgentAvatar extends StatelessWidget {
  final String imagePath;

  const AgentAvatar({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF1A1A2E),
      child: AgentProfileIcon(imagePath: imagePath, size: 48),
    );
  }
}
