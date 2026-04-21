import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../providers/config_provider.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../models/provider_item.dart';
import '../providers_notifier.dart';
import 'oauth_dialog.dart';
import '../../../../l10n/app_localizations.dart';

class OAuthSection extends StatefulWidget {
  final ProviderItem item;

  const OAuthSection({super.key, required this.item});

  @override
  State<OAuthSection> createState() => _OAuthSectionState();
}

class _OAuthSectionState extends State<OAuthSection> {
  // 로그인 여부는 widget.item.oauthLoggedIn이 단일 진실. 별도 변수 두지 않는다.
  bool _isLoggingIn = false;
  String _statusMsg = '';
  StreamSubscription<Map<String, dynamic>>? _eventSub;
  bool _isDialogOpen = false;
  OAuthDialogController? _dialogController;
  Timer? _pollTimer;

  String get _provider => widget.item.provider;
  String get _accountId => widget.item.accountId;

  ProvidersNotifier get _notifier =>
      Provider.of<ProvidersNotifier>(context, listen: false);
  ConfigProvider get _cfg =>
      Provider.of<ConfigProvider>(context, listen: false);

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
    if (_isLoggingIn) {
      try {
        unawaited(_cfg.cancelOAuthLogin(_accountId));
      } catch (_) {}
    }
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
      final result = await _cfg.getOAuthStatus(_accountId);
      if (mounted && result != null && result['loggedIn'] == true) {
        // _statusMsg만 로컬 상태. oauthLoggedIn은 recordOAuthLogin이 item setter로 통보.
        setState(() => _statusMsg = S.of(context).oauthLoginComplete);
        _closeDialog();
        _stopPolling();
        await _notifier.recordOAuthLogin(widget.item);
      }
    });
  }

  void _closeDialog() {
    if (_isDialogOpen && mounted) {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _isDialogOpen = false;
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
      if (!submitted && !widget.item.oauthLoggedIn) _cancelLogin();
    });
  }

  // ─── 초기 상태 로드 ───────────────────────────────────────

  Future<void> _loadInitialStatus() async {
    final result = await _cfg.getOAuthStatus(_accountId);
    if (mounted && result != null) {
      // item setter가 watchers(=ProviderCard)에게 직접 알림 → 카드 자동 rebuild.
      widget.item.oauthLoggedIn = result['loggedIn'] == true;
    }
  }

  // ─── /OAUTH_EVENT 구독 ────────────────────────────────────

  void _subscribeEvents() {
    _eventSub = AriAgent.on('/OAUTH_EVENT', (data) {
      final eventAccountId = data['accountId'] as String?;
      final matches = eventAccountId != null
          ? eventAccountId == _accountId
          : data['provider'] == _provider;
      if (!matches || !mounted) return;
      final type = data['type'] as String?;
      if (type == null) return;

      if (!_isLoggingIn &&
          (type == 'auth_url' || type == 'prompt' || type == 'progress')) {
        return;
      }

      bool justDone = false;
      setState(() {
        switch (type) {
          case 'auth_url':
            _statusMsg = S.of(context).oauthBrowserAuth;
            final url = data['authUrl'] as String?;
            if (url != null) {
              unawaited(
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                    .then((success) {
                  if (!success) {
                    debugPrint('❌ Failed to launch OAuth URL: $url');
                  }
                }).catchError((e) {
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
            _statusMsg = data['message'] as String? ??
                S.of(context).oauthInProgress;
            break;
          case 'done':
            _statusMsg = S.of(context).oauthLoginComplete;
            _isLoggingIn = false;
            _closeDialog();
            _stopPolling();
            justDone = true;
            break;
          case 'error':
            _isLoggingIn = false;
            _stopPolling();
            _closeDialog();
            _statusMsg = S.of(context).oauthError(
                data['message'] as String? ?? S.of(context).oauthErrorDefault);
            break;
        }
      });
      if (justDone) {
        // 저장은 notifier에 일임 — item 상태 갱신과 서버 저장 모두 통제됨.
        _notifier.recordOAuthLogin(widget.item);
      }
    });
  }

  // ─── 액션 ─────────────────────────────────────────────────

  Future<void> _login() async {
    setState(() {
      _isLoggingIn = true;
      _statusMsg = S.of(context).oauthStarting;
    });
    _ensureDialogOpen();
    try {
      await _cfg.startOAuthLogin(_accountId, _provider);
    } catch (_) {
      if (mounted) {
        setState(() => _isLoggingIn = false);
        _closeDialog();
      }
    }
  }

  Future<void> _cancelLogin() async {
    if (!_isLoggingIn) return;
    _stopPolling();
    if (mounted) {
      setState(() {
        _isLoggingIn = false;
        _statusMsg = '';
      });
    }
    unawaited(_cfg.cancelOAuthLogin(_accountId));
  }

  Future<void> _logout() async {
    await _cfg.logoutOAuth(_accountId);
    if (mounted) {
      // _isLoggingIn/_statusMsg는 로컬, oauthLoggedIn은 recordOAuthLogout이 통보.
      setState(() {
        _isLoggingIn = false;
        _statusMsg = '';
      });
      await _notifier.recordOAuthLogout(widget.item);
    }
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.item.oauthLoggedIn
                ? const Color(0xFF0D2B1A)
                : const Color(0xFF1E1A2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.item.oauthLoggedIn
                  ? const Color(0xFF4ADE80).withValues(alpha: 0.4)
                  : const Color(0xFF6C63FF).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.item.oauthLoggedIn ? Icons.check_circle_outline : Icons.lock_outline,
                size: 15,
                color: widget.item.oauthLoggedIn
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFF6C63FF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.item.oauthLoggedIn
                      ? S.of(context).oauthLoggedIn
                      : (_statusMsg.isEmpty
                          ? S.of(context).oauthLoginRequired
                          : _statusMsg),
                  style: TextStyle(
                    color: widget.item.oauthLoggedIn
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
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: (widget.item.oauthLoggedIn || _isLoggingIn) ? null : _login,
                child: Opacity(
                  opacity: _isLoggingIn ? 0.6 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      gradient: widget.item.oauthLoggedIn
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
                            ),
                      color: widget.item.oauthLoggedIn
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
                            widget.item.oauthLoggedIn
                                ? Icons.check_rounded
                                : Icons.login_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          widget.item.oauthLoggedIn
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
            if (widget.item.oauthLoggedIn) ...[
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
