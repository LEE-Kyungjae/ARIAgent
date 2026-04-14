import 'dart:io';
import 'dart:math';

import 'package:ari_plugin/ari_plugin.dart';
import 'package:ari_agent/providers/home_assistant_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/place_avatar.dart';
import 'models/ha_device_item.dart';
import 'providers/place_agent_status_provider.dart';
import 'widgets/agent_avatar.dart';
import 'widgets/ha_device_icon.dart';
import 'widgets/ha_registration_sheet.dart';

class PlaceTab extends StatefulWidget {
  const PlaceTab({super.key});

  @override
  State<PlaceTab> createState() => _PlaceTabState();
}

class _PlaceTabState extends State<PlaceTab> {
  final Random _random = Random();
  final Map<String, Offset> _avatarPositions = {};
  final Map<String, Offset> _devicePositions = {};
  List<Map<String, dynamic>> _haDevices = [];
  Map<String, List<Map<String, dynamic>>> _agentApps = {};
  int _lastAppsVersion = -1;
  String _lastAvatarsKey = '';
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadHADevices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadInstalledApps();
    });
  }

  Future<void> _loadHADevices() async {
    final haProvider = Provider.of<HomeAssistantProvider>(context, listen: false);
    final devices = await haProvider.getHADevices();
    if (devices != null && mounted) {
      setState(() {
        _haDevices = devices;
        for (final device in _haDevices) {
          _devicePositions.putIfAbsent(device['id'] as String, () => _randomDevicePosition());
        }
      });
    }
  }

  Future<void> _loadInstalledApps() async {
    final myVersion = ++_loadVersion;
    final agent = Provider.of<AgentProvider>(context, listen: false);
    final avatarProvider = Provider.of<AgentProvider>(context, listen: false);
    // 에이전트 설정(appIds 포함)을 서버에서 먼저 갱신
    await avatarProvider.refreshAvatars();
    final allProfiles = avatarProvider.allAvatars;

    // 전체 설치된 앱 한 번만 로드 (place tab은 설치 현황 시각화 목적)
    final allApps = await agent.getApps();
    final Map<String, List<Map<String, dynamic>>> agentApps = {
      for (final profile in allProfiles) profile.id: allApps,
    };

    if (mounted && myVersion == _loadVersion) {
      setState(() {
        _agentApps = agentApps;
      });
    }
  }

  Offset _randomDevicePosition() => Offset(0.05 + _random.nextDouble() * 0.9, 0.15 + _random.nextDouble() * 0.45);
  Offset _randomPosition() => Offset(0.12 + _random.nextDouble() * 0.76, 0.6 + _random.nextDouble() * 0.22);

  Widget _buildAppIcon(Map<String, dynamic> app, List<String> connectedAppIds) {
    final appId = app['name'] as String;
    final iconName = app['icon'] as String?;
    final isConnected = connectedAppIds.contains(appId);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: '${app['title'] ?? appId}${isConnected ? ' (연결됨)' : ''}',
        child: Stack(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isConnected
                    ? const Color(0xFF6C63FF).withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isConnected
                      ? const Color(0xFF63FF88).withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.15),
                  width: isConnected ? 1.5 : 1.0,
                ),
              ),
              child: app['iconPath'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(app['iconPath'] as String),
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: iconName != null
                          ? Text(iconName, style: const TextStyle(fontSize: 15))
                          : Icon(
                              Icons.extension_rounded,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                    ),
            ),
            if (isConnected)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: const Color(0xFF63FF88),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF63FF88).withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentProvider>();
    final allProfiles = agent.allAvatars;
    final currentAvatarId = agent.currentAvatarId;
    final statusProvider = context.watch<PlaceAgentStatusProvider>();
    final connectedAppIds = agent.connectedAppIds;

    // 아바타 목록 변경 시 (WebSocket 수신 후) 재로드
    final avatarsKey = allProfiles.map((p) => p.id).join(',');
    if (avatarsKey != _lastAvatarsKey && avatarsKey.isNotEmpty) {
      _lastAvatarsKey = avatarsKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadInstalledApps();
      });
    }

    // 앱 설치/삭제 시 갱신
    if (agent.installedAppsVersion != _lastAppsVersion) {
      _lastAppsVersion = agent.installedAppsVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadInstalledApps();
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final avatars = allProfiles.map((profile) {
          _avatarPositions.putIfAbsent(
              profile.id,
              () => _seededPosition(_avatarPositions.length, allProfiles.length));
          return PlaceAvatar(
            profile: profile,
            position: _avatarPositions[profile.id]!,
            status: statusProvider.statusFor(
              profile.id,
              isSelected: profile.id == currentAvatarId,
            ),
          );
        }).toList();

        final devices = _haDevices
            .map((d) => HADeviceItem(
                  rawData: d,
                  position: _devicePositions[d['id']] ?? const Offset(0.5, 0.3),
                ))
            .toList();

        return Stack(
          children: [
            Positioned.fill(
                child: Image.asset('assets/images/room.png', fit: BoxFit.cover)),

            ...devices.map((device) => Positioned(
                  left: constraints.maxWidth * device.position.dx - 20,
                  top: constraints.maxHeight * device.position.dy - 20,
                  child: HADeviceIcon(
                    item: device,
                    onTap: () async {
                      final haProvider = context.read<HomeAssistantProvider>();
                      final success = await haProvider.controlHADevice(
                          device.id, 'toggle', domain: device.type);
                      if (success) _loadHADevices();
                    },
                  ),
                )),

            ...avatars.map((avatar) {
              final pos = _avatarPositions[avatar.profile.id]!;
              final apps = _agentApps[avatar.profile.id] ?? [];

              return Positioned(
                left: constraints.maxWidth * pos.dx - 48,
                top: constraints.maxHeight * pos.dy - 62,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      final current = _avatarPositions[avatar.profile.id]!;
                      _avatarPositions[avatar.profile.id] = Offset(
                        (current.dx + details.delta.dx / constraints.maxWidth).clamp(0.0, 1.0),
                        (current.dy + details.delta.dy / constraints.maxHeight).clamp(0.0, 1.0),
                      );
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AgentAvatar(item: avatar),
                      if (apps.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: apps
                                .map((app) => _buildAppIcon(app, connectedAppIds))
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.8),
                onPressed: () => setState(() {
                  for (final id in _avatarPositions.keys) {
                    _avatarPositions[id] = _randomPosition();
                  }
                  for (final id in _devicePositions.keys) {
                    _devicePositions[id] = _randomDevicePosition();
                  }
                }),
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: 'ha_connect',
                backgroundColor: const Color(0xFFFF5722).withValues(alpha: 0.8),
                onPressed: () => _startHAConnection(context).then((_) => _loadHADevices()),
                child: const Icon(Icons.home_filled, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Offset _seededPosition(int index, int total) {
    if (total <= 1) return const Offset(0.5, 0.72);
    final x = (0.15 + (0.7 / (total - 1) * index)).clamp(0.15, 0.85);
    final y = (0.66 + ((index % 2) * 0.08)).clamp(0.6, 0.82);
    return Offset(x, y);
  }

  Future<void> _startHAConnection(BuildContext context) async {
    final haProvider = Provider.of<HomeAssistantProvider>(context, listen: false);
    final existing = await haProvider.getHACredentials();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HARegistrationSheet(
        existing: existing,
        onSubmit: (url, token) {
          Navigator.pop(context);
          _submitHARegistration(context, url, token);
        },
      ),
    );
  }

  Future<void> _submitHARegistration(BuildContext context, String url, String token) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.orange)));
    final haProvider = Provider.of<HomeAssistantProvider>(context, listen: false);
    final result = await haProvider.saveHACredentials(url, token);
    if (!context.mounted) return;
    Navigator.pop(context);
    if (result['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Home Assistant 서버 연동에 성공했습니다.'), backgroundColor: Colors.green));
    } else {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
              title: const Text('연동 실패'),
              content: Text(result['error'] ?? '알 수 없는 오류가 발생했습니다.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))]));
    }
  }
}
