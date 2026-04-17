import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../../../l10n/app_localizations.dart';

class TokenManagementScreen extends StatefulWidget {
  final String agentId;
  const TokenManagementScreen({super.key, required this.agentId});

  @override
  State<TokenManagementScreen> createState() => _TokenManagementScreenState();
}

class _TokenManagementScreenState extends State<TokenManagementScreen> {
  static const Color _accentColor = Color(0xFF6C63FF);

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAndStore();
  }

  /// 서버에서 전체 집계를 가져와 AgentModel에 저장
  Future<void> _fetchAndStore() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await AriAgent.call('/USAGE.GET', {'agentId': widget.agentId});
      if (!mounted) return;
      context
          .read<AgentProvider>()
          .currentAgent
          .setTokenUsageFromSummary(data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _accentColor));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white38, size: 40),
            const SizedBox(height: 12),
            Text(S.of(context).errorLoadData,
                style:
                    TextStyle(color: Colors.white.withValues(alpha: 0.6))),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _fetchAndStore,
              child: Text(S.of(context).retry,
                  style: const TextStyle(color: _accentColor)),
            ),
          ],
        ),
      );
    }

    // AgentModel을 직접 구독 → /USAGE.UPDATED로 실시간 누적되면 자동 반영
    final agent = context.watch<AgentProvider>().currentAgent;
    return ListenableBuilder(
      listenable: agent,
      builder: (context, _) =>
          _buildContent(context, agent.tokenUsage),
    );
  }

  Widget _buildContent(BuildContext context, AgentTokenUsage usage) {
    return RefreshIndicator(
      color: _accentColor,
      backgroundColor: const Color(0xFF1A1A2E),
      onRefresh: _fetchAndStore,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(S.of(context).tokenTotalUsage),
            const SizedBox(height: 16),
            _buildUsageSummaryCard(usage),
            if (usage.byModel.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionHeader(S.of(context).tokenByModel),
              const SizedBox(height: 16),
              ..._buildModelCards(usage),
            ],
            if (usage.byDay.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionHeader(S.of(context).tokenDailyTrend),
              const SizedBox(height: 16),
              _buildUsageHistoryCard(usage),
            ],
            if (usage.isEmpty) ...[
              const SizedBox(height: 40),
              _buildEmptyState(),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _accentColor,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildUsageSummaryCard(AgentTokenUsage usage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.of(context).tokenTotal,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              GestureDetector(
                onTap: _fetchAndStore,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Text(S.of(context).tokenRefresh,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatNumber(usage.total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const Text('tokens',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildSummaryChip(
                  Icons.arrow_downward_rounded, 'Input',
                  _formatNumber(usage.input)),
              const SizedBox(width: 12),
              _buildSummaryChip(
                  Icons.arrow_upward_rounded, 'Output',
                  _formatNumber(usage.output)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 10)),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildModelCards(AgentTokenUsage usage) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF9D4EDD),
      const Color(0xFF00BFA5),
      const Color(0xFFFFB347),
      const Color(0xFFFF6B6B),
    ];

    return usage.byModel.entries.toList().asMap().entries.map((entry) {
      final color = colors[entry.key % colors.length];
      final modelName = entry.value.key;
      final m = entry.value.value;
      final inputRatio = m.total > 0 ? m.input / m.total : 0.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildModelUsageCard(
          modelName,
          inputTokens: m.input,
          outputTokens: m.output,
          total: m.total,
          inputRatio: inputRatio,
          color: color,
        ),
      );
    }).toList();
  }

  Widget _buildModelUsageCard(
    String modelName, {
    required int inputTokens,
    required int outputTokens,
    required int total,
    required double inputRatio,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(modelName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${_formatNumber(total)} tokens',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                    height: 6,
                    color: Colors.white.withValues(alpha: 0.08)),
                FractionallySizedBox(
                  widthFactor: inputRatio,
                  child: Container(height: 6, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTokenLabel('Input', inputTokens, color),
              const SizedBox(width: 16),
              _buildTokenLabel('Output', outputTokens,
                  Colors.white.withValues(alpha: 0.3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenLabel(String label, int count, Color color) {
    return Row(
      children: [
        Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label: ${_formatNumber(count)}',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildUsageHistoryCard(AgentTokenUsage usage) {
    final days = usage.byDay.length > 14
        ? usage.byDay.sublist(usage.byDay.length - 14)
        : usage.byDay;
    final maxTotal =
        days.map((d) => d.total).fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.asMap().entries.map((entry) {
                final isToday = entry.key == days.length - 1;
                final d = entry.value;
                final ratio =
                    maxTotal > 0 ? d.total / maxTotal : 0.0;
                return Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isToday && d.total > 0)
                          Text(
                            _formatCompact(d.total),
                            style: const TextStyle(
                                color: _accentColor,
                                fontSize: 8,
                                fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(height: 2),
                        Container(
                          height: (80 * ratio).clamp(4.0, 80.0),
                          decoration: BoxDecoration(
                            color: isToday
                                ? _accentColor
                                : _accentColor.withValues(alpha: 0.3),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: days.asMap().entries.map((entry) {
              final isToday = entry.key == days.length - 1;
              final label = entry.value.date.length >= 10
                  ? entry.value.date.substring(5)
                  : entry.value.date;
              return Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isToday ? _accentColor : Colors.white38,
                    fontSize: 9,
                    fontWeight: isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.token_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text(S.of(context).tokenNoUsage,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14)),
          const SizedBox(height: 8),
          Text(S.of(context).tokenNoUsageDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 12,
                  height: 1.6)),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _formatCompact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
