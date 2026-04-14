import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';

class PlaceAgentAppsBar extends StatelessWidget {
  final List<AgentModel> allProfiles;
  final Map<String, List<Map<String, dynamic>>> agentApps;
  final List<String> connectedAppIds;
  final bool isLoading;

  const PlaceAgentAppsBar({
    super.key,
    required this.allProfiles,
    required this.agentApps,
    required this.connectedAppIds,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 36,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
          ),
        ),
      );
    }

    final profilesWithApps = allProfiles
        .where((p) => (agentApps[p.id] ?? []).isNotEmpty)
        .toList();

    if (profilesWithApps.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < profilesWithApps.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 10,
                    thickness: 0.5,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                _AgentAppsRow(
                  profile: profilesWithApps[i],
                  apps: agentApps[profilesWithApps[i].id] ?? [],
                  connectedAppIds: connectedAppIds,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentAppsRow extends StatelessWidget {
  final AgentModel profile;
  final List<Map<String, dynamic>> apps;
  final List<String> connectedAppIds;

  const _AgentAppsRow({
    required this.profile,
    required this.apps,
    required this.connectedAppIds,
  });

  Widget _buildAvatarIcon() {
    if (profile.imagePath.isNotEmpty) {
      final file = File(profile.imagePath);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(file, width: 24, height: 24, fit: BoxFit.cover),
        );
      }
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person_rounded, size: 14, color: Colors.white70),
    );
  }

  Widget _buildAppIcon(BuildContext context, Map<String, dynamic> app) {
    final appId = app['name'] as String;
    final iconName = app['icon'] as String?;
    final isConnected = connectedAppIds.contains(appId);

    return Padding(
      key: ValueKey(appId),
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: '${app['title'] ?? appId}${isConnected ? ' (연결됨)' : ''}',
        child: GestureDetector(
          onTap: () => context.read<AgentProvider>().launchApp(appId),
          child: Stack(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isConnected
                      ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isConnected
                        ? const Color(0xFF63FF88).withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.08),
                    width: isConnected ? 1.5 : 1.0,
                  ),
                ),
                child: app['iconPath'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.file(
                          File(app['iconPath'] as String),
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: iconName != null
                            ? Text(iconName, style: const TextStyle(fontSize: 16))
                            : Icon(
                                Icons.extension_rounded,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                      ),
              ),
              if (isConnected)
                Positioned(
                  right: 3,
                  top: 3,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFF63FF88),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF63FF88).withValues(alpha: 0.5),
                          blurRadius: 3,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          _buildAvatarIcon(),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 56),
            child: Text(
              profile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white.withValues(alpha: 0.2),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: apps
                    .map((app) => _buildAppIcon(context, app))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
