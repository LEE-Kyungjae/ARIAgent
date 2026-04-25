import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../theme/ari_markdown_theme.dart';

class AriMarkdownView extends StatefulWidget {
  const AriMarkdownView({
    super.key,
    required this.content,
    this.padding = const EdgeInsets.fromLTRB(18, 24, 18, 18),
    this.borderRadius = 24,
    this.theme = const AriMarkdownTheme(),
    this.onBlockSelected,
    this.onEditSave,
  });

  final String content;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final AriMarkdownTheme theme;

  /// 블록 선택/해제 시 호출. 선택 해제 시 null 전달.
  final void Function(String? selectedBlock)? onBlockSelected;

  /// 블록 더블클릭 시 해당 문단만 인라인 편집.
  /// 포커스 아웃 시 변경된 전체 content 를 전달. null 이면 편집 비활성.
  final void Function(String updatedContent)? onEditSave;

  @override
  State<AriMarkdownView> createState() => _AriMarkdownViewState();
}

class _AriMarkdownViewState extends State<AriMarkdownView> {
  int? _selectedIndex;
  int? _hoveredIndex;

  int? _editingIndex;
  TextEditingController? _editController;
  FocusNode? _editFocus;

  @override
  void dispose() {
    _editFocus?.dispose();
    _editController?.dispose();
    super.dispose();
  }

  List<String> _currentBlocks() => widget.content
      .split('\n\n')
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();

  void _startEditing(int index, String blockText) {
    if (widget.onEditSave == null) return;

    // 기존 편집 중이던 컨트롤러 정리
    _editFocus?.removeListener(_handleFocusChange);
    _editFocus?.dispose();
    _editController?.dispose();

    final controller = TextEditingController(text: blockText);
    final focus = FocusNode();
    focus.addListener(_handleFocusChange);

    setState(() {
      _editingIndex = index;
      _editController = controller;
      _editFocus = focus;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focus.requestFocus();
    });
  }

  void _handleFocusChange() {
    if (_editFocus?.hasFocus == false && _editingIndex != null) {
      _commit();
    }
  }

  void _commit() {
    final idx = _editingIndex;
    final ctrl = _editController;
    if (idx == null || ctrl == null) {
      if (mounted) setState(() => _editingIndex = null);
      return;
    }

    final blocks = _currentBlocks();
    final newText = ctrl.text.trim();

    if (idx < blocks.length && newText != blocks[idx]) {
      if (newText.isEmpty) {
        blocks.removeAt(idx);
      } else {
        blocks[idx] = newText;
      }
      widget.onEditSave?.call(blocks.join('\n\n'));
    }

    if (mounted) setState(() => _editingIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _currentBlocks();

    final style = MarkdownStyleSheet(
      p: TextStyle(fontSize: 12, height: 1.6, color: widget.theme.textMain),
      strong:
          TextStyle(fontWeight: FontWeight.w700, color: widget.theme.textMain),
      h1: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: widget.theme.textMain),
      h2: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: widget.theme.textMain),
      h3: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: widget.theme.textMain),
      listBullet: TextStyle(fontSize: 12, color: widget.theme.textMain),
      blockquote:
          TextStyle(color: widget.theme.textSub, fontSize: 12, height: 1.6),
    );

    return Container(
      width: double.infinity,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
            color: widget.theme.primaryColor.withValues(alpha: 0.2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            if (_editingIndex == i)
              _buildEditingBlock()
            else
              _buildViewBlock(i, blocks[i], style),
          ],
        ],
      ),
    );
  }

  Widget _buildEditingBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.theme.primaryColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.theme.primaryColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: _editController,
        focusNode: _editFocus,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.5,
          color: widget.theme.textMain,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: '마크다운 원본…',
          hintStyle: TextStyle(
            color: widget.theme.textSub.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildViewBlock(int i, String block, MarkdownStyleSheet style) {
    final showEditButton =
        _hoveredIndex == i && widget.onEditSave != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = i),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          final next = _selectedIndex == i ? null : i;
          setState(() => _selectedIndex = next);
          widget.onBlockSelected?.call(next != null ? block : null);
        },
        onDoubleTap:
            widget.onEditSave == null ? null : () => _startEditing(i, block),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: double.infinity,
              decoration: BoxDecoration(
                color: _selectedIndex == i
                    ? widget.theme.primaryColor.withValues(alpha: 0.07)
                    : _hoveredIndex == i
                        ? widget.theme.primaryColor.withValues(alpha: 0.03)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedIndex == i
                      ? widget.theme.primaryColor.withValues(alpha: 0.2)
                      : _hoveredIndex == i
                          ? widget.theme.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 14,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _selectedIndex == i
                              ? widget.theme.primaryColor.withValues(alpha: 0.25)
                              : widget.theme.primaryColor.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 32, 8),
                        child: MarkdownBody(
                          data: block,
                          selectable: true,
                          styleSheet: style,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showEditButton)
              Positioned(
                top: 4,
                right: 4,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _startEditing(i, block),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: widget.theme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: widget.theme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
