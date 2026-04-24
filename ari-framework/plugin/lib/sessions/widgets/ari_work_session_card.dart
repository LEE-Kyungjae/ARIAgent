import 'package:flutter/material.dart';

import '../../theme/ari_chat_theme.dart';
import '../models/ari_work_session.dart';
import '../models/ari_work_step.dart';

/// 채팅 스트림에 인라인으로 표시되는 작업 세션 카드.
///
/// AI 가 `WORK.START → STEP* → END` 를 호출한 결과를 한 장의 카드로 렌더링한다.
/// 진행 중인 세션은 자동으로 펼쳐진 상태를 유지한다.
class AriWorkSessionCard extends StatefulWidget {
  const AriWorkSessionCard({
    super.key,
    required this.session,
    required this.theme,
  });

  final AriWorkSession session;
  final AriChatTheme theme;

  @override
  State<AriWorkSessionCard> createState() => _AriWorkSessionCardState();
}

class _AriWorkSessionCardState extends State<AriWorkSessionCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.session.status == AriWorkStatus.running;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final theme = widget.theme;
    final accent = _statusColor(s.status, theme);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    _StatusDot(color: accent, pulse: s.status == AriWorkStatus.running),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.summary ?? _statusLabel(s.status),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.textMain,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _footerLabel(s),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: theme.textSub,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded && s.steps.isNotEmpty) ...[
              Divider(height: 1, color: theme.borderColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: _StepFlow(steps: s.steps, theme: theme),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(AriWorkStatus status) => switch (status) {
        AriWorkStatus.running => '진행 중',
        AriWorkStatus.completed => '작업 완료',
        AriWorkStatus.failed => '작업 실패',
      };

  String _footerLabel(AriWorkSession s) {
    final time = _fmtTime(s.startedAt);
    final steps = s.steps.length;
    final duration = s.duration;
    if (duration != null) {
      final mins = duration.inMinutes;
      final secs = duration.inSeconds % 60;
      return '$time · ${mins}분 ${secs}초 · $steps단계';
    }
    return '$time · $steps단계';
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

Color _statusColor(AriWorkStatus status, AriChatTheme theme) => switch (status) {
      AriWorkStatus.running => theme.primaryColor,
      AriWorkStatus.completed => const Color(0xFF00B341),
      AriWorkStatus.failed => const Color(0xFFE6463A),
    };

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.pulse});
  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: pulse
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
    );
  }
}

class _StepFlow extends StatelessWidget {
  const _StepFlow({required this.steps, required this.theme});
  final List<AriWorkStep> steps;
  final AriChatTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _StepRow(step: steps[i], theme: theme),
          if (i < steps.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Container(
                width: 1,
                height: 10,
                color: theme.borderColor,
              ),
            ),
        ],
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.theme});
  final AriWorkStep step;
  final AriChatTheme theme;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (step.status) {
      AriStepStatus.done => (
          Icons.check_circle_rounded,
          const Color(0xFF00B341),
        ),
      AriStepStatus.running => (
          Icons.radio_button_checked,
          theme.primaryColor,
        ),
      AriStepStatus.pending => (
          Icons.radio_button_unchecked,
          theme.borderColor,
        ),
      AriStepStatus.failed => (
          Icons.cancel_rounded,
          const Color(0xFFE6463A),
        ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: step.status == AriStepStatus.pending
                      ? theme.textSub
                      : theme.textMain,
                ),
              ),
              if (step.detail != null && step.detail!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    step.detail!,
                    style: TextStyle(fontSize: 11, color: theme.textSub),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
