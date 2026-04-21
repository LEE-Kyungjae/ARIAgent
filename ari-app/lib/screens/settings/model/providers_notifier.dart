import 'package:flutter/foundation.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../../../providers/config_provider.dart';
import 'models/provider_item.dart';
import 'models/provider_meta.dart';

/// ModelSettings 화면 한정 상태.
/// providers 리스트, 저장 상태('', 'saving', 'saved', 'error', 'dirty'),
/// 그리고 모든 저장 로직을 단일 진입점으로 통제한다.
/// 저장은 반드시 이 클래스의 [persist]를 통해서만 일어난다.
class ProvidersNotifier extends ChangeNotifier {
  ProvidersNotifier(this._cfg);

  final ConfigProvider _cfg;

  final List<ProviderItem> _providers = [];
  String _saveStatus = '';

  List<ProviderItem> get providers => _providers;
  String get saveStatus => _saveStatus;

  void attach() {
    AriAgent.connectionNotifier.addListener(_onConnectionChanged);
    if (AriAgent.isConnected) loadFromServer();
  }

  @override
  void dispose() {
    AriAgent.connectionNotifier.removeListener(_onConnectionChanged);
    for (var p in _providers) {
      p.dispose();
    }
    super.dispose();
  }

  void _onConnectionChanged() {
    if (AriAgent.isConnected) loadFromServer();
  }

  // ─── 로드 ────────────────────────────────────────────────

  Future<void> loadFromServer() async {
    final data = await _cfg.getServerHealth();
    if (data == null) return;
    if (_saveStatus == 'saving') return;

    final old = List<ProviderItem>.from(_providers);
    _providers.clear();

    if (data['providers'] != null && (data['providers'] as List).isNotEmpty) {
      final seenIds = <String>{};
      for (final p in (data['providers'] as List)) {
        final id = p['provider'] as String? ?? 'openai-codex';
        final meta = metaFor(id);
        final authType =
            (p['authType'] as String?) ?? (meta.isOAuth ? 'oauth' : 'apikey');
        String? accountId = p['accountId'] as String?;
        if (accountId == null || seenIds.contains(accountId)) {
          accountId = null;
        } else {
          seenIds.add(accountId);
        }
        _providers.add(ProviderItem(
          provider: id,
          model: p['model'] ?? meta.models.firstOrNull?.id ?? '',
          hasApiKey: p['hasApiKey'] == true,
          authType: authType,
          accountId: accountId,
        ));
      }
    } else {
      final p = (data['provider'] ?? 'openai-codex') as String;
      final m = (data['model'] ?? 'gpt-5.3-codex') as String;
      final meta = metaFor(p.isNotEmpty ? p : 'openai-codex');
      _providers.add(ProviderItem(
        provider: p.isNotEmpty ? p : 'openai-codex',
        model: m.isNotEmpty ? m : 'gpt-5.3-codex',
        hasApiKey: data['hasApiKey'] == true,
        authType: meta.isOAuth ? 'oauth' : 'apikey',
      ));
    }

    if (_saveStatus != 'dirty') _saveStatus = 'saved';
    notifyListeners();

    for (var p in old) {
      p.dispose();
    }
  }

  // ─── 저장 (단일 진입점) ──────────────────────────────────

  /// 서버 저장. 불완전한(키 비었거나 미로그인) 아이템은 자동 제외.
  /// 저장 후 평문으로 입력된 apiKey는 마스킹 처리하여 hasApiKey=true로 갱신.
  Future<void> persist() async {
    _saveStatus = 'saving';
    notifyListeners();

    final savable = _providers.where((p) => p.isSavable).toList();
    final success = await _cfg.saveProviders(
      savable.map((p) => p.toJson()).toList(),
    );

    if (success) {
      // 새로 입력된 평문 apiKey는 저장 직후 마스킹 + hasApiKey=true.
      for (final p in savable) {
        if (p.authType != 'oauth') {
          final text = p.apiKeyController.text;
          if (text.isNotEmpty && !text.contains('••')) {
            p.hasApiKey = true;
            p.apiKeyController.text = '••••••••••••••••';
          }
        }
      }
    }

    _saveStatus = success ? 'saved' : 'error';
    notifyListeners();
  }

  void markDirty() {
    if (_saveStatus == 'saving' || _saveStatus == 'dirty') return;
    _saveStatus = 'dirty';
    notifyListeners();
  }

  // ─── 카드에서 직접 호출하는 상태 변경 ────────────────────

  /// OAuth 로그인 완료 — item 상태 갱신 후 저장.
  Future<void> recordOAuthLogin(ProviderItem item) async {
    item.oauthLoggedIn = true;
    await persist();
  }

  /// OAuth 로그아웃 — item 상태 갱신 후 저장 (필터로 자동 제외됨).
  Future<void> recordOAuthLogout(ProviderItem item) async {
    item.oauthLoggedIn = false;
    await persist();
  }

  // ─── 목록 조작 ────────────────────────────────────────────

  void addProvider() {
    _providers.add(ProviderItem(
      provider: 'openai-codex',
      model: metaFor('openai-codex').models.firstOrNull?.id ?? '',
      hasApiKey: false,
      authType: 'oauth',
    ));
    // 리스트 변화 + dirty 상태를 단일 notifyListeners로 처리.
    if (_saveStatus != 'saving' && _saveStatus != 'dirty') {
      _saveStatus = 'dirty';
    }
    notifyListeners();
  }

  void removeProvider(int index) {
    _providers[index].dispose();
    _providers.removeAt(index);
    notifyListeners();
    persist();
  }

  void moveUp(int index) {
    if (index <= 0) return;
    _providers.insert(index - 1, _providers.removeAt(index));
    notifyListeners();
    persist();
  }

  void moveDown(int index) {
    if (index >= _providers.length - 1) return;
    _providers.insert(index + 1, _providers.removeAt(index));
    notifyListeners();
    persist();
  }
}
