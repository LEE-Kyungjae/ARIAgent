import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../avatar/widgets/avatar_widget.dart';
import '../../../providers/server_provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../../../providers/config_provider.dart';
import '../../../l10n/app_localizations.dart';

class ChatHeader extends StatefulWidget {
  final bool isLoading;

  const ChatHeader({super.key, required this.isLoading});

  @override
  State<ChatHeader> createState() => _ChatHeaderState();
}

class _ChatHeaderState extends State<ChatHeader> {
  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerProvider>();
    final avatar = context.watch<AgentProvider>();
    final config = context.watch<ConfigProvider>();

    final isConnected = server.isRunning;
    final isStarting = server.status == ServerStatus.starting;
    final name = avatar.name;
    final isChatCollapsed = config.isChatCollapsed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: const BoxDecoration(
        color: Color(0xFF12122A),
      ),
      padding: EdgeInsets.only(
        top: isChatCollapsed ? 8 : 12,
        bottom: isChatCollapsed ? 8 : 12,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isChatCollapsed)
            // 접혔을 때: 한 줄 레이아웃 [아바타 | 상태 | 토글 | 휴지통]
            Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: AvatarWidget(
                    isConnected: isConnected,
                    isThinking: widget.isLoading,
                    avatarSize: 'small',
                    showStatusIndicator: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatus(
                    isConnected,
                    isStarting,
                    name,
                    server,
                    isCompact: true,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: () => config.updateIsChatCollapsed(false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: S.of(context).chatTooltipExpand,
                ),
                _buildTrashButton(context),
              ],
            )
          else
            // 펼쳐졌을 때: 버튼들을 최상단 우측으로 이동 (아바타와 독립적인 레이아웃)
            Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_up,
                          color: Colors.white54,
                          size: 20,
                        ),
                        onPressed: () => config.updateIsChatCollapsed(true),
                        tooltip: S.of(context).chatTooltipCollapse,
                      ),
                      _buildTrashButton(context),
                    ],
                  ),
                ),
                // 아바타 (중앙)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: AvatarWidget(
                    isConnected: isConnected,
                    isThinking: widget.isLoading,
                    showStatusIndicator: false,
                  ),
                ),
              ],
            ),
          if (!isChatCollapsed)
            // 펼쳐졌을 때의 상태 표시
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildStatus(isConnected, isStarting, name, server),
            ),
        ],
      ),
    );
  }

  Widget _buildTrashButton(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 20),
      tooltip: S.of(context).chatTooltipClearHistory,
      onPressed: () async {
        final l10n = S.of(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: Text(l10n.chatClearTitle, style: const TextStyle(fontSize: 16)),
            content: Text(
              l10n.chatClearMessage,
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  l10n.cancel,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  l10n.chatClearButton,
                  style: const TextStyle(color: Color(0xFFFF6B6B)),
                ),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          final avatarId = context.read<AgentProvider>().currentAvatarId;
          await context.read<AriChatProvider>().clearServerHistory(
            avatarId,
            appId: 'ari',
          );
        }
      },
    );
  }

  Widget _buildStatus(
    bool isConnected,
    bool isStarting,
    String name,
    ServerProvider server, {
    bool isCompact = false,
  }) {
    return Row(
      mainAxisAlignment: isCompact
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            isConnected
                ? '$name is Online'
                : (isStarting ? 'Starting...' : '$name Offline'),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isConnected
                  ? const Color(0xFF4ADE80)
                  : (isStarting
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFFF6B6B)),
              fontSize: isCompact ? 12 : 11,
              fontWeight: FontWeight.w600,
              letterSpacing: isCompact ? 0.5 : 1.2,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isConnected
                ? const Color(0xFF4ADE80)
                : (isStarting
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFFFF6B6B)),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:
                    (isConnected
                            ? const Color(0xFF4ADE80)
                            : (isStarting
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFFFF6B6B)))
                        .withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        if (!isConnected && !isStarting) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await server.start();
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Color(0xFF4ADE80),
                size: 14,
              ),
            ),
          ),
        ],
        if (isStarting) ...[
          const SizedBox(width: 8),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFFBBF24),
            ),
          ),
        ],
      ],
    );
  }
}
