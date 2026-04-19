import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import 'model/model_settings.dart';
import 'server/server_settings.dart';
import 'appearance/appearance_settings.dart';
import 'experimental/experimental_settings.dart';
import 'notification/notification_settings.dart';
import 'about/about_settings.dart';
import '../../../providers/server_provider.dart';
import '../../../providers/config_provider.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const _SettingsCategoryList(),
        );
      },
    );
  }
}

class _SettingsCategoryList extends StatelessWidget {
  const _SettingsCategoryList();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ServerProvider(),
        context.watch<ConfigProvider>(),
      ]),
      builder: (context, _) {
        final isServerRunning = ServerProvider().isRunning;
        final l10n = S.of(context);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCategoryItem(
              context,
              Icons.psychology_rounded,
              isServerRunning
                  ? l10n.settingsModelDesc
                  : l10n.settingsModelDescDisabled,
              isEnabled: isServerRunning,
              page: const ModelSettings(),
              title: 'Model Settings',
            ),
            _buildCategoryItem(
              context,
              Icons.dns_rounded,
              l10n.settingsServerDesc,
              isEnabled: true,
              page: const ServerSettings(),
              title: 'Agent Settings',
            ),
            _buildCategoryItem(
              context,
              Icons.palette_rounded,
              l10n.settingsAppearanceDesc,
              isEnabled: true,
              page: const AppearanceSettings(),
              title: 'Appearance',
            ),
            _buildCategoryItem(
              context,
              Icons.notifications_none_rounded,
              l10n.settingsNotificationDesc,
              isEnabled: true,
              page: const NotificationSettings(),
              title: 'Notification',
            ),
            _buildCategoryItem(
              context,
              Icons.science_outlined,
              isServerRunning
                  ? l10n.settingsExperimentalDesc
                  : l10n.settingsExperimentalDescDisabled,
              isEnabled: isServerRunning,
              page: const ExperimentalSettings(),
              title: 'Advanced & Labs',
            ),
            _buildCategoryItem(
              context,
              Icons.info_outline_rounded,
              l10n.settingsAboutDesc,
              isEnabled: true,
              page: const AboutSettings(),
              title: 'App Intro',
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryItem(
    BuildContext context,
    IconData icon,
    String subtitle, {
    required bool isEnabled,
    required Widget page,
    required String title,
  }) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF6C63FF)),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white12),
          onTap: isEnabled
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          _SettingsSubPage(title: title, child: page),
                    ),
                  );
                }
              : null,
        ),
      ),
    );
  }
}

class _SettingsSubPage extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSubPage({required this.title, required this.child});

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
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
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
