import 'dart:async';
import 'dart:io';

import '../model/AriPersona.dart';
import '../ws/WebSocketService.dart';
import '../ws/settings_loader_stub.dart'
    if (dart.library.io) '../ws/settings_loader_io.dart';

// Flutter on Windows uses BoringSSL which doesn't trust the Windows certificate
// store on clean systems, causing HandshakeException on ariwith.me / CloudFront.
class _AriHttpOverrides extends HttpOverrides {
  static const _trustedHosts = [
    'ariwith.me',
    'cloudfront.net',
    'amazonaws.com',
    'supabase.co',
  ];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) =>
          _trustedHosts.any(
            (trusted) => host == trusted || host.endsWith('.$trusted'),
          );
  }
}

void _logDebug(Object message) {
  print(message);
}

class AriAgent {
  static final WebSocketService _webSocketService = WebSocketService();
  static const String defaultHost = '127.0.0.1';
  static const int defaultPort = 29277;

  /// 이 프로세스(=이 소켓)가 소유한 고정 페르소나.
  /// 원칙: 이 앱이 서버로 보내는 모든 /AGENT 호출에는 자기 페르소나가 동봉된다.
  static AriPersona? _ownPersona;
  static AriPersona? get ownPersona => _ownPersona;

  static get url => _webSocketService.url;
  static get isConnected => _webSocketService.isConnected;
  static AriConnectionNotifier get connectionNotifier =>
      _webSocketService.connectionNotifier;
  static Stream<bool> get connectionStream =>
      _webSocketService.connectionStream;

  static void init({
    String? url,
    String host = defaultHost,
    int port = defaultPort,
  }) {
    if (HttpOverrides.current == null) {
      HttpOverrides.global = _AriHttpOverrides();
    }
    final resolvedUrl = url ?? 'ws://$host:$port';
    _webSocketService.setFallbackUrlResolver(_resolveFallbackUrl);
    _webSocketService.initialize(resolvedUrl);
  }

  static void connect() {
    _webSocketService.connect();
  }

  static void close() {
    _webSocketService.close();
  }

  static void setAutomaticallyClose(bool value) {
    _webSocketService.automaticallyClose = value;
  }

  static Future<void> emit(String cmd, Map<String, dynamic> param) async {
    await _webSocketService.emit(cmd, param);
  }

  /// Registers the application with the given appId.
  /// [persona] 는 앱이 소유한 고정 정체성. 이 프로세스에 기억되고, 이후 이 앱이
  /// 보내는 모든 /AGENT 호출의 페이로드에 자동 동봉된다. 서버는 /APP.REGISTER
  /// 시점에는 페르소나를 수신하지 않는다 (Payload-only 원칙).
  static Future<void> register(String appId, {AriPersona? persona}) async {
    if (persona != null) {
      _ownPersona = persona;
    }
    await emit('/APP.REGISTER', {'appId': appId});
  }

  /// Sends a response to a previously received command.
  static Future<void> sendResponse({
    required String requestId,
    required dynamic result,
  }) async {
    await emit('/APP.COMMAND_RESPONSE', {
      'requestId': requestId,
      'result': result,
    });
  }

  /// 다른 에이전트(앱)에게 메시지를 전달한다.
  static Future<void> sendMessageToAgent(
    String toAppId,
    String message, {
    String? requestId,
    Map<String, dynamic>? details,
  }) async {
    final payload = <String, dynamic>{
      'to': toAppId,
      'message': message,
    };
    if (requestId != null) payload['requestId'] = requestId;
    if (details != null) payload['details'] = details;
    await emit('/AGENT', payload);
  }

  /// 아리(PM) 에이전트에게 메시지를 전달한다. `sendMessageToAgent('ari', …)` 의 헬퍼.
  static Future<void> sendMessageToAri(
    String message, {
    String? requestId,
    Map<String, dynamic>? details,
  }) {
    return sendMessageToAgent('ari', message, requestId: requestId, details: details);
  }

  static Future<Map<String, dynamic>> call(
    String uri, [
    Map<String, dynamic>? param,
    Duration idleTimeout = const Duration(seconds: 600),
  ]) async {
    final completer = Completer<Map<String, dynamic>>();
    final requestId = param?['requestId']?.toString();

    Timer? timer;
    StreamSubscription? progressSub;
    void Function()? cancelSend;

    // 타임아웃 타이머를 초기화하거나 갱신하는 내부 함수 (Activity Watchdog)
    void resetTimer() {
      timer?.cancel();
      timer = Timer(idleTimeout, () {
        if (!completer.isCompleted) {
          progressSub?.cancel();
          cancelSend?.call();
          completer.completeError(
            Exception('[AriAgent] Inactivity timeout: $uri ($requestId)'),
          );
        }
      });
    }

    resetTimer(); // 첫 실행 시 타이머 시작

    // 만약 requestId가 전달되었다면, 해당 요청에 대한 PROGRESS가 올 때마다 타이머 갱신
    if (requestId != null) {
      progressSub = on('/AGENT.PROGRESS', (data) {
        final payload = data['data'] ?? data;
        if (payload['requestId']?.toString() == requestId) {
          _logDebug(
            '[AriAgent] Refreshing timeout for $requestId due to activity signal.',
          );
          resetTimer();
        }
      });
    }

    cancelSend = await _webSocketService.send(uri, param ?? {}, (res) {
      progressSub?.cancel();
      cancelSend?.call();
      timer?.cancel();
      if (completer.isCompleted) return;

      if (res.r) {
        completer.complete(res.d as Map<String, dynamic>);
      } else {
        completer.completeError(Exception(res.m));
      }
    });

    return await completer.future;
  }

  static StreamSubscription<Map<String, dynamic>> on(
    String cmd,
    void Function(Map<String, dynamic>) callback,
  ) {
    return WebSocketService.on(cmd).listen(callback);
  }

  static void offAll(String cmd) => WebSocketService.offAll(cmd);

  static Future<String?> _resolveFallbackUrl(String currentUrl) async {
    final settings = await loadAriAgentSettings();
    if (settings == null) return null;

    final configuredUrl = settings['URL'];
    if (configuredUrl is String && configuredUrl.isNotEmpty) {
      return configuredUrl == currentUrl ? null : configuredUrl;
    }

    final configuredHost =
        (settings['HOST'] as String?)?.trim().isNotEmpty == true
            ? (settings['HOST'] as String).trim()
            : defaultHost;
    final configuredPort = _parsePort(settings['PORT']);
    if (configuredPort == null) return null;

    final fallbackUrl = 'ws://$configuredHost:$configuredPort';
    return fallbackUrl == currentUrl ? null : fallbackUrl;
  }

  static int? _parsePort(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
