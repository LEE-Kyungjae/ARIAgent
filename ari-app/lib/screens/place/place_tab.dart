import 'dart:io';
import 'dart:math';

import 'package:ari_plugin/ari_plugin.dart';
import 'package:ari_agent/providers/home_assistant_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';

import 'models/place_avatar.dart';
import 'models/ha_device_item.dart';
import 'providers/place_agent_status_provider.dart';
import 'widgets/agent_avatar.dart';
import 'widgets/ha_device_icon.dart';
import 'widgets/ha_registration_sheet.dart';

class PlaceTab extends StatefulWidget {
  final VoidCallback? onOpenChat;

  const PlaceTab({super.key, this.onOpenChat});

  @override
  State<PlaceTab> createState() => _PlaceTabState();
}

class _PlaceTabState extends State<PlaceTab> {
  final Random _random = Random();
  final Map<String, Offset> _avatarPositions = {};
  final Map<String, Offset> _devicePositions = {};
  final Map<String, Offset> _appPositions = {};
  List<Map<String, dynamic>> _haDevices = [];

  @override
  void initState() {
    super.initState();
    _loadHADevices();
  }

  Future<void> _loadHADevices() async {
    final haProvider =
        Provider.of<HomeAssistantProvider>(context, listen: false);
    final devices = await haProvider.getHADevices();
    if (devices != null && mounted) {
      setState(() {
        _haDevices = devices;
        for (final device in _haDevices) {
          _devicePositions.putIfAbsent(
              device['id'] as String, () => _randomDevicePosition());
        }
      });
    }
  }

  Offset _randomDevicePosition() =>
      Offset(0.05 + _random.nextDouble() * 0.9,
          0.15 + _random.nextDouble() * 0.35);

  Offset _randomAppPosition() =>
      Offset(0.1 + _random.nextDouble() * 0.8,
          0.35 + _random.nextDouble() * 0.2);

  Offset _randomPosition() =>
      Offset(0.12 + _random.nextDouble() * 0.76,
          0.6 + _random.nextDouble() * 0.22);

