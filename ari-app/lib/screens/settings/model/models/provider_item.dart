import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 카드 단위 상태. ChangeNotifier로 — 각 카드는 자기 인스턴스를
/// ChangeNotifierProvider.value로 받아 자체 구독한다.
/// 모든 setter는 값이 실제로 바뀔 때만 notifyListeners를 호출.
class ProviderItem extends ChangeNotifier {
  String _provider;
  String _model;
  bool _hasApiKey;
  bool _apiKeyObscured;
  String _authType; // 'apikey' | 'oauth'
  bool _oauthLoggedIn;
  String _accountId; // OAuth 다중 계정 구분자. 서버/로컬 어디서든 고유.
  final TextEditingController apiKeyController;

  bool _suppressNotify = false;

  /// 여러 setter를 한 번에 호출할 때 알림을 1회로 묶는다.
  /// 블록 내부의 setter는 알림이 억제되고, 블록 종료 후 단일 notifyListeners 발생.
  void update(VoidCallback block) {
    _suppressNotify = true;
    try {
      block();
    } finally {
      _suppressNotify = false;
    }
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_suppressNotify) return;
    super.notifyListeners();
  }

  ProviderItem({
    required String provider,
    required String model,
    required bool hasApiKey,
    String authType = 'apikey',
    bool oauthLoggedIn = false,
    String? accountId,
  })  : _provider = provider,
        _model = model,
        _hasApiKey = hasApiKey,
        _apiKeyObscured = true,
        _authType = authType,
        _oauthLoggedIn = oauthLoggedIn,
        _accountId = accountId ?? _uuid.v4(),
        apiKeyController = TextEditingController(
          text: hasApiKey ? '••••••••••••••••' : '',
        );

  String get provider => _provider;
  set provider(String v) {
    if (v == _provider) return;
    _provider = v;
    notifyListeners();
  }

  String get model => _model;
  set model(String v) {
    if (v == _model) return;
    _model = v;
    notifyListeners();
  }

  bool get hasApiKey => _hasApiKey;
  set hasApiKey(bool v) {
    if (v == _hasApiKey) return;
    _hasApiKey = v;
    notifyListeners();
  }

  bool get apiKeyObscured => _apiKeyObscured;
  set apiKeyObscured(bool v) {
    if (v == _apiKeyObscured) return;
    _apiKeyObscured = v;
    notifyListeners();
  }

  String get authType => _authType;
  set authType(String v) {
    if (v == _authType) return;
    _authType = v;
    notifyListeners();
  }

  bool get oauthLoggedIn => _oauthLoggedIn;
  set oauthLoggedIn(bool v) {
    if (v == _oauthLoggedIn) return;
    _oauthLoggedIn = v;
    notifyListeners();
  }

  String get accountId => _accountId;
  set accountId(String v) {
    if (v == _accountId) return;
    _accountId = v;
    notifyListeners();
  }

  /// 카드가 "저장 완료" 상태인지 여부.
  /// OAuth는 로그인됨, API key는 키가 저장됨일 때 true.
  /// 우선순위 이동 버튼은 이 카드들끼리만 노출/동작한다.
  bool get isSaved => _authType == 'oauth' ? _oauthLoggedIn : _hasApiKey;

  /// 서버 저장 대상인지 여부. 불완전한(키 비었거나 미로그인) 아이템은 저장 시 자동 제외.
  bool get isSavable {
    if (_authType == 'oauth') return _oauthLoggedIn;
    if (_hasApiKey) return true;
    final text = apiKeyController.text.trim();
    return text.isNotEmpty && !text.contains('••');
  }

  @override
  void dispose() {
    apiKeyController.dispose();
    super.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': _provider,
      'model': _model,
      'authType': _authType,
      'accountId': _accountId,
      if (_authType != 'oauth')
        'apiKey': apiKeyController.text.contains('••')
            ? null
            : apiKeyController.text.trim(),
    };
  }
}
