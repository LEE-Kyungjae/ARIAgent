import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers_notifier.dart';
import '../../../../l10n/app_localizations.dart';

/// 통합 OAuth 다이얼로그 컨트롤러.
/// 로그인 플로우 동안 단일 다이얼로그가 살아있고, 이벤트가 도착할 때마다
/// 컨트롤러를 통해 내용이 갱신된다 (URL → URL+코드 입력).
class OAuthDialogController extends ChangeNotifier {
  String? _authUrl;
  String? _instructions;
  String? _promptMessage;

  String? get authUrl => _authUrl;
  String? get instructions => _instructions;
  String? get promptMessage => _promptMessage;
  bool get hasUrl => _authUrl != null;
  bool get hasPrompt => _promptMessage != null;

  void setAuth({required String url, String? instructions}) {
    _authUrl = url;
    _instructions = instructions;
    notifyListeners();
  }

  void setPrompt(String message) {
    _promptMessage = message;
    notifyListeners();
  }
}

/// 통합 OAuth 다이얼로그.
/// 반환값: true = 사용자가 코드 제출, false = 닫힘/취소
Future<bool> showOAuthDialog(
  BuildContext context, {
  required OAuthDialogController controller,
  required String accountId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _OAuthDialog(controller: controller, accountId: accountId),
  );
  return result ?? false;
}

class _OAuthDialog extends StatefulWidget {
  final OAuthDialogController controller;
  final String accountId;
  const _OAuthDialog({required this.controller, required this.accountId});

  @override
  State<_OAuthDialog> createState() => _OAuthDialogState();
}

class _OAuthDialogState extends State<_OAuthDialog> {
  final TextEditingController _codeCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    _codeCtrl.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final value = _codeCtrl.text.trim();
    if (value.isEmpty) return;
    setState(() => _submitting = true);
    final notifier = Provider.of<ProvidersNotifier>(context, listen: false);
    await notifier.sendOAuthPrompt(widget.accountId, value);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        c.hasPrompt && !c.hasUrl
            ? S.of(context).oauthCodeInput
            : S.of(context).oauthBrowserAuthTitle,
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!c.hasUrl && !c.hasPrompt) ...[
              // URL/prompt가 아직 도착하지 않은 초기 상태 — 로딩 표시.
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    S.of(context).oauthStarting,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            if (c.hasUrl) ...[
              if (c.instructions != null) ...[
                Text(
                  c.instructions!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF111122),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  c.authUrl!,
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                S.of(context).oauthBrowserAutoProgress,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
            if (c.hasPrompt) ...[
              if (c.hasUrl)
                const Divider(height: 24, color: Colors.white12),
              Text(
                c.promptMessage!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeCtrl,
                autofocus: true,
                enabled: !_submitting,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: S.of(context).oauthCodeHint,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF111122),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (c.hasUrl && !c.hasPrompt)
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(c.authUrl!),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              S.of(context).oauthOpenBrowser,
              style: const TextStyle(
                color: Color(0xFF6C63FF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (c.hasPrompt)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
            ),
            onPressed: _submitting ? null : _submit,
            child: Text(
              S.of(context).confirm,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(
            c.hasPrompt ? S.of(context).cancel : S.of(context).close,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
        ),
      ],
    );
  }
}
