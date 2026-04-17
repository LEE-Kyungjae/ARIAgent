import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'token_management_screen.dart';
import '../widgets/tab_section_header.dart';
import '../../../l10n/app_localizations.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (context) => const _SettingsTabContent(),
      ),
    );
  }
}

class _SettingsTabContent extends StatelessWidget {
  const _SettingsTabContent();

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentProvider>();
    final avatarList = context.watch<AgentProvider>();

    final l10n = S.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabSectionHeader(
            icon: Icons.folder_outlined,
            title: l10n.settingsDataManagement,
            description: l10n.settingsDataManagementDesc,
          ),
          _buildNavigationButton(
            context,
            icon: Icons.token_outlined,
            title: l10n.settingsTokenManagement,
            description: l10n.settingsTokenDesc,
            destination: TokenManagementScreen(agentId: agent.currentAvatarId),
            destinationTitle: l10n.settingsTokenManagement,
          ),
          const SizedBox(height: 12),
          _buildSettingsButton(
            context,
            icon: Icons.psychology_outlined,
            title: l10n.settingsResetMemory,
            description: l10n.settingsResetMemoryDesc,
            onPressed: () => _confirmAction(
              context,
              l10n.settingsResetMemory,
              l10n.settingsResetMemoryConfirm,
              () => agent.initializeMemory(),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsButton(
            context,
            icon: Icons.chat_bubble_outline_rounded,
            title: l10n.settingsResetConversation,
            description: l10n.settingsResetConversationDesc,
            onPressed: () => _confirmAction(
              context,
              l10n.settingsResetConversation,
              l10n.settingsResetConversationConfirm,
              () async {
                final avatarId = agent.currentAvatarId;
                if (context.mounted) {
                  await context.read<AriChatProvider>().clearServerHistory(
                    avatarId,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          TabSectionHeader(
            icon: Icons.warning_amber_outlined,
            title: l10n.settingsDangerZone,
            description: l10n.settingsDangerZoneDesc,
          ),
          _buildSettingsButton(
            context,
            icon: Icons.delete_forever_outlined,
            title: l10n.settingsDeleteAvatar,
            description: l10n.settingsDeleteAvatarDesc,
            isCritical: true,
            onPressed: agent.currentAvatarId == 'default'
                ? null
                : () => _confirmAction(
                    context,
                    l10n.settingsDeleteAvatar,
                    l10n.settingsDeleteAvatarConfirm(agent.name),
                    () => avatarList.deleteAvatar(),
                  ),
          ),
          const SizedBox(height: 12),
          _buildSettingsButton(
            context,
            icon: Icons.folder_open_outlined,
            title: l10n.settingsOpenFolder,
            description: l10n.settingsOpenFolderDesc,
            isCritical: true,
            onPressed: () async {
              final home =
                  Platform.environment['HOME'] ??
                  Platform.environment['USERPROFILE'];

              if (home != null) {
                final path = '$home/.ari-agent';
                final uri = Uri.file(path);

                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  // Fallback for directories on some platforms
                  await launchUrl(Uri.parse('file://$path'));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.settingsHomeDirNotFound)),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Widget destination,
    required String destinationTitle,
  }) {
    const color = Color(0xFF6C63FF);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => _AvatarSettingsSubPage(
              title: destinationTitle,
              child: destination,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSettingsButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback? onPressed,
    bool isCritical = false,
  }) {
    final bool isDisabled = onPressed == null;
    final color = isCritical
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF6C63FF);

    return Opacity(
      opacity: isDisabled ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(isDisabled ? 0.05 : 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDisabled ? Colors.white54 : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDisabled)
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAction(
    BuildContext context,
    String title,
    String message,
    Future<void> Function() action,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).cancel, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await action();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(S.of(context).settingsActionCompleted(title)),
                    backgroundColor: const Color(0xFF6C63FF),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: Text(
              S.of(context).confirm,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarSettingsSubPage extends StatelessWidget {
  final String title;
  final Widget child;

  const _AvatarSettingsSubPage({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
