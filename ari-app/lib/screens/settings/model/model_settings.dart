import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/config_provider.dart';
import 'models/provider_item.dart';
import 'provider_card.dart';
import 'providers_notifier.dart';
import 'widgets/add_provider_button.dart';
import 'widgets/help_section.dart';
import 'widgets/server_connection_notice.dart';
import '../../../l10n/app_localizations.dart';

class ModelSettings extends StatelessWidget {
  const ModelSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProvidersNotifier>(
      create: (ctx) => ProvidersNotifier(
        Provider.of<ConfigProvider>(ctx, listen: false),
      )..attach(),
      child: const _ModelSettingsView(),
    );
  }
}

class _ModelSettingsView extends StatefulWidget {
  const _ModelSettingsView();

  @override
  State<_ModelSettingsView> createState() => _ModelSettingsViewState();
}

class _ModelSettingsViewState extends State<_ModelSettingsView> {
  bool _showHelp = false;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ProvidersNotifier>();
    final providers = notifier.providers;
    final saveStatus = notifier.saveStatus;

    if (providers.isEmpty) {
      return const ServerConnectionNotice();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context).modelProvidersPriority,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAutoSaveIndicator(saveStatus),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() => _showHelp = !_showHelp),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(
                        _showHelp ? Icons.help : Icons.help_outline,
                        size: 16,
                        color: _showHelp
                            ? const Color(0xFF6C63FF)
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_showHelp) ...[
            const SizedBox(height: 12),
            const HelpSection(),
          ],
          const SizedBox(height: 16),
          ...List.generate(providers.length, (i) {
            final item = providers[i];
            return ChangeNotifierProvider<ProviderItem>.value(
              key: ValueKey('provider_${item.accountId}'),
              value: item,
              child: ProviderCard(
                index: i,
                totalCount: providers.length,
              ),
            );
          }),
          const SizedBox(height: 12),
          AddProviderButton(onTap: notifier.addProvider),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAutoSaveIndicator(String saveStatus) {
    if (saveStatus.isEmpty) return const SizedBox.shrink();
    Color color;
    String text;
    Widget leading;
    switch (saveStatus) {
      case 'saving':
        color = Colors.white.withValues(alpha: 0.5);
        text = S.of(context).modelSaving;
        leading = SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: color,
          ),
        );
        break;
      case 'saved':
        color = const Color(0xFF4ADE80);
        text = S.of(context).modelSaved;
        leading = Icon(Icons.check_circle_outline, size: 12, color: color);
        break;
      case 'error':
        color = const Color(0xFFFF6B6B);
        text = S.of(context).modelSaveFailed;
        leading = Icon(Icons.error_outline, size: 12, color: color);
        break;
      case 'dirty':
        color = const Color(0xFFFFB155);
        text = S.of(context).modelUnsaved;
        leading = Icon(Icons.edit_outlined, size: 12, color: color);
        break;
      default:
        return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}
