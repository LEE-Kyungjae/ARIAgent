import 'package:flutter/material.dart';
import 'ari_markdown_diff_view.dart';
import 'ari_markdown_view.dart';

class AriMarkdownEditor extends StatelessWidget {
  const AriMarkdownEditor({
    super.key,
    required this.content,
    this.previousContent,
    this.hasDiff = false,
    required this.onApproveAll,
    required this.onRejectAll,
    required this.onPartialUpdate,
    this.onBlockSelected,
    this.onEditSave,
  });

  final String content;
  final String? previousContent;
  final bool hasDiff;

  final VoidCallback onApproveAll;
  final VoidCallback onRejectAll;
  final Function(String updatedContent, String updatedPrevious) onPartialUpdate;
  final void Function(String? selectedBlock)? onBlockSelected;

  /// 뷰 모드에서 더블클릭 인라인 편집 활성화. null 이면 비활성.
  /// 편집 완료(포커스 아웃) 시 전체 content 전달.
  final void Function(String updatedContent)? onEditSave;

  @override
  Widget build(BuildContext context) {
    if (hasDiff && previousContent != null) {
      return AriMarkdownDiffView(
        currentContent: content,
        previousContent: previousContent!,
        onApproveAll: onApproveAll,
        onRejectAll: onRejectAll,
        onPartialUpdate: onPartialUpdate,
      );
    }

    return AriMarkdownView(
      content: content,
      onBlockSelected: onBlockSelected,
      onEditSave: onEditSave,
    );
  }
}
