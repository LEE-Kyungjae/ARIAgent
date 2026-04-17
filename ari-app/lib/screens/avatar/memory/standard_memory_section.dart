import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../widgets/tab_section_header.dart';
import '../../../l10n/app_localizations.dart';

class StandardMemorySection extends StatefulWidget {
  final VoidCallback onRefresh;
  
  const StandardMemorySection({
    super.key,
    required this.onRefresh,
  });

  @override
  State<StandardMemorySection> createState() => _StandardMemorySectionState();
}

class _StandardMemorySectionState extends State<StandardMemorySection> {
  final TextEditingController _coreMemoryController = TextEditingController();
  String _dailyLogs = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  String? _lastAvatarId;

  @override
  void initState() {
    super.initState();
    _fetchMemory();
  }

  @override
  void dispose() {
    _coreMemoryController.dispose();
    super.dispose();
  }

  Future<void> _fetchMemory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final memory = await context.read<AgentProvider>().getMemory();
      if (mounted) {
        setState(() {
          _coreMemoryController.text = memory['core'] ?? '';
          _dailyLogs = memory['daily'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).errorLoadMemoryFailedWith(e.toString()))),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveCoreMemory() async {
    setState(() => _isSaving = true);
    try {
      await context.read<AgentProvider>().updateMemory(
            _coreMemoryController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).memoryLongTermUpdated)),
        );
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).errorSaveFailedWith(e.toString()))),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<AgentProvider>();

    // 아바타가 바뀌었을 때 다시 불러오기
    if (_lastAvatarId != avatar.currentAvatarId) {
      _lastAvatarId = avatar.currentAvatarId;
      _isEditing = false;
      _fetchMemory();
    }

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabSectionHeader(
          icon: Icons.psychology_rounded,
          title: S.of(context).memoryCoreTitle,
          description: S.of(context).memoryCoreDesc,
          trailing: _buildCoreMemoryAction(),
        ),
        _buildCoreMemoryCard(),
        const SizedBox(height: 32),
        TabSectionHeader(
          icon: Icons.history_rounded,
          title: S.of(context).memoryDailyTitle,
          description: S.of(context).memoryDailyDesc,
        ),
        _buildDailyLogsCard(),
      ],
    );
  }


  Widget _buildCoreMemoryAction() {
    if (_isEditing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => setState(() {
              _isEditing = false;
              _fetchMemory();
            }),
            child: Text(S.of(context).cancel, style: const TextStyle(color: Colors.white54)),
          ),
          const SizedBox(width: 8),
          _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF6C63FF)),
                )
              : ElevatedButton(
                  onPressed: _saveCoreMemory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(S.of(context).save),
                ),
        ],
      );
    }
    return IconButton(
      onPressed: () => setState(() => _isEditing = true),
      icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF6C63FF)),
      tooltip: S.of(context).edit,
    );
  }

  Widget _buildCoreMemoryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isEditing
              ? const Color(0xFF6C63FF).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.05),
          width: _isEditing ? 1.5 : 1,
        ),
      ),
      child: _isEditing
          ? TextField(
              controller: _coreMemoryController,
              maxLines: null,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.6,
                fontFamily: 'Courier',
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: S.of(context).memoryLongTermHint,
                hintStyle: const TextStyle(color: Colors.white24),
              ),
              cursorColor: const Color(0xFF6C63FF),
            )
          : _coreMemoryController.text.isEmpty
              ? Text(
                  S.of(context).memoryNoLongTerm,
                  style: const TextStyle(color: Colors.white24, fontSize: 14),
                )
              : MarkdownBody(
                  data: _coreMemoryController.text,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.6,
                    ),
                    code: TextStyle(
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      color: const Color(0xFF4ADE80),
                      fontFamily: 'Courier',
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
    );
  }

  Widget _buildDailyLogsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: _dailyLogs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(S.of(context).memoryNoDailyLog,
                    style: const TextStyle(color: Colors.white24, fontSize: 13)),
              ),
            )
          : MarkdownBody(
              data: _dailyLogs,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.5,
                ),
                code: TextStyle(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  color: const Color(0xFF4ADE80),
                  fontFamily: 'Courier',
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
    );
  }
}
