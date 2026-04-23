import 'dart:io';

import 'package:ari_plugin/ari_plugin.dart';
import 'package:flutter/material.dart';

/// 에이전트/앱 프로필 아이콘 공통 위젯.
/// - `appId` 가 `null`/빈값/`"ari"` 이면 PM 아바타(에이전트 프로필 이미지 or 기본 ARI 아이콘)
/// - 그 외면 [installedApps] 에서 해당 앱 메타를 찾아 앱 아이콘 렌더
class AgentProfileIcon extends StatelessWidget {
  final String imagePath;
  final List<Map<String, dynamic>> installedApps;
  final String? appId;
  final double size;

  const AgentProfileIcon({
    super.key,
    this.imagePath = '',
    this.installedApps = const [],
    this.appId,
    this.size = 24,
  });

  /// 편의 생성자: [AgentModel] 에서 imagePath / installedApps 를 바로 꺼냄.
  factory AgentProfileIcon.fromAgent({
    Key? key,
    required AgentModel agent,
    String? appId,
    double size = 24,
  }) =>
      AgentProfileIcon(
        key: key,
        imagePath: agent.imagePath,
        installedApps: agent.installedApps,
        appId: appId,
        size: size,
      );

  /// 편의 생성자: 단일 앱 메타(맵)로 앱 아이콘만 렌더.
  factory AgentProfileIcon.app({
    Key? key,
    required Map<String, dynamic> app,
    double size = 24,
  }) =>
      AgentProfileIcon(
        key: key,
        installedApps: [app],
        appId: app['name'] as String?,
        size: size,
      );

  @override
  Widget build(BuildContext context) {
    if (appId != null && appId!.isNotEmpty && appId != 'ari') {
      return _domainIcon();
    }
    return _pmAvatar();
  }

  Widget _domainIcon() {
    final app = installedApps.firstWhere(
      (a) => a['name'] == appId,
      orElse: () => const <String, dynamic>{},
    );
    final iconPath = app['iconPath'] as String?;
    final iconName = app['icon'] as String?;
    final radius = BorderRadius.circular(size / 4);

    if (iconPath != null) {
      final file = File(iconPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: radius,
          child: Image.file(file,
              width: size, height: size, fit: BoxFit.cover),
        );
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: iconName != null && iconName.isNotEmpty
          ? Text(iconName, style: TextStyle(fontSize: size * 0.55))
          : Icon(Icons.extension_rounded,
              size: size * 0.55,
              color: const Color(0xFF6C63FF).withValues(alpha: 0.9)),
    );
  }

  Widget _pmAvatar() {
    final path = imagePath.trim();
    Widget image;
    if (path.startsWith('assets/')) {
      image = Image.asset(path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAriIcon());
    } else if (path.isNotEmpty && File(path).existsSync()) {
      image = Image.file(File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAriIcon());
    } else {
      image = _defaultAriIcon();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: image,
    );
  }

  Widget _defaultAriIcon() => Image.asset(
        'assets/images/avatar.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
}
