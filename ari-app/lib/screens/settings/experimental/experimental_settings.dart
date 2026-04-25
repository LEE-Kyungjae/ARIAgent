import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/config_provider.dart';

class ExperimentalSettings extends StatefulWidget {
  const ExperimentalSettings({super.key});

  @override
  State<ExperimentalSettings> createState() => _ExperimentalSettingsState();
}

class _ExperimentalSettingsState extends State<ExperimentalSettings> {
  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Advanced Features'),
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
                S.of(context).experimentalShowAdvancedTools,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              subtitle: Text(
                S.of(context).experimentalShowAdvancedToolsDesc,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
              value: config.showAdvancedDeveloperUI,
              activeThumbColor: const Color(0xFF6C63FF),
              onChanged: (value) async {
                await config.updateShowAdvancedDeveloperUI(value);
              },
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Experimental Features'),
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
                S.of(context).experimentalEnableExperimental,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              subtitle: Text(
                S.of(context).experimentalEnableExperimentalDesc,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
              value: config.isExperimentalEnabled,
              activeThumbColor: const Color(0xFF6C63FF),
              onChanged: (value) async {
                await config.updateIsExperimentalEnabled(value);
              },
            ),
          ),
        ],
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
