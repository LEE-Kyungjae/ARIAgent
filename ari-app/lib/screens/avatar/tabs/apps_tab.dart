import 'dart:io';

import 'package:ari_plugin/ari_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../widgets/tab_section_header.dart';

class AppsTab extends StatelessWidget {
  const AppsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentProvider>().currentAgent;
    return ListenableBuilder(
      listenable: agent,
      builder: (context, _) {
        final apps = agent.installedApps;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TabSectionHeader(
              icon: Icons.apps_rounded,
              title: S.of(context).appsTitle,
              description: S.of(context).appsDesc,
            ),
            if (apps.isEmpty)
              _EmptyState()
            else
              ...apps.map(
                (app) => _AppPinRow(
                  app: app,
                  isPinned: agent.isAppPinned(app['name'] as String),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AppPinRow extends StatelessWidget {
  final Map<String, dynamic> app;
  final bool isPinned;

  const _AppPinRow({required this.app, required this.isPinned});

  Widget _buildIcon() {
    final iconPath = app['iconPath'] as String?;
    final iconName = app['icon'] as String?;
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
        color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: iconName != null
            ? Text(iconName, style: const TextStyle(fontSize: 20))
            : Icon(
                Icons.extension_rounded,
                size: 20,
                color: const Color(0xFF6C63FF).withValues(alpha: 0.7),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appId = app['name'] as String;
    final title = (app['title'] as String?) ?? appId;
    final description = app['description'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildIcon(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: isPinned,
            activeThumbColor: const Color(0xFF6C63FF),
            onChanged: (v) {
              final prov = context.read<AgentProvider>();
              if (v) {
                prov.pinApp(appId);
              } else {
                prov.unpinApp(appId);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.apps_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context).appsNoApps,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
