import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../providers/config_provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../provider_meta.dart';
import 'oauth_dialog.dart';
import '../../../../l10n/app_localizations.dart';

class OAuthSection extends StatefulWidget {
  final ProviderItem item;
  final VoidCallback? onSave;
  final VoidCallback? onLogoutSave;
  final VoidCallback? onLockStateChanged;

  const OAuthSection({
    super.key,
    required this.item,
    this.onSave,
    this.onLogoutSave,
    this.onLockStateChanged,
  });

  @override
  State<OAuthSection> createState() => _OAuthSectionState();
}

class _OAuthSectionState extends State<OAuthSection> {
  bool _isLoggedIn = false;
  bool _isLoggingIn = false;
  String _statusMsg = '';
  StreamSubscription<Map<String, dynamic>>? _eventSub;
  bool _isDialogOpen = false;
  OAuthDialogController? _dialogController;
  Timer? _pollTimer;

  String get _provider => widget.item.provider;
  String get _accountId => widget.item.accountId;

  @override
  void initState() {
    super.initState();
    _loadInitialStatus();
    _subscribeEvents();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _stopPolling();
    super.dispose();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) return;
      final cfg = Provider.of<ConfigProvider>(context, listen: false);
      final result = await cfg.getOAuthStatus(_accountId);
      if (mounted && result != null && result['loggedIn'] == true) {
        setState(() {
          _isLoggedIn = true;
          _statusMsg = S.of(context).oauthLoginComplete;
          widget.item.oauthLoggedIn = true;
        });
        _closeDialog();
        _stopPolling();
        widget.onSave?.call();
      }
    });
  }

  void _closeDialog() {
    if (_isDialogOpen && mounted) {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _isDialogOpen = false;
      // 컨트롤러 dispose는 다이얼로그 State.dispose에서 removeListener가 끝난 뒤
      // 안전하게 정리되도록 showOAuthDialog().then() 콜백에 위임한다.
    }
  }

  void _ensureDialogOpen() {
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    _dialogController = OAuthDialogController();
    showOAuthDialog(
      context,
      controller: _dialogController!,
      accountId: _accountId,
    ).then((submitted) {
      if (!mounted) return;
      _isDialogOpen = false;
      _dialogController?.dispose();
      _dialogController = null;
      // 사용자가 직접 닫음(취소/빈 입력) 또는 done/error로 외부에서 pop됨.
      // 아직 로그인 완료가 아니라면 취소로 간주 (cancel은 _isLoggingIn 가드로 중복 안전).
      if (!submitted && !_isLoggedIn) _cancelLogin();
    });
  }

  // ─── 초기 상태 로드 ───────────────────────────────────────

  Future<void> _loadInitialStatus() async {
    final cfg = Provider.of<ConfigProvider>(context, listen: false);
    final result = await cfg.getOAuthStatus(_accountId);
    if (mounted && result != null) {
      final loggedIn = result['loggedIn'] == true;
      setState(() => _isLoggedIn = loggedIn);
      if (widget.item.oauthLoggedIn != loggedIn) {
        widget.item.oauthLoggedIn = loggedIn;
        widget.onLockStateChanged?.call();
      }
    }
  }

  // ─── /OAUTH_EVENT 구독 ────────────────────────────────────

  void _subscribeEvents() {
    _eventSub = AriAgent.on('/OAUTH_EVENT', (data) {
      // accountId가 있는 이벤트는 accountId로 필터, 레거시는 provider로
      final eventAccountId = data['accountId'] as String?;
      final matches = eventAccountId != null
          ? eventAccountId == _accountId
          : data['provider'] == _provider;
      if (!matches || !mounted) return;
      final type = data['type'] as String?;
      if (type == null) return;

      // 진행 중인 로그인이 아닐 때 들어오는 이벤트는 stale로 간주하고 drop.
      // (서버에서도 loginId로 필터하지만 이중 안전장치)
      if (!_isLoggingIn && (type == 'auth_url' || type == 'prompt' || type == 'progress')) {
        return;
      }

      bool shouldSave = false;
      setState(() {
        switch (type) {
          case 'auth_url':
            _statusMsg = S.of(context).oauthBrowserAuth;
            final url = data['authUrl'] as String?;
            if (url != null) {
              // 브라우저 자동 실행 (비동기로 안전하게 실행)
              unawaited(
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                    .then((success) {
                      if (!success) {
                        debugPrint('❌ Failed to launch OAuth URL: $url');
                      }
                    })
                    .catchError((e) {
                      debugPrint('❌ Error launching OAuth URL: $e');
                    }),
              );

              _ensureDialogOpen();
              _dialogController?.setAuth(
                url: url,
                instructions: data['instructions'] as String?,
              );
              _startPolling();
            }
            break;
          case 'prompt':
            _statusMsg = S.of(context).oauthCodeRequired;
            final msg = data['promptMessage'] as String?;
            if (msg != null) {
              _ensureDialogOpen();
              _dialogController?.setPrompt(msg);
            }
            break;
          case 'progress':
            _statusMsg = data['message'] as String? ?? S.of(context).oauthInProgress;
            break;
          case 'done':
            _statusMsg = S.of(context).oauthLoginComplete;
            _isLoggedIn = true;
            _isLoggingIn = false;
            widget.item.oauthLoggedIn = true;
            _closeDialog();
            _stopPolling();
            shouldSave = true;
            break;
          case 'error':
            _isLoggingIn = false;
            _stopPolling();
            _closeDialog();
            _statusMsg = S.of(context).oauthError(data['message'] as String? ?? S.of(context).oauthErrorDefault);
            break;
        }
      });
      // 부모(ModelSettings)의 setState를 자식 setState 내부에서 호출하면
      // nested setState로 인해 indicator 갱신이 누락될 수 있어서 외부로 분리.
      if (shouldSave) widget.onSave?.call();
    });
  }

  // ─── 액션 ─────────────────────────────────────────────────

  Future<void> _login() async {
    setState(() {
      _isLoggingIn = true;
      _statusMsg = S.of(context).oauthStarting;
    });
    final cfg = Provider.of<ConfigProvider>(context, listen: false);
    try {
      await cfg.startOAuthLogin(_accountId, _provider);
    } catch (_) {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  /// 진행 중인 로그인을 취소한다.
  /// 클라이언트 상태를 즉시 초기화하고 서버에 취소 신호를 보낸다.
  Future<void> _cancelLogin() async {
    if (!_isLoggingIn) return;
    _stopPolling();
    if (mounted) {
      setState(() {
        _isLoggingIn = false;
        _statusMsg = '';
      });
    }
    final cfg = Provider.of<ConfigProvider>(context, listen: false);
    unawaited(cfg.cancelOAuthLogin(_accountId));
  }

  Future<void> _logout() async {
    final cfg = Provider.of<ConfigProvider>(context, listen: false);
    await cfg.logoutOAuth(_accountId);
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _isLoggingIn = false;
        _statusMsg = '';
        widget.item.oauthLoggedIn = false;
      });
      // 로그아웃 시 서버 저장 목록에서도 제외 (UI 카드는 그대로 유지).
      widget.onLogoutSave?.call();
    }
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상태 배지
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _isLoggedIn
                ? const Color(0xFF0D2B1A)
                : const Color(0xFF1E1A2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isLoggedIn
                  ? const Color(0xFF4ADE80).withValues(alpha: 0.4)
                  : const Color(0xFF6C63FF).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isLoggedIn ? Icons.check_circle_outline : Icons.lock_outline,
                size: 15,
                color: _isLoggedIn
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFF6C63FF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isLoggedIn
                      ? S.of(context).oauthLoggedIn
                      : (_statusMsg.isEmpty ? S.of(context).oauthLoginRequired : _statusMsg),
                  style: TextStyle(
                    color: _isLoggedIn
                        ? const Color(0xFF4ADE80)
                        : Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 버튼 행
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: (_isLoggedIn || _isLoggingIn) ? null : _login,
                child: Opacity(
                  opacity: _isLoggingIn ? 0.6 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      gradient: _isLoggedIn
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
                            ),
                      color: _isLoggedIn
                          ? Colors.white.withValues(alpha: 0.06)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isLoggingIn)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          Icon(
                            _isLoggedIn
                                ? Icons.check_rounded
                                : Icons.login_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _isLoggedIn
                              ? S.of(context).oauthLoggedInButton
                              : S.of(context).oauthLoginButton,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoggedIn) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _logout,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    S.of(context).oauthLogout,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
