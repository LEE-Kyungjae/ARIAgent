import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:ari_plugin/ari_plugin.dart';
import '../repositories/config_repository.dart';

/// ConfigProvider: 애플리케이션 설정을 관리하고 서버 설정을 중계합니다.
class ConfigProvider extends ChangeNotifier {
  static final ConfigProvider _instance = ConfigProvider._internal();
  factory ConfigProvider() => _instance;
  ConfigProvider._internal();

  final ConfigRepository _repository = ConfigRepository();

  int get port => _repository.port;
  String get baseUrl => _repository.baseUrl;
  String get wsUrl => _repository.wsUrl;
  bool get isPinned => _repository.getIsPinned();
  String get avatarSize => _repository.getAvatarSize();
  bool get isChatCollapsed => _repository.getIsChatCollapsed();
  bool get isNotificationEnabled => _repository.getIsNotificationEnabled();
  bool get showTaskMessages => _repository.getShowTaskMessages();
  bool get isExperimentalEnabled => _repository.getIsExperimentalEnabled();
  bool get showAdvancedDeveloperUI => _repository.getShowAdvancedDeveloperUI();
  bool get isSpaceUnified => _repository.getIsSpaceUnified();
  String get backgroundTheme => _repository.getBackgroundTheme();
  String get localeCode => _repository.getLocale();
  Locale get locale => Locale(localeCode);
  double? get windowWidth => _repository.windowWidth;
  double? get windowHeight => _repository.windowHeight;
  double? get windowPosX => _repository.windowPosX;
  double? get windowPosY => _repository.windowPosY;

  String? _mode;
  String? get mode => _mode;
  bool get isDevelopment => _mode == 'development';

  Future<void> init() async {
    await _repository.init();

    // 서버 환경 상태 수신
    AriAgent.on('/GREETING', (data) {
      _mode = data['mode'];
      debugPrint('[SERVER] Running in ${data['mode']} mode');
      notifyListeners();
    });

    // 서버 로그 수신 시 디버그 콘솔에 출력
    AriAgent.on('/SERVER.LOG', (data) {
      debugPrint(
        '[SERVER-LOG] [${data['level']}] [${data['label']}] ${data['message']}',
      );
    });

    notifyListeners();
  }

  /// 포트 변경 (서버 재부팅 필요할 수 있음)
  Future<void> setPort(int newPort) async {
    await _repository.savePort(newPort);
    notifyListeners();
  }

  /// 항상 위 설정
  Future<void> updateIsPinned(bool value) async {
    await _repository.updateIsPinned(value);
    notifyListeners();
  }

  /// 아바타 크기 설정
  Future<void> updateAvatarSize(String size) async {
    await _repository.updateAvatarSize(size);
    notifyListeners();
  }

  /// 채팅 헤더 접힘 상태 설정
  Future<void> updateIsChatCollapsed(bool value) async {
    await _repository.updateIsChatCollapsed(value);
    notifyListeners();
  }

  Future<void> updateIsNotificationEnabled(bool value) async {
    await _repository.updateIsNotificationEnabled(value);
    notifyListeners();
  }

  Future<void> updateShowTaskMessages(bool value) async {
    await _repository.updateShowTaskMessages(value);
    try {
      await AriAgent.call('/SETTINGS', {'showTaskMessages': value});
    } catch (e) {
      debugPrint('[ConfigProvider] updateShowTaskMessages failed: $e');
    }
    notifyListeners();
  }

  Future<void> updateIsExperimentalEnabled(bool value) async {
    await _repository.updateIsExperimentalEnabled(value);
    notifyListeners();
  }

  Future<void> updateShowAdvancedDeveloperUI(bool value) async {
    await _repository.updateShowAdvancedDeveloperUI(value);
    notifyListeners();
  }

  Future<void> updateIsSpaceUnified(bool value) async {
    await _repository.updateIsSpaceUnified(value);
    notifyListeners();
  }

  /// 배경 테마 설정
  Future<void> updateBackgroundTheme(String theme) async {
    await _repository.updateBackgroundTheme(theme);
    notifyListeners();
  }

  /// 언어 설정
  Future<void> updateLocale(String localeCode) async {
    await _repository.updateLocale(localeCode);
    try {
      await AriAgent.call('/SETTINGS', {'language': localeCode});
    } catch (e) {
      debugPrint('[ConfigProvider] updateLocale sync to server failed: $e');
    }
    notifyListeners();
  }

  Future<void> updateWindowBounds({
    required double width,
    required double height,
    required double posX,
    required double posY,
  }) async {
    await _repository.updateWindowBounds(
      width: width,
      height: height,
      posX: posX,
      posY: posY,
    );
  }

  // --- 서버 통신 (AriAgent 호출) ---

  Future<Map<String, dynamic>?> getServerHealth() async {
    try {
      return await AriAgent.call('/HEALTH');
    } catch (e) {
      debugPrint('[ConfigProvider] getServerHealth failed: $e');
      return null;
    }
  }

  Future<bool> savePortToServer(int port) async {
    try {
      await AriAgent.call('/SETTINGS', {'port': port});
      return true;
    } catch (e) {
      debugPrint('[ConfigProvider] savePortToServer failed: $e');
      return false;
    }
  }

}
