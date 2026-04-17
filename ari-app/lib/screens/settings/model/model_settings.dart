import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/config_provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'provider_meta.dart';
import 'provider_card.dart';
import 'widgets/add_provider_button.dart';
import 'widgets/help_section.dart';
import 'widgets/server_connection_notice.dart';
import '../../../l10n/app_localizations.dart';

class ModelSettings extends StatefulWidget {
  const ModelSettings({super.key});

  @override
  State<ModelSettings> createState() => _ModelSettingsState();
}

class _ModelSettingsState extends State<ModelSettings> {
  List<ProviderItem> _providers = [];
  bool _showHelp = false;
  Timer? _saveDebounce;
  Timer? _statusClearTimer;
  String _saveStatus = ''; // '', 'saving', 'saved', 'error'

  @override
  void initState() {
    super.initState();
    // WS가 연결될 때만 설정 로드 (ServerProvider 로그 notifyListeners 폭발 방지)
    AriAgent.connectionNotifier.addListener(_onConnectionChanged);
    if (AriAgent.isConnected) _loadCurrentSettings();
  }

  @override
  void dispose() {
    AriAgent.connectionNotifier.removeListener(_onConnectionChanged);
    _saveDebounce?.cancel();
    _statusClearTimer?.cancel();
    for (var p in _providers) {
      p.dispose();
    }
    super.dispose();
  }

  void _onConnectionChanged() {
    if (AriAgent.isConnected) _loadCurrentSettings();
  }

  // ─── 설정 ────────────────────────────────────────────

  Future<void> _loadCurrentSettings() async {
    final cfg = Provider.of<ConfigProvider>(context, listen: false);
    final data = await cfg.getServerHealth();

    if (data != null && mounted) {
      // 자동저장 대기 중이면 서버 상태로 덮어쓰지 않음 (race 방지)
      if (_saveDebounce?.isActive ?? false) return;
      if (_saveStatus == 'saving') return;

      final old = _providers;
      setState(() {
        if (data['providers'] != null &&
            (data['providers'] as List).isNotEmpty) {
          final seenIds = <String>{};
          _providers = (data['providers'] as List).map((p) {
            final id = p['provider'] as String? ?? 'openai-codex';
            final meta = metaFor(id);
            final authType =
                (p['authType'] as String?) ??
                (meta.isOAuth ? 'oauth' : 'apikey');
            // 서버가 주는 accountId 유지. 누락/중복이면 새로 발급 (방어 로직).
            String? accountId = p['accountId'] as String?;
            if (accountId == null || seenIds.contains(accountId)) {
              accountId = null; // ProviderItem 생성자가 uuid 발급
            } else {
              seenIds.add(accountId);
            }
            return ProviderItem(
              provider: id,
              model: p['model'] ?? metaFor(id).models.firstOrNull ?? '',
              hasApiKey: p['hasApiKey'] == true,
              authType: authType,
              accountId: accountId,
            );
          }).toList();
        } else {
          final p = (data['provider'] ?? 'openai-codex') as String;
          final m = (data['model'] ?? 'gpt-5.3-codex') as String;
          final meta = metaFor(p.isNotEmpty ? p : 'openai-codex');
          _providers = [
            ProviderItem(
              provider: p.isNotEmpty ? p : 'openai-codex',
              model: m.isNotEmpty ? m : 'gpt-5.3-codex',
              hasApiKey: data['hasApiKey'] == true,
              authType: meta.isOAuth ? 'oauth' : 'apikey',
            ),
          ];
        }
      });
      // 이전 controller 메모리 누수 방지
      for (var p in old) {
        p.dispose();
      }
    }
  }

  // ─── 자동 저장 ────────────────────────────────────────────

  void _scheduleSave({
    Duration delay = const Duration(milliseconds: 500),
  }) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(delay, _persistChanges);
  }

  Future<void> _persistChanges() async {
    if (!mounted) return;
    setState(() => _saveStatus = 'saving');
    final cfg = Provider.of<ConfigProvider>(context, listen: false);
    final success = await cfg.saveProviders(
      _providers.map((p) => p.toJson()).toList(),
    );
    if (!mounted) return;
    setState(() => _saveStatus = success ? 'saved' : 'error');
    _statusClearTimer?.cancel();
    _statusClearTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _saveStatus != 'saving') {
        setState(() => _saveStatus = '');
      }
    });
  }

  // ─── 목록 조작 ────────────────────────────────────────────

  void _addProvider() {
    setState(() {
      _providers.add(
        ProviderItem(
          provider: 'openai-codex',
          model: metaFor('openai-codex').models.firstOrNull?.id ?? '',
          hasApiKey: false,
          authType: 'oauth',
        ),
      );
    });
    _scheduleSave(delay: const Duration(milliseconds: 100));
  }

  void _removeProvider(int index) {
    setState(() {
      _providers[index].dispose();
      _providers.removeAt(index);
    });
    _scheduleSave(delay: const Duration(milliseconds: 100));
  }

  void _moveUp(int index) {
    if (index > 0) {
      setState(() => _providers.insert(index - 1, _providers.removeAt(index)));
      _scheduleSave(delay: const Duration(milliseconds: 100));
    }
  }

  void _moveDown(int index) {
    if (index < _providers.length - 1) {
      setState(() => _providers.insert(index + 1, _providers.removeAt(index)));
      _scheduleSave(delay: const Duration(milliseconds: 100));
    }
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_providers.isEmpty) {
      return const ServerConnectionNotice();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context).modelProvidersPriority,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAutoSaveIndicator(),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() => _showHelp = !_showHelp),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(
                        _showHelp ? Icons.help : Icons.help_outline,
                        size: 16,
                        color: _showHelp
                            ? const Color(0xFF6C63FF)
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_showHelp) ...[
            const SizedBox(height: 12),
            const HelpSection(),
          ],
          const SizedBox(height: 16),
          ...List.generate(
            _providers.length,
            (i) => ProviderCard(
              key: ValueKey('provider_${_providers[i].accountId}'),
              item: _providers[i],
              index: i,
              totalCount: _providers.length,
              onMoveUp: () => _moveUp(i),
              onMoveDown: () => _moveDown(i),
              onRemove: () => _removeProvider(i),
              onChanged: () {
                setState(() {});
                _scheduleSave();
              },
            ),
          ),
          const SizedBox(height: 12),
          AddProviderButton(onTap: _addProvider),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAutoSaveIndicator() {
    if (_saveStatus.isEmpty) return const SizedBox.shrink();
    Color color;
    String text;
    Widget leading;
    switch (_saveStatus) {
      case 'saving':
        color = Colors.white.withValues(alpha: 0.5);
        text = S.of(context).modelSaving;
        leading = SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: color,
          ),
        );
        break;
      case 'saved':
        color = const Color(0xFF4ADE80);
        text = S.of(context).modelSaved;
        leading = Icon(Icons.check_circle_outline, size: 12, color: color);
        break;
      case 'error':
        color = const Color(0xFFFF6B6B);
        text = S.of(context).modelSaveFailed;
        leading = Icon(Icons.error_outline, size: 12, color: color);
        break;
      default:
        return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}
