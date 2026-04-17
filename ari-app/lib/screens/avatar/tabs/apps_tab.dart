import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/tab_section_header.dart';
import '../../../l10n/app_localizations.dart';

class AppsTab extends StatelessWidget {
  const AppsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // 에이전트 전환 감지 → ListenableBuilder가 새 agent 구독
    final provider = context.watch<AgentProvider>();
    final agent = provider.currentAgent;

    return ListenableBuilder(
      listenable: agent,
      builder: (context, _) => _buildContent(context, provider, agent),
    );
  }

  Widget _buildContent(
      BuildContext context, AgentProvider provider, AgentModel agent) {
    final agentId = agent.id;
    final apps = agent.installedApps;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: TabSectionHeader(
            icon: Icons.apps_rounded,
            title: S.of(context).appsTitle,
            description: S.of(context).appsDesc,
            trailing: TextButton.icon(
              onPressed: () async {
                final uri = Uri.parse('https://ariwith.me/store');
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
              icon: const Icon(Icons.storefront_rounded,
                  size: 14, color: Color(0xFF6C63FF)),
              label: Text(S.of(context).appsStore,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6C63FF))),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
        Expanded(
          child: apps.isEmpty
              ? _buildEmptyState(context)
              : RefreshIndicator(
                  onRefresh: () => agent.loadApps(),
                  color: const Color(0xFF6C63FF),
                  backgroundColor: const Color(0xFF1A1A2E),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      final isConnected =
                          agent.isAppConnected(app['name'] as String);
                      return _AppCard(
                        app: app,
                        agentId: agentId,
                        isConnected: isConnected,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = S.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apps_rounded,
              color: Colors.white.withValues(alpha: 0.2), size: 48),
          const SizedBox(height: 16),
          Text(l10n.appsNoApps,
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            l10n.appsCheckFolder,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final Map<String, dynamic> app;
  final String agentId;
  final bool isConnected;

  const _AppCard({
    required this.app,
    required this.agentId,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final appId = app['name'] as String;
    final title = (app['title'] as String?) ?? appId;
    final description = app['description'] as String?;
    final icon = app['icon'] as String?;
    final iconPath = app['iconPath'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
              : const Color(0xFF6C63FF).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(
                color: isConnected
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF6C63FF).withValues(alpha: 0.4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16).copyWith(left: 22),
              child: Row(
                children: [
                  _buildIcon(iconPath, icon),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? const Color(0xFF4CAF50)
                                        .withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isConnected ? S.of(context).appsConnected : S.of(context).appsOffline,
                                style: TextStyle(
                                  color: isConnected
                                      ? const Color(0xFF4CAF50)
                                      : Colors.white.withValues(alpha: 0.3),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isConnected)
                    IconButton(
                      icon: Icon(
                        Icons.play_circle_outline_rounded,
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.7),
                        size: 24,
                      ),
                      onPressed: () =>
                          context.read<AgentProvider>().launchApp(appId),
                    ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent.withValues(alpha: 0.7),
                      size: 18,
                    ),
                    onPressed: () async {
                      final l10n = S.of(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1A1A2E),
                          title: Text(l10n.appsDeleteTitle,
                              style: const TextStyle(color: Colors.white)),
                          content: Text(l10n.appsDeleteConfirm(title),
                              style:
                                  const TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(l10n.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(l10n.delete,
                                  style:
                                      const TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await context
                            .read<AgentProvider>()
                            .deleteApp(appId, agentId: agentId);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(String? iconPath, String? icon) {
    if (iconPath != null) {
      final file = File(iconPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(file, width: 44, height: 44, fit: BoxFit.cover),
        );
      }
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: icon != null
            ? Text(icon, style: const TextStyle(fontSize: 22))
            : Icon(Icons.extension_rounded,
                color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                size: 22),
      ),
    );
  }
}
