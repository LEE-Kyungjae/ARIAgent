import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';

import '../../providers/server_provider.dart';
import '../../providers/config_provider.dart';
import '../../l10n/app_localizations.dart';
import '../settings/model/providers_notifier.dart';

import 'views/chat_header.dart';
import 'views/chat_suggestions.dart';
import 'views/server_stopped_view.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input.dart';

const _chatPanelBackgroundColor = Color(0xFF12122A);

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  String? _lastAgentId;
  bool _lastConnected = false;

  @override
  void initState() {
    super.initState();
    AriAgent.connectionNotifier.addListener(_onConnectionChanged);
  }

  @override
  void dispose() {
    AriAgent.connectionNotifier.removeListener(_onConnectionChanged);
    super.dispose();
  }

  void _onConnectionChanged() {
    if (AriAgent.isConnected) {
      if (_lastAgentId != null) {
        context.read<AriChatProvider>().loadServerHistory(_lastAgentId!, appId: 'ari');
      }
      context.read<ConfigProvider>().getServerHealth();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<AriChatProvider>();
    final server = context.watch<ServerProvider>();
    final providers = context.watch<ProvidersNotifier>();
    final avatar = context.watch<AgentProvider>();

    final isServerRunning = server.isRunning;
    final isConnected = AriAgent.isConnected;
    final avatarId = avatar.currentAvatarId;

    // 아바타가 변경되었거나, 서버가 방금 연결된 경우 히스토리 다시 불러오기
    if (avatarId != _lastAgentId || (isConnected && !_lastConnected)) {
      _lastAgentId = avatarId;
      _lastConnected = isConnected;
      chatProvider.setFilterAgentId(avatarId);
      if (isConnected) {
        Future.microtask(() => chatProvider.loadServerHistory(avatarId, appId: 'ari'));
      }
    }

    final Widget? overlay = isServerRunning ? null : const ServerStoppedView();

    return AriChatPanel(
      appId: 'ari',
      messages: chatProvider.messages,
      onSend: (text) => chatProvider.sendAgentMessage(
        text,
        agentId: avatar.currentAvatarId,
        persona: avatar.persona.trim(),
        avatarName: avatar.name,
      ),
      onCancel: () =>
          chatProvider.cancelAgentMessage(agentId: avatar.currentAvatarId),
      isLoading: chatProvider.isLoading,
      followUpMessage: chatProvider.latestFollowUpMessage,
      followUpCount: chatProvider.queuedFollowUpCount,
      hintText: S.of(context).chatHint,
      followUpSummaryBuilder: (count) => count > 1
          ? S.of(context).chatFollowUpPendingCount(count)
          : S.of(context).chatFollowUpPending,
      reverseMessages: true,
      headerBuilder: (_) => ChatHeader(isLoading: chatProvider.isLoading),
      overlayWidget: overlay,
      emptyStateWidget: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Center(
              child: Text(
                S.of(context).chatEmptyPrompt,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          ChatSuggestions(
            isSetupMode: providers.isSetupMode,
            onSuggestionTap: (text) => chatProvider.sendAgentMessage(
              text,
              agentId: avatar.currentAvatarId,
              persona: avatar.persona.trim(),
              avatarName: avatar.name,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      messageBubbleBuilder: (msg) => ChatBubble(
        message: msg.text,
        isUser: msg.isUser,
        isError: msg.isError,
        isSystem: msg.isSystem,
        isNotice: msg.isNotice,
      ),
      inputAreaBuilder: (onSend, onCancel, isLoading) {
        if (!isServerRunning) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
          child: ChatInput(
            onSubmit: onSend,
            onCancel: onCancel,
            isLoading: isLoading,
          ),
        );
      },
      followUpBannerTopOffset: -68,
      theme: const AriChatTheme(
        primaryColor: Color(0xFF6C63FF),
        surfaceColor: _chatPanelBackgroundColor,
        backgroundColor: _chatPanelBackgroundColor,
        textMain: Colors.white,
        textSub: Color(0xFF9E9EB8),
        borderColor: Colors.transparent,
        borderWidth: 0,
        hintColor: Color(0x66FFFFFF),
      ),
    );
  }
}
