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
  Timer? _statusClearTimer;
  String _saveStatus = ''; // '', 'saving', 'saved', 'error', 'dirty'

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
      // 저장 진행 중이면 서버 상태로 덮어쓰지 않음 (race 방지)
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
              model: p['model'] ?? metaFor(id).models.firstOrNull?.id ?? '',
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

  // ─── 저장 ──────────────────────────────────────────────
  // 저장 트리거: OAuth 로그인 완료, OAuth 로그아웃, API 키 저장 버튼,
  //              프로바이더 순서 변경(이동), 프로바이더 삭제.
  // 그 외(추가/드롭다운 변경/텍스트 입력)는 메모리 상태만 변경한다.

  Future<void> _persistChanges() => _saveProvidersList(_providers);

  /// 특정 accountId의 카드를 서버 저장에서 제외하고 나머지만 저장.
  /// UI 상의 카드(_providers)는 그대로 유지된다 — 로그아웃에서 사용.
  Future<void> _persistChangesExcluding(String accountId) {
    return _saveProvidersList(
      _providers.where((p) => p.accountId != accountId).toList(),
    );
  }

  Future<void> _saveProvidersList(List<ProviderItem> list) async {
    if (!mounted) return;
    debugPrint('[ModelSettings] _saveProvidersList start, count=${list.length}');
    setState(() => _saveStatus = 'saving');
    final cfg = Provider.of<ConfigProvider>(context, listen: false);
    final success = await cfg.saveProviders(
      list.map((p) => p.toJson()).toList(),
    );
    debugPrint('[ModelSettings] saveProviders returned $success, mounted=$mounted');
    if (!mounted) return;
    setState(() => _saveStatus = success ? 'saved' : 'error');
    debugPrint('[ModelSettings] _saveStatus set to $_saveStatus');
    _statusClearTimer?.cancel();
    _statusClearTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_saveStatus == 'saved' || _saveStatus == 'error')) {
        setState(() => _saveStatus = '');
      }
    });
  }

  /// 변경사항이 있지만 아직 저장되지 않았음을 표시.
  /// 추가/드롭다운 변경/API 키 텍스트 입력 등에서 호출.
  void _markDirty() {
    if (_saveStatus == 'saving') return;
    if (_saveStatus == 'dirty') return;
    setState(() => _saveStatus = 'dirty');
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
    _markDirty();
  }

  void _removeProvider(int index) {
    setState(() {
      _providers[index].dispose();
      _providers.removeAt(index);
    });
    _persistChanges();
  }

  void _moveUp(int index) {
    if (index > 0) {
      setState(() => _providers.insert(index - 1, _providers.removeAt(index)));
      _persistChanges();
    }
  }

  void _moveDown(int index) {
    if (index < _providers.length - 1) {
      setState(() => _providers.insert(index + 1, _providers.removeAt(index)));
      _persistChanges();
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
            (i) {
              final item = _providers[i];
              return ProviderCard(
                key: ValueKey('provider_${item.accountId}'),
                item: item,
                index: i,
                totalCount: _providers.length,
                onMoveUp: () => _moveUp(i),
                onMoveDown: () => _moveDown(i),
                onRemove: () => _removeProvider(i),
                onSave: _persistChanges,
                onLogoutSave: () => _persistChangesExcluding(item.accountId),
                onMarkDirty: _markDirty,
              );
            },
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
      case 'dirty':
        color = const Color(0xFFFFB155);
        text = S.of(context).modelUnsaved;
        leading = Icon(Icons.edit_outlined, size: 12, color: color);
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
