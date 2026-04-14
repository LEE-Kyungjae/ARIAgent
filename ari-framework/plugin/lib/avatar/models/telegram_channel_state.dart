class TelegramChannelState {
  final bool enabled;
  final String botTokenMasked;
  final String? agentId;
  final bool isPolling;

  const TelegramChannelState({
    this.enabled = false,
    this.botTokenMasked = '',
    this.agentId,
    this.isPolling = false,
  });

  bool get hasToken => botTokenMasked.isNotEmpty;

  TelegramChannelState copyWith({
    bool? enabled,
    String? botTokenMasked,
    String? agentId,
    bool? isPolling,
  }) {
    return TelegramChannelState(
      enabled: enabled ?? this.enabled,
      botTokenMasked: botTokenMasked ?? this.botTokenMasked,
      agentId: agentId ?? this.agentId,
      isPolling: isPolling ?? this.isPolling,
    );
  }
}