  Widget _buildFloatingApp(
    Map<String, dynamic> app,
    bool isConnected,
    BoxConstraints constraints,
  ) {
    final appId = app['name'] as String;
    final iconName = app['icon'] as String?;
    final title = (app['title'] as String?) ?? appId;
    final pos = _appPositions[appId]!;

    return Positioned(
      key: ValueKey('app-$appId'),
      left: constraints.maxWidth * pos.dx - 26,
      top: constraints.maxHeight * pos.dy - 26,
      child: GestureDetector(
        onTap: () => context.read<AgentProvider>().launchApp(appId),
        onPanUpdate: (details) {
          setState(() {
            final current = _appPositions[appId]!;
            _appPositions[appId] = Offset(
              (current.dx + details.delta.dx / constraints.maxWidth)
                  .clamp(0.0, 1.0),
              (current.dy + details.delta.dy / constraints.maxHeight)
                  .clamp(0.0, 1.0),
            );
          });
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(
            message:
                '$title${isConnected ? ' (${S.of(context).placeConnected})' : ''}',
            child: Opacity(
              opacity: isConnected ? 1.0 : 0.6,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 53,
                      height: 53,
                      decoration: BoxDecoration(
                        color: isConnected
                            ? const Color(0xFF6C63FF).withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isConnected
                              ? const Color(0xFF63FF88).withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.2),
                          width: isConnected ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: app['iconPath'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(app['iconPath'] as String),
                                width: 53,
                                height: 53,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: iconName != null
                                  ? Text(iconName,
                                      style: const TextStyle(fontSize: 24))
                                  : Icon(Icons.extension_rounded,
                                      size: 24,
                                      color:
                                          Colors.white.withValues(alpha: 0.7)),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isConnected) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF63FF88),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF63FF88)
                                    .withValues(alpha: 0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final avatars = allProfiles.map((profile) {
          _avatarPositions.putIfAbsent(
            profile.id,
            () => _seededPosition(
                _avatarPositions.length, allProfiles.length),
          );
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
                  position: _devicePositions[d['id']] ??
                      const Offset(0.5, 0.3),
                ))
            .toList();

        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/room.png',
                  fit: BoxFit.cover),
            ),

            ...devices.map((device) => Positioned(
                  left: constraints.maxWidth * device.position.dx - 20,
                  top: constraints.maxHeight * device.position.dy - 20,
                  child: HADeviceIcon(
                    item: device,
                    onTap: () async {
                      final haProvider =
                          context.read<HomeAssistantProvider>();
                      final success = await haProvider.controlHADevice(
                          device.id, 'toggle',
                          domain: device.type);
                      if (success) _loadHADevices();
                    },
                  ),
                )),

            ...avatars.map((avatar) {
              final pos = _avatarPositions[avatar.profile.id]!;

              return Positioned(
                key: ValueKey(avatar.profile.id),
                left: constraints.maxWidth * pos.dx - 48,
                top: constraints.maxHeight * pos.dy - 62,
                child: GestureDetector(
                  onDoubleTap: () {
                    context
                        .read<AgentProvider>()
                        .switchAvatar(avatar.profile.id);
                    widget.onOpenChat?.call();
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      final current =
                          _avatarPositions[avatar.profile.id]!;
                      _avatarPositions[avatar.profile.id] = Offset(
                        (current.dx +
                                details.delta.dx / constraints.maxWidth)
                            .clamp(0.0, 1.0),
                        (current.dy +
                                details.delta.dy / constraints.maxHeight)
                            .clamp(0.0, 1.0),
                      );
                    });
                  },
                  child: AgentAvatar(item: avatar),
                ),
              );
            }),

            ListenableBuilder(
              listenable: agent.currentAgent,
              builder: (context, _) {
                final apps = agent.currentAgent.installedApps;
                final connectedIds = agent.currentAgent.connectedAppIds;
                final activeIds =
                    apps.map((a) => a['name'] as String).toSet();
                _appPositions.removeWhere((id, _) => !activeIds.contains(id));
                for (final id in activeIds) {
                  _appPositions.putIfAbsent(id, () => _randomAppPosition());
                }
                return Stack(
                  children: apps
                      .map((app) => _buildFloatingApp(
                            app,
                            connectedIds.contains(app['name'] as String),
                            constraints,
                          ))
                      .toList(),
                );
              },
            ),

            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor:
                    const Color(0xFF6C63FF).withValues(alpha: 0.8),
                onPressed: () => setState(() {
                  for (final id in _avatarPositions.keys) {
                    _avatarPositions[id] = _randomPosition();
                  }
                  for (final id in _devicePositions.keys) {
                    _devicePositions[id] = _randomDevicePosition();
                  }
                  for (final id in _appPositions.keys) {
                    _appPositions[id] = _randomAppPosition();
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
                backgroundColor:
                    const Color(0xFFFF5722).withValues(alpha: 0.8),
                onPressed: () => _startHAConnection(context)
                    .then((_) => _loadHADevices()),
                child:
                    const Icon(Icons.home_filled, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Offset _seededPosition(int index, int total) {
    if (total <= 1) return const Offset(0.5, 0.72);
    final x =
        (0.15 + (0.7 / (total - 1) * index)).clamp(0.15, 0.85);
    final y = (0.66 + ((index % 2) * 0.08)).clamp(0.6, 0.82);
    return Offset(x, y);
  }

  Future<void> _startHAConnection(BuildContext context) async {
    final haProvider =
        Provider.of<HomeAssistantProvider>(context, listen: false);
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

  Future<void> _submitHARegistration(
      BuildContext context, String url, String token) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.orange)),
    );
    final haProvider =
        Provider.of<HomeAssistantProvider>(context, listen: false);
    final result = await haProvider.saveHACredentials(url, token);
    if (!context.mounted) return;
    Navigator.pop(context);
    if (result['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.of(context).haIntegrationSuccess),
          backgroundColor: Colors.green));
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.of(context).errorIntegrationFailed),
          content: Text(result['error'] ?? S.of(context).errorUnknown),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).confirm))
          ],
        ),
      );
    }
  }
}
