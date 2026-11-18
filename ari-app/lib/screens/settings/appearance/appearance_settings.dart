import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/config_provider.dart';

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Window Settings'),
          const SizedBox(height: 8),
          Consumer<ConfigProvider>(
            builder: (context, configProvider, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        S.of(context).settingsPinToDesktop,
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      subtitle: Text(
                        S.of(context).settingsPinToDesktopDesc,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                      value: configProvider.isPinned,
                      activeThumbColor: const Color(0xFF6C63FF),
                      onChanged: (val) async {
                        await configProvider.updateIsPinned(val);
                        await windowManager.setAlwaysOnTop(val);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(S.of(context).appearanceSpaceUsage),
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
                        S.of(context).appearanceUnifySpace,
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      subtitle: Text(
                        S.of(context).appearanceUnifySpaceDesc,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                      value: configProvider.isSpaceUnified,
                      activeThumbColor: const Color(0xFF6C63FF),
                      onChanged: (val) =>
                          configProvider.updateIsSpaceUnified(val),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('Avatar Settings'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          S.of(context).settingsAvatarSize,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        Flexible(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _configButton(
                                context,
                                S.of(context).settingsAvatarSizeSmall,
                                configProvider.avatarSize == 'small',
                                () => configProvider.updateAvatarSize('small'),
                              ),
                              _configButton(
                                context,
                                S.of(context).settingsAvatarSizeMedium,
                                configProvider.avatarSize == 'medium',
                                () => configProvider.updateAvatarSize('medium'),
                              ),
                              _configButton(
                                context,
                                S.of(context).appearanceLarge,
                                configProvider.avatarSize == 'large',
                                () => configProvider.updateAvatarSize('large'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(S.of(context).appearanceLanguage),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          S.of(context).appearanceLanguage,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        Flexible(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _configButton(
                                context,
                                '한국어',
                                configProvider.localeCode == 'ko',
                                () => configProvider.updateLocale('ko'),
                              ),
                              _configButton(
                                context,
                                'English',
                                configProvider.localeCode == 'en',
                                () => configProvider.updateLocale('en'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('Background Theme'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          S.of(context).appearanceBgTheme,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        Flexible(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _configButton(
                                context,
                                S.of(context).appearanceDark,
                                configProvider.backgroundTheme == 'dark',
                                () =>
                                    configProvider.updateBackgroundTheme('dark'),
                              ),
                              _configButton(
                                context,
                                S.of(context).appearanceBlue,
                                configProvider.backgroundTheme == 'blue',
                                () =>
                                    configProvider.updateBackgroundTheme('blue'),
                              ),
                              _configButton(
                                context,
                                S.of(context).appearancePurple,
                                configProvider.backgroundTheme == 'purple',
                                () => configProvider
                                    .updateBackgroundTheme('purple'),
                              ),
                              _configButton(
                                context,
                                S.of(context).appearanceGray,
                                configProvider.backgroundTheme == 'gray',
                                () =>
                                    configProvider.updateBackgroundTheme('gray'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _configButton(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 50),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6C63FF)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Center(
          widthFactor: 1.0,
          heightFactor: 1.0,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
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
