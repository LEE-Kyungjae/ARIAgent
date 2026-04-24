import 'package:flutter/material.dart';

import '../markdown/ari_markdown_editor.dart';
import 'ari_agent_next_schedule_footer.dart';
import 'ari_agent_run_bar.dart';

/// AI와 사용자가 공동으로 관리하는 마크다운 문서 화면.
///
/// - 상단: [header] 슬롯 (앱 고유 헤더)
/// - 섹션 라벨 + [AriMarkdownEditor]
/// - 가이드 문구 + 글복사/삭제 버튼 2개 (가운데 정렬)
/// - 다음 스케줄 카운트다운 ([AriAgentNextScheduleFooter])
/// - 1회 실행 버튼 ([AriAgentRunBar])
///
/// FloARI(조사방법), SARI(업무지시서), STARI/Bitnari(매매전략) 화면의 공용 레이아웃.
class AriAgentWorkspace extends StatelessWidget {
  const AriAgentWorkspace({
    super.key,
    required this.appId,
    required this.sectionTitle,
    required this.content,
    this.previousContent,
    this.hasDiff = false,
    required this.onApproveAll,
    required this.onRejectAll,
    required this.onPartialUpdate,
    this.onEditSave,
    this.onBlockSelected,
    required this.noteText,
    required this.copyLabel,
    required this.deleteLabel,
    required this.onCopy,
    required this.onDelete,
    required this.runButtonLabel,
    required this.onRun,
    this.runHintText,
    this.header,
    this.listPadding = const EdgeInsets.all(16),
    this.primaryColor = const Color(0xFF3182F6),
    this.sectionLabelColor,
    this.textSubColor = const Color(0xFF4E5968),
    this.textMainColor = const Color(0xFF191F28),
    this.surfaceColor = const Color(0xFFFFFFFF),
    this.borderColor = const Color(0x1A191F28),
    this.nextScheduleLabelBuilder,
  });

  final String appId;

  final Widget? header;
  final EdgeInsetsGeometry listPadding;

  // ── 본문 ─────────────────────────────────────────────
  final String sectionTitle;
  final String content;
  final String? previousContent;
  final bool hasDiff;
  final VoidCallback onApproveAll;
  final VoidCallback onRejectAll;
  final void Function(String updatedContent, String updatedPrevious)
      onPartialUpdate;
  final void Function(String updatedContent)? onEditSave;
  final void Function(String? selectedBlock)? onBlockSelected;

  // ── 가이드 + 버튼 ────────────────────────────────────
  final String noteText;
  final String copyLabel;
  final String deleteLabel;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  // ── 하단 실행 바 ─────────────────────────────────────
  final String runButtonLabel;
  final String? runHintText;
  final VoidCallback onRun;

  // ── 스케줄 푸터 ──────────────────────────────────────
  final String Function(String remainingText, String taskLabel)?
      nextScheduleLabelBuilder;

  // ── 테마 ─────────────────────────────────────────────
  final Color primaryColor;
  final Color? sectionLabelColor;
  final Color textSubColor;
  final Color textMainColor;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final labelColor = sectionLabelColor ?? primaryColor;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: listPadding,
            children: [
              if (header != null) ...[
                header!,
                const SizedBox(height: 20),
              ],
              _SectionLabel(
                title: sectionTitle,
                barColor: primaryColor,
                labelColor: labelColor,
              ),
              AriMarkdownEditor(
                content: content,
                previousContent: previousContent,
                hasDiff: hasDiff,
                onApproveAll: onApproveAll,
                onRejectAll: onRejectAll,
                onPartialUpdate: onPartialUpdate,
                onBlockSelected: onBlockSelected,
                onEditSave: onEditSave,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.center,
                child: Text(
                  noteText,
                  style: TextStyle(color: textSubColor, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SubtleTextButton(
                    icon: Icons.copy_rounded,
                    label: copyLabel,
                    onPressed: onCopy,
                    foregroundColor: textSubColor,
                  ),
                  const SizedBox(width: 4),
                  _SubtleTextButton(
                    icon: Icons.delete_outline_rounded,
                    label: deleteLabel,
                    onPressed: onDelete,
                    foregroundColor: textSubColor,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        AriAgentNextScheduleFooter(
          appId: appId,
          textSubColor: textSubColor,
          labelBuilder: nextScheduleLabelBuilder,
        ),
        AriAgentRunBar(
          label: runButtonLabel,
          hintText: runHintText,
          onStart: onRun,
          primaryColor: primaryColor,
          surfaceColor: surfaceColor,
          textSubColor: textSubColor,
          borderColor: borderColor,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.barColor,
    required this.labelColor,
  });

  final String title;
  final Color barColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 12),
      child: Row(
        children: [
          Container(width: 3, height: 14, color: barColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: labelColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtleTextButton extends StatelessWidget {
  const _SubtleTextButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: foregroundColor,
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
