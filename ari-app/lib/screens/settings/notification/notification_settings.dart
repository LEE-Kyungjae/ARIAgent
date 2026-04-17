import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/config_provider.dart';

class NotificationSettings extends StatelessWidget {
  const NotificationSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Consumer<ConfigProvider>(
        builder: (context, configProvider, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Desktop Notifications'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: SwitchListTile(
                  title: Text(
                    S.of(context).notificationDaemonTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: Text(
                    S.of(context).notificationDaemonDesc,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  value: configProvider.isNotificationEnabled,
                  activeThumbColor: const Color(0xFF6C63FF),
                  onChanged: (val) async {
                    await configProvider.updateIsNotificationEnabled(val);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Scheduled Tasks'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: SwitchListTile(
                  title: Text(
                    S.of(context).notificationAutoTaskTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: Text(
                    S.of(context).notificationAutoTaskDesc,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  value: configProvider.showTaskMessages,
                  activeThumbColor: const Color(0xFF6C63FF),
                  onChanged: (val) async {
                    await configProvider.updateShowTaskMessages(val);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    );
  }
}
