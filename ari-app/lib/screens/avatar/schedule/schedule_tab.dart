import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../widgets/tab_section_header.dart';
import '../../../l10n/app_localizations.dart';

part 'widgets/schedule_constants.dart';
part 'widgets/routine_card.dart';
part 'widgets/day_column.dart';
part 'widgets/day_view_grid.dart';
part 'widgets/week_overview.dart';
part 'widgets/task_detail_bar.dart';

// ── View mode ─────────────────────────────────────────────
enum _ViewMode { day, week }

// ─────────────────────────────────────────────────────────────────────────────
//  ScheduleTab
// ─────────────────────────────────────────────────────────────────────────────

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  bool _isLoading = false;
  List<AgentSchedule> _selectedTasks = [];
  _ViewMode _viewMode = _ViewMode.day;
  DateTime _viewDate = DateTime.now(); // 하루보기 기준 날짜
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _refreshTasks();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshTasks() async {
    setState(() => _isLoading = true);
    try {
      await context.read<AgentProvider>().refreshTasks();
    } catch (e) {
      debugPrint('[Schedule] ❌ 갱신 실패: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _scrollToNow() {
    final now = TimeOfDay.now();
    final targetPx =
        (now.hour * _kHourH + now.minute * _kHourH / 60).clamp(0.0, _kTotalH - 200);
    if (_scrollController.hasClients) _scrollController.jumpTo(targetPx);
  }

  void _onSlotSelected(List<AgentSchedule> tasks) {
    setState(() {
      final newIds = tasks.map((t) => t.id).toSet();
      final curIds = _selectedTasks.map((t) => t.id).toSet();
      _selectedTasks = newIds == curIds ? [] : tasks;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 에이전트 전환 감지 → ListenableBuilder가 새 agent 구독
    final agentProvider = context.watch<AgentProvider>();
    final agentModel = agentProvider.currentAgent;

    return ListenableBuilder(
      listenable: agentModel,
      builder: (context, _) =>
          _buildContent(context, agentProvider, agentModel),
    );
  }

  Widget _buildContent(
      BuildContext context, AgentProvider agent, AgentModel agentModel) {
    final allTasks = agentModel.tasks;

    final dayTaskLists = List.generate(7, (_) => <AgentSchedule>[]);
    for (final task in allTasks) {
      _assignToDays(task, dayTaskLists);
    }

    final selectedIds = _selectedTasks.map((t) => t.id).toList();
    final today = DateTime.now().weekday % 7;

    return Column(
      children: [
        // ── 헤더 ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TabSectionHeader(
            icon: Icons.calendar_month_outlined,
            title: S.of(context).scheduleTitle(agent.name),
            description: S.of(context).scheduleDesc,
            trailing: GestureDetector(
              onTap: _refreshTasks,
              child: _isLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: _kAccent),
                    )
                  : Icon(Icons.refresh, size: 16,
                      color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
        ),

        // ── 뷰 토글 ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _ViewToggleBtn(
                label: S.of(context).scheduleDayView,
                active: _viewMode == _ViewMode.day,
                onTap: () {
                  setState(() => _viewMode = _ViewMode.day);
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollToNow());
                },
              ),
              const SizedBox(width: 6),
              _ViewToggleBtn(
                label: S.of(context).scheduleWeekView,
                active: _viewMode == _ViewMode.week,
                onTap: () => setState(() => _viewMode = _ViewMode.week),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── 시간표 ────────────────────────────────────────
        Expanded(
          child: allTasks.isEmpty
              ? Center(
                  child: Text(
                    S.of(context).scheduleEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 12, height: 1.6,
                    ),
                  ),
                )
              : _viewMode == _ViewMode.week
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: _kWeekViewW + 32,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _WeekHeader(width: _kWeekViewW),
                                const SizedBox(height: 4),
                                _DayHeader(today: today, leftWidth: _kWeekLabelW),
                                Container(
                                  height: 1, width: _kWeekViewW,
                                  color: Colors.white.withValues(alpha: 0.07),
                                ),
                                WeekOverview(
                                  dayTaskLists: dayTaskLists,
                                  selectedTaskId: selectedIds.firstOrNull,
                                  onTaskSelected: (id) {
                                    final t = allTasks.firstWhere(
                                      (t) => t.id == id,
                                      orElse: () => allTasks.first,
                                    );
                                    _onSlotSelected([t]);
                                  },
                                  today: today,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final colW = constraints.maxWidth - 32 - _kTimeColW;
                        return SingleChildScrollView(
                          controller: _scrollController,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DayViewHeader(
                                  viewDate: _viewDate,
                                  colWidth: colW,
                                  onPrev: () => setState(() {
                                    _viewDate = _viewDate.subtract(const Duration(days: 1));
                                    _selectedTasks = [];
                                  }),
                                  onNext: () => setState(() {
                                    _viewDate = _viewDate.add(const Duration(days: 1));
                                    _selectedTasks = [];
                                  }),
                                  onToday: () => setState(() {
                                    _viewDate = DateTime.now();
                                    _selectedTasks = [];
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) => _scrollToNow());
                                  }),
                                ),
                                Container(
                                  height: 1,
                                  width: _kTimeColW + colW,
                                  color: Colors.white.withValues(alpha: 0.07),
                                ),
                                _DayViewGrid(
                                  tasks: allTasks,
                                  selectedTaskIds: selectedIds,
                                  onSlotSelected: _onSlotSelected,
                                  colWidth: colW,
                                  displayDate: _viewDate,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),

        // ── 선택 상세 ─────────────────────────────────────
        if (_selectedTasks.isNotEmpty)
          _TaskDetailBar(
            tasks: _selectedTasks,
            onClose: () => setState(() => _selectedTasks = []),
            onDelete: (task) async {
              await agent.deleteTask(task.id);
              setState(() => _selectedTasks =
                  _selectedTasks.where((t) => t.id != task.id).toList());
            },
            onToggle: (task) async {
              await agent.toggleTask(task.id);
            },
          ),
      ],
    );
  }

  static void _assignToDays(
    AgentSchedule task,
    List<List<AgentSchedule>> dayLists,
  ) {
    if (task.isOneOff) {
      final wd = task.startAt.toLocal().weekday % 7;
      dayLists[wd].add(task);
      return;
    }
    final type = task.scheduleSpec?['type'] as String?;
    if (type == 'daily') {
      for (int d = 0; d < 7; d++) { dayLists[d].add(task); }
    } else if (type == 'weekly') {
      final rawDays = task.scheduleSpec?['days'];
      if (rawDays is List) {
        for (final d in rawDays) { dayLists[(d as num).toInt()].add(task); }
      }
    } else {
      for (int d = 0; d < 7; d++) { dayLists[d].add(task); }
    }
  }
}

// ── 요일 헤더 ────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final int today;
  final double leftWidth;

  const _DayHeader({required this.today, this.leftWidth = _kTimeColW});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          SizedBox(width: leftWidth),
          ...List.generate(7, (i) {
            final isToday = i == today;
            final color = i == 0
                ? const Color(0xFFFF6B6B)
                : i == 6
                    ? const Color(0xFF6B9EFF)
                    : Colors.white.withValues(alpha: 0.5);
            return SizedBox(
              width: _kCardW,
              child: Center(
                child: isToday
                    ? Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                            color: _kAccent, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(_kDayNames[i],
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      )
                    : Text(_kDayNames[i],
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── 주간 헤더 ─────────────────────────────────────────────

class _WeekHeader extends StatelessWidget {
  final double width;
  const _WeekHeader({required this.width});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final ordinals = [
      l10n.scheduleWeekOrdinal1,
      l10n.scheduleWeekOrdinal2,
      l10n.scheduleWeekOrdinal3,
      l10n.scheduleWeekOrdinal4,
      l10n.scheduleWeekOrdinal5,
    ];
    final now = DateTime.now();

    // 이번 주 일요일 ~ 토요일
    final weekday = now.weekday % 7; // 0=일, 1=월, ..., 6=토
    final sunday = now.subtract(Duration(days: weekday));
    final saturday = sunday.add(const Duration(days: 6));

    // 몇째 주 (일요일 기준)
    final weekOfMonth = ((sunday.day - 1) ~/ 7).clamp(0, 4);
    final ordinal = ordinals[weekOfMonth];

    // 날짜 범위 표시
    final sameMonth = sunday.month == saturday.month;
    final range = sameMonth
        ? l10n.scheduleDateRangeSameMonth(sunday.month, sunday.day, saturday.day)
        : l10n.scheduleDateRangeDiffMonth(sunday.month, sunday.day, saturday.month, saturday.day);

    return SizedBox(
      width: width,
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.scheduleThisWeek,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.scheduleMonthWeek(sunday.month, ordinal),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            range,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 뷰 토글 버튼 ─────────────────────────────────────────

class _ViewToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ViewToggleBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _kAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? _kAccent : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
