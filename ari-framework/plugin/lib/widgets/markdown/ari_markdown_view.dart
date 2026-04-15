import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AriMarkdownView extends StatefulWidget {
  const AriMarkdownView({
    super.key,
    required this.content,
    this.padding = const EdgeInsets.fromLTRB(18, 24, 18, 18),
    this.borderRadius = 24,
    this.primaryColor = const Color(0xFF3182F6),
    this.textMainColor = const Color(0xFF191F28),
    this.textSubColor = const Color(0xFF4E5968),
    this.onBlockSelected,
  });

  final String content;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color primaryColor;
  final Color textMainColor;
  final Color textSubColor;
  /// 블록 선택/해제 시 호출. 선택 해제 시 null 전달.
  final void Function(String? selectedBlock)? onBlockSelected;

  @override
  State<AriMarkdownView> createState() => _AriMarkdownViewState();
}

class _AriMarkdownViewState extends State<AriMarkdownView> {
  int? _selectedIndex;
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final blocks = widget.content
        .split('\n\n')
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();

    final style = MarkdownStyleSheet(
      p: TextStyle(fontSize: 12, height: 1.6, color: widget.textMainColor),
      strong: TextStyle(fontWeight: FontWeight.w700, color: widget.textMainColor),
      h1: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: widget.textMainColor),
      h2: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: widget.textMainColor),
      h3: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.textMainColor),
      listBullet: TextStyle(fontSize: 12, color: widget.textMainColor),
      blockquote: TextStyle(color: widget.textSubColor, fontSize: 12, height: 1.6),
    );

    return Container(
      width: double.infinity,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: widget.primaryColor.withValues(alpha: 0.2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            MouseRegion(
              onEnter: (_) => setState(() => _hoveredIndex = i),
              onExit: (_) => setState(() => _hoveredIndex = null),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  final next = _selectedIndex == i ? null : i;
                  setState(() => _selectedIndex = next);
                  widget.onBlockSelected?.call(next != null ? blocks[next] : null);
                },
                child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _selectedIndex == i
                      ? widget.primaryColor.withValues(alpha: 0.07)
                      : _hoveredIndex == i
                          ? widget.primaryColor.withValues(alpha: 0.03)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedIndex == i
                        ? widget.primaryColor.withValues(alpha: 0.2)
                        : _hoveredIndex == i
                            ? widget.primaryColor.withValues(alpha: 0.1)
                            : Colors.transparent,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 왼쪽 토글 인디케이터
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 14,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _selectedIndex == i
                              ? widget.primaryColor.withValues(alpha: 0.25)
                              : widget.primaryColor.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    // 텍스트 영역 (selectable 유지)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: MarkdownBody(
                          data: blocks[i],
                          selectable: true,
                          styleSheet: style,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
            ),
          ],
        ],
      ),
    );
  }
}
