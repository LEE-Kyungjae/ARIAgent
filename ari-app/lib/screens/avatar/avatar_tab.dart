import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import 'tabs/profile_tab.dart';
import 'tabs/memory_tab.dart';
import 'schedule/schedule_tab.dart';
import 'tabs/apps_tab.dart';
import 'tabs/skills_tab.dart';
import 'tabs/tools_tab.dart';
import 'tabs/channels_tab.dart';
import 'tabs/settings_tab.dart';
import '../../providers/config_provider.dart';

/// 마우스 드래그로 스크롤 가능하게 하는 커스텀 ScrollBehavior
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class AvatarTab extends StatefulWidget {
  const AvatarTab({super.key});

  @override
  State<AvatarTab> createState() => _AvatarTabState();
}

class _AvatarTabState extends State<AvatarTab> {
  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final showAdvanced = config.showAdvancedDeveloperUI;

    final List<Widget> tabs = [
      const Tab(text: 'Profile'),
      const Tab(text: 'Schedule'),
      const Tab(text: 'Memory'),
      const Tab(text: 'Apps'),
      if (showAdvanced) const Tab(text: 'Skills'),
      if (showAdvanced) const Tab(text: 'Tools'),
      const Tab(text: 'Channels'),
      const Tab(text: 'Settings'),
    ];

    final List<Widget> views = [
      ProfileTab(),
      const ScheduleTab(),
      const MemoryTab(),
      const AppsTab(),
      if (showAdvanced) SkillsTab(),
      if (showAdvanced) ToolsTab(),
      ChannelsTab(),
      SettingsTab(),
    ];

    return DefaultTabController(
      key: ValueKey(showAdvanced),
      length: tabs.length,
      child: Column(
        children: [
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Color(0xFF6C63FF), width: 2),
              ),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFF6C63FF),
              unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
              overlayColor: WidgetStateProperty.resolveWith<Color?>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.white.withValues(alpha: 0.05);
                }
                return Colors.transparent;
              }),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: tabs,
            ),
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: AppScrollBehavior(),
              child: TabBarView(children: views),
            ),
          ),
        ],
      ),
    );
  }
}
