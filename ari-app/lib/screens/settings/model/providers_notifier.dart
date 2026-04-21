import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'models/provider_item.dart';
import 'models/provider_meta.dart';

/// 모델 프로바이더 + OAuth + isSetupMode 통합 상태.
/// 앱 단위 싱글턴 — main.dart에서 한 번 등록, 서버 연결 시점부터 자동 동기화.
/// 모든 저장/OAuth 호출은 이 클래스가 단일 진입점.
class ProvidersNotifier extends ChangeNotifier {
  static final ProvidersNotifier _instance = ProvidersNotifier._internal();
  factory ProvidersNotifier() => _instance;
  ProvidersNotifier._internal();

  final List<ProviderItem> _providers = [];
  String _saveStatus = '';
  bool _isSetupMode = false;

  List<ProviderItem> get providers => _providers;
  String get saveStatus => _saveStatus;
  bool get isSetupMode => _isSetupMode;

  /// main.dart에서 AriAgent.init 이후 1회 호출.
  void init() {
    AriAgent.connectionNotifier.addListener(_onConnectionChanged);
    if (AriAgent.isConnected) loadFromServer();
  }

  void _onConnectionChanged() {
    if (AriAgent.isConnected) loadFromServer();
  }

  // ─── 로드 ────────────────────────────────────────────────

  Future<void> loadFromServer() async {
    final data = await _fetchHealth();
    if (data == null) return;
    if (_saveStatus == 'saving') return;

    if (data.containsKey('isSetupMode')) {
      _isSetupMode = data['isSetupMode'] == true;
    }

    final old = List<ProviderItem>.from(_providers);
    _providers.clear();

    bool autoCorrected = false;
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
        final savedModel = p['model'] as String?;
        final validatedModel = _validateModel(savedModel, meta);
        if (savedModel != null && savedModel != validatedModel) {
          autoCorrected = true;
        }
        _providers.add(ProviderItem(
          provider: id,
          model: validatedModel,
          hasApiKey: p['hasApiKey'] == true,
          authType: authType,
          accountId: accountId,
        ));
      }
    } else {
      final p = (data['provider'] ?? 'openai-codex') as String;
      final providerId = p.isNotEmpty ? p : 'openai-codex';
      final meta = metaFor(providerId);
      final m = data['model'] as String?;
      _providers.add(ProviderItem(
        provider: providerId,
        model: _validateModel(m, meta),
        hasApiKey: data['hasApiKey'] == true,
        authType: meta.isOAuth ? 'oauth' : 'apikey',
      ));
    }

    // 저장된 모델이 meta에 없어 자동 교정한 경우, 서버에도 즉시 반영.
    if (autoCorrected) {
      _saveStatus = 'saved';
      notifyListeners();
      unawaited(persist());
      for (var p in old) {
        p.dispose();
      }
      return;
    }

    if (_saveStatus != 'dirty') _saveStatus = 'saved';
    notifyListeners();

    for (var p in old) {
      p.dispose();
    }
  }

  /// 저장된 모델이 meta에 있으면 그대로, 없으면 meta 첫 모델로 교정.
  /// meta가 비어있으면 saved 그대로 둔다 (커스텀 프로바이더 가능성).
  String _validateModel(String? saved, ProviderMeta meta) {
    if (meta.models.isEmpty) return saved ?? '';
    if (saved != null && meta.models.any((m) => m.id == saved)) return saved;
    return meta.models.first.id;
  }

  Future<Map<String, dynamic>?> _fetchHealth() async {
    try {
      return await AriAgent.call('/HEALTH');
    } catch (e) {
      debugPrint('[ProvidersNotifier] /HEALTH failed: $e');
      return null;
    }
  }

  // ─── 저장 (단일 진입점) ──────────────────────────────────

  /// 서버 저장. 불완전한(키 비었거나 미로그인) 아이템은 자동 제외.
  /// 저장 후 평문으로 입력된 apiKey는 마스킹 처리하여 hasApiKey=true로 갱신.
  /// 저장 직후 서버 health를 재조회하여 isSetupMode를 동기화한다.
  Future<void> persist() async {
    _saveStatus = 'saving';
    notifyListeners();

    final savable = _providers.where((p) => p.isSavable).toList();

    bool success = false;
    try {
      await AriAgent.call('/SETTINGS', {
        'providers': savable.map((p) => p.toJson()).toList(),
      });
      success = true;
    } catch (e) {
      debugPrint('[ProvidersNotifier] saveProviders failed: $e');
    }

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
      final health = await _fetchHealth();
      if (health != null && health.containsKey('isSetupMode')) {
        _isSetupMode = health['isSetupMode'] == true;
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

  // ─── OAuth (accountId 단위 다중 계정) ────────────────────

  Future<bool> startOAuthLogin(String accountId, String provider) async {
    try {
      await AriAgent.call('/OAUTH_LOGIN', {
        'accountId': accountId,
        'provider': provider,
      });
      return true;
    } catch (e) {
      debugPrint('[ProvidersNotifier] startOAuthLogin failed: $e');
      return false;
    }
  }

  Future<bool> sendOAuthPrompt(String accountId, String value) async {
    try {
      await AriAgent.call('/OAUTH_PROMPT', {
        'accountId': accountId,
        'value': value,
      });
      return true;
    } catch (e) {
      debugPrint('[ProvidersNotifier] sendOAuthPrompt failed: $e');
      return false;
    }
  }

  Future<bool> cancelOAuthLogin(String accountId) async {
    try {
      await AriAgent.call('/OAUTH_CANCEL', {'accountId': accountId});
      return true;
    } catch (e) {
      debugPrint('[ProvidersNotifier] cancelOAuthLogin failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getOAuthStatus(String accountId) async {
    try {
      return await AriAgent.call('/OAUTH_STATUS', {'accountId': accountId});
    } catch (e) {
      debugPrint('[ProvidersNotifier] getOAuthStatus failed: $e');
      return null;
    }
  }

  Future<bool> logoutOAuth(String accountId) async {
    try {
      await AriAgent.call('/OAUTH_LOGOUT', {'accountId': accountId});
      return true;
    } catch (e) {
      debugPrint('[ProvidersNotifier] logoutOAuth failed: $e');
      return false;
    }
  }

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
