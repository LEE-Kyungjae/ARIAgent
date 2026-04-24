import 'dart:async';
import 'dart:io';

import '../agent/AriAgent.dart';
import '../model/AriPersona.dart';

class AppProtocolHandler {
  final String appId;
  /// 앱이 소유한 고정 정체성. 서버 연결/등록 시 전달된다.
  final AriPersona? persona;
  final FutureOr<dynamic> Function(String command, Map<String, dynamic> params)? onCommand;
  final Map<String, dynamic> Function()? onGetState;
  /// 선택적 종료 훅. false를 반환하면 종료를 취소합니다. null/true면 정상 종료.
  final FutureOr<bool?> Function()? onShutdown;
  /// 다른 에이전트에서 온 메시지 수신 훅.
  /// 서버는 `/APP.PUSH` 로 최종 응답을 전송하며, `from` 이 자신의 `appId` 와 다르면
  /// (즉, 에이전트 간 호출 응답이면) 이 콜백이 호출된다.
  final FutureOr<void> Function(String from, String message, Map<String, dynamic> data)?
      onAgentMessage;

  AppProtocolHandler({
    required this.appId,
    this.persona,
    this.onCommand,
    this.onGetState,
    this.onShutdown,
    this.onAgentMessage,
  });

  final List<StreamSubscription> _subscriptions = [];
  Timer? _registerRetryTimer;
  bool _registered = false;

  void start() {
    _subscriptions.add(AriAgent.on('/APP.COMMAND', _handleAppCommand));
    _subscriptions.add(AriAgent.on('/APP.PUSH', _handleAppPushForAgentMessage));
    _subscriptions.add(AriAgent.on('/AGENT.FORWARD', _handleAgentForward));
    _subscriptions.add(AriAgent.on('/GREETING', (_) => _registerApp()));
    _subscriptions.add(AriAgent.on('/APP.REGISTER', _handleRegisterAck));
    _subscriptions.add(AriAgent.connectionStream.listen((connected) {
      if (connected) {
        _registered = false;
        _registerApp();
        _startRegisterRetry();
      } else {
        _stopRegisterRetry();
      }
    }));

    if (AriAgent.isConnected) {
      _registerApp();
      _startRegisterRetry();
    }
  }

  void stop() {
    _stopRegisterRetry();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _registerApp() {
    if (!AriAgent.isConnected) return;
    AriAgent.register(appId, persona: persona);
  }

  void _startRegisterRetry() {
    _registerRetryTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (!AriAgent.isConnected) {
        _stopRegisterRetry();
        return;
      }
      if (_registered) {
        _stopRegisterRetry();
        return;
      }
      _registerApp();
    });
  }

  void _stopRegisterRetry() {
    _registerRetryTimer?.cancel();
    _registerRetryTimer = null;
  }

  void _handleRegisterAck(Map<String, dynamic> data) {
    final ackAppId = data['data']?['appId'] ?? data['appId'];
    if (ackAppId == appId) {
      _registered = true;
      _stopRegisterRetry();
    }
  }

  /// `/APP.PUSH` 중 에이전트 간 응답 (`from` 이 있고 내 `appId` 가 아닌 경우) 만
  /// `onAgentMessage` 콜백으로 라우트.
  Future<void> _handleAppPushForAgentMessage(Map<String, dynamic> data) async {
    if (onAgentMessage == null) return;
    final payload = (data['data'] is Map<String, dynamic>)
        ? data['data'] as Map<String, dynamic>
        : data;

    final from = (payload['from'] as String?) ?? '';
    if (from.isEmpty || from == appId) return;

    final to = payload['to'];
    if (to is String && to.isNotEmpty && to != appId) return;

    final message = (payload['message'] as String?) ??
        (payload['response'] as String?) ??
        '';
    await onAgentMessage!(from, message, payload);
  }

  /// 다른 에이전트가 나에게 자연어 지시를 forward 한 경우.
  /// 원칙: 내 도메인 작업은 "내 세션"에서 "내 페르소나"로 수행되어야 한다.
  /// 그래서 서버가 포워드해준 메시지를 내가 /AGENT 로 재발행한다
  /// (ChatRepository 가 ownPersona 를 자동 동봉해 실어보낸다).
  Future<void> _handleAgentForward(Map<String, dynamic> data) async {
    final payload = (data['data'] is Map<String, dynamic>)
        ? data['data'] as Map<String, dynamic>
        : data;

    final to = payload['to'];
    if (to is String && to.isNotEmpty && to != appId) return;

    final message = (payload['message'] as String?) ?? '';
    final requestId = (payload['requestId'] as String?) ?? '';
    if (message.isEmpty || requestId.isEmpty) return;

    final own = AriAgent.ownPersona;
    final from = (payload['from'] as String?) ?? '';
    final rawTtl = payload['ttl'];
    final ttl = rawTtl is int
        ? rawTtl
        : (rawTtl is num ? rawTtl.toInt() : null);

    await AriAgent.emit('/AGENT.INTER', {
      'message': message,
      'requestId': requestId,
      if (own != null) 'persona': own.systemPrompt,
      if (own != null) 'avatarName': own.name,
      if (from.isNotEmpty) 'from': from,
      'to': appId,
      if (ttl != null) 'ttl': ttl,
    });
  }

  Future<void> _handleAppCommand(Map<String, dynamic> data) async {
    if (data['appId'] != appId) return;

    final command = data['command'] as String?;
    final requestId = data['requestId'] as String?;
    if (command == null) return;

    final params = data['params'] as Map<String, dynamic>? ?? {};

    // Handle reserved command: GET_STATE
    if (command == 'GET_STATE' && onGetState != null) {
      final state = onGetState!();
      if (requestId != null) {
        AriAgent.sendResponse(requestId: requestId, result: state);
      }
      return;
    }

    // Handle reserved command: SHUTDOWN
    if (command == 'SHUTDOWN') {
      final proceed = (await onShutdown?.call()) ?? true;
      if (requestId != null) {
        AriAgent.sendResponse(
          requestId: requestId,
          result: {'ok': proceed, 'shuttingDown': proceed},
        );
      }
      if (proceed) {
        // 응답이 소켓으로 빠져나간 뒤 종료되도록 짧게 지연
        await Future.delayed(const Duration(milliseconds: 300));
        exit(0);
      }
      return;
    }

    // Reserved: WORK.* (framework 공용 — 앱 onCommand 로 전달하지 않음)
    // 세션 상태는 AriChatProvider 가 /APP.COMMAND 를 별도 구독해 업데이트한다.
    // 여기서는 AI 에게 성공 응답만 돌려준다.
    if (command.startsWith('WORK.')) {
      if (requestId != null) {
        final sessionId = params['id']?.toString();
        AriAgent.sendResponse(
          requestId: requestId,
          result: {
            'status': 'success',
            if (sessionId != null) 'id': sessionId,
          },
        );
      }
      return;
    }

    final result = await onCommand?.call(command, params);

    if (requestId != null && result != null) {
      AriAgent.sendResponse(requestId: requestId, result: result);
    }
  }
}
