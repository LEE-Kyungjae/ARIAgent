import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'package:ari_plugin/ari_plugin.dart' show AgentProvider;

import '../providers/config_provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/server_provider.dart';
import '../services/app_update_service.dart';
import 'avatar/avatar_tab.dart';
import 'chat/chat_tab.dart';
import 'home/home_constants.dart';
import 'home/home_drag_handle.dart';
import 'friends/friends_tab.dart';
import 'home/home_server_required_overlay.dart';
import 'home/home_tab_bar.dart';
import 'home/home_update_banner.dart';
import 'place/place_tab.dart';
import 'settings/settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _launcherInstallFolderName = 'ARIAgent Launcher';
  static const String _launcherExecutableName = 'ARI_Launcher.exe';

  final AppUpdateService _appUpdateService = const AppUpdateService();
  int _currentTab = 1;
  AppUpdateInfo? _availableUpdate;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
      _updateTimer = Timer.periodic(const Duration(hours: 12), (timer) {
        _checkForUpdates();
      });
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    try {
      final update = await _appUpdateService.checkForUpdate();
      if (!mounted) {
        return;
      }

      setState(() {
        _availableUpdate = update;
      });
    } catch (e) {
      debugPrint('Update check error: $e');
    }
  }

  Future<void> _doUpdate() async {
    try {
      if (Platform.isWindows) {
        final launcherPath = _installedWindowsLauncherPath();
        if (launcherPath != null && await File(launcherPath).exists()) {
          await Process.start(
            launcherPath,
            const [],
            mode: ProcessStartMode.detached,
            workingDirectory: File(launcherPath).parent.path,
          );
          exit(0);
        }

        final update = _availableUpdate;
        if (update != null) {
          await _appUpdateService.openDownloadUrl(update);
        }
        return;
      }

      final appPath = '/Applications/ARIAgent.app';
      if (await Directory(appPath).exists()) {
        await Process.run('open', [appPath]);
        exit(0);
      }

      if (!mounted) {
        return;
      }

      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2A),
          title: Text(
            S.of(context).errorAppNotFound,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            S.of(context).errorAppNotFoundMessage,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                S.of(context).confirm,
                style: const TextStyle(color: Color(0xFF6C63FF)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Update fail: $e');
      exit(0);
    }
  }

  String? _installedWindowsLauncherPath() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.isEmpty) {
      return null;
    }

    return '$localAppData\\Programs\\$_launcherInstallFolderName\\$_launcherExecutableName';
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final theme = config.backgroundTheme;
    final isWindows = Platform.isWindows;
    final isLight =
        theme == 'light_obsolete'; // Medium gray is dark enough for white icons

    final backgroundColor = homeBackgroundColorForTheme(theme);

    final windowContent = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: null,
        boxShadow: isWindows
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
      ),
      child: Column(
        children: [
          HomeDragHandle(isLight: isLight),
          if (_availableUpdate != null)
            HomeUpdateBanner(
              update: _availableUpdate!,
              onUpdatePressed: _doUpdate,
            ),
          HomeTabBar(
            currentTab: _currentTab,
            isLight: isLight,
            onTabSelected: (index) {
              if (index == 0) {
                AgentProvider().refreshAvatars();
                AgentProvider().refreshTasks();
              }
              setState(() {
                _currentTab = index;
              });
            },
          ),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );

    final windowShell = ClipRRect(
      borderRadius: BorderRadius.circular(homeWindowRadius),
      child: ColoredBox(
        color: backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(homeWindowResizePadding),
          child: windowContent,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: isWindows
          ? DragToResizeArea(resizeEdgeSize: 8, child: windowShell)
          : windowContent,
    );
  }

  Widget _buildTabContent() {
    return IndexedStack(
      index: _currentTab,
      children: [
        FriendsTab(onOpenChat: () => setState(() => _currentTab = 1)),
        const ChatTab(),
        _withServerGuard(const PlaceTab()),
        _withServerGuard(const AvatarTab()),
        const SettingsTab(),
      ],
    );
  }

  Widget _withServerGuard(Widget child) {
    return ListenableBuilder(
      listenable: ServerProvider(),
      builder: (context, _) => !ServerProvider().isRunning
          ? HomeServerRequiredOverlay(
              onGoToSettings: () => setState(() => _currentTab = 4),
            )
          : child,
    );
  }
}
