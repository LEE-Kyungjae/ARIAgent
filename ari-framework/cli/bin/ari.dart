/// ARI Framework CLI
///
/// ARI 앱 프로젝트 초기화 및 배포 패키징 도구
///
/// 사용법:
///   ari init [options]    — 프로젝트 초기 세팅
///   ari build [options]   — 빌드 + dist/ 패키징
import 'dart:convert';
import 'dart:io';

// ──────────────────────────────────────────────────────────────────────────────
// Constants
// ──────────────────────────────────────────────────────────────────────────────

const _version = '1.0.0';

const _validCategories = [
  'productivity',
  'finance',
  'media',
  'utility',
  'education',
];

// ──────────────────────────────────────────────────────────────────────────────
// Entry point
// ──────────────────────────────────────────────────────────────────────────────

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    exit(0);
  }

  final command = args[0];

  switch (command) {
    case 'init':
      await _handleInit(args.sublist(1));
    case 'build':
      await _handleBuild(args.sublist(1));
    default:
      _printError("Unknown command: '$command'");
      _printUsage();
      exit(1);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// INIT — 프로젝트 초기 세팅 (1회)
// ──────────────────────────────────────────────────────────────────────────────

Future<void> _handleInit(List<String> args) async {
  _requirePubspec();

  final pubspec = _parsePubspec(File('pubspec.yaml').readAsStringSync());
  final appId = _getArg(args, '--app-id') ?? pubspec['name'] ?? 'my_app';
  final name = _getArg(args, '--name') ?? _defaultName(appId);
  final description = _getArg(args, '--desc') ?? pubspec['description'] ?? '';
  final category = _getArg(args, '--category') ?? 'utility';
  final githubUrl = _getArg(args, '--github') ?? '';
  final version = _cleanVersion(pubspec['version'] ?? '0.1.0');
  final versionCode = _extractVersionCode(pubspec['version'] ?? '0.1.0+1');

  _validateAppId(appId);
  _validateCategory(category);

  _printHeader();
  print('  command : init');
  print('  app_id  : $appId');
  print('  name    : $name');
  print('  category: $category');
  _printDivider();

  // 1. pubspec.yaml에 ari_plugin 추가
  _step('ari_plugin 의존성 추가');
  final pubspecContent = File('pubspec.yaml').readAsStringSync();
  if (pubspecContent.contains('ari_plugin')) {
    _msg('이미 존재 — 건너뜀');
  } else {
    _patchPubspec('pubspec.yaml');
    _done();
  }

  // 2. dist/app_info.json
  Directory('dist').createSync(recursive: true);
  _step('dist/app_info.json');
  if (File('dist/app_info.json').existsSync()) {
    _msg('이미 존재 — 건너뜀');
  } else {
    _writeJson('dist/app_info.json', {
      'app_id': appId,
      'name': name,
      'description': description,
      'category': category,
      'github_url': githubUrl,
      'version': version,
      'version_code': versionCode,
      'platform': Platform.isMacOS ? 'mac' : 'win',
    });
    _done();
  }

  // 3. dist/SKILL.md
  _step('dist/SKILL.md');
  if (File('dist/SKILL.md').existsSync()) {
    _msg('이미 존재 — 건너뜀');
  } else {
    File('dist/SKILL.md').writeAsStringSync(_skillTemplate(appId, name));
    _done();
  }

  // 4. dist/icon.png
  _step('dist/icon.png');
  if (File('dist/icon.png').existsSync()) {
    _msg('이미 존재 — 건너뜀');
  } else {
    final icon1024 = File('1024.png');
    final iconRoot = File('icon.png');
    if (icon1024.existsSync()) {
      icon1024.copySync('dist/icon.png');
      _msg('복사 (1024.png → dist/icon.png)');
    } else if (iconRoot.existsSync()) {
      iconRoot.copySync('dist/icon.png');
      _msg('복사 (icon.png → dist/icon.png)');
    } else {
      print('');
      _printError('아이콘 파일을 찾을 수 없습니다.');
      _printError('프로젝트 루트에 1024.png 또는 icon.png를 추가한 뒤 다시 실행하세요.');
      exit(1);
    }
  }

  // 5. lib/protocol_config.dart (번호 유지)
  _step('lib/protocol_config.dart');
  if (File('lib/protocol_config.dart').existsSync()) {
    _msg('이미 존재 — 건너뜀');
  } else {
    File('lib/protocol_config.dart')
        .writeAsStringSync(_protocolConfigTemplate(appId));
    _done();
  }

  // 5. lib/components/
  _step('lib/components/');
  final compDir = Directory('lib/components');
  if (compDir.existsSync()) {
    _msg('이미 존재 — 건너뜀');
  } else {
    compDir.createSync(recursive: true);
    File('lib/components/.gitkeep').writeAsStringSync('');
    _done();
  }

  // 6. flutter pub get
  _step('flutter pub get');
  final pubGet = await Process.run('flutter', ['pub', 'get']);
  if (pubGet.exitCode != 0) {
    _msg('실패 — 나중에 수동으로 실행하세요');
  } else {
    _done();
  }

  print('');
  _printDivider();
  print('  초기화 완료!');
  _printDivider();
  print('');
  print('  생성된 파일:');
  print('    dist/app_info.json        앱 메타데이터');
  print('    dist/SKILL.md             AI 스킬 문서 (내용을 채워주세요)');
  print('    dist/icon.png             앱 아이콘');
  print('    lib/protocol_config.dart  명령 핸들러');
  print('    lib/components/           기능 모듈 디렉토리');
  print('');
  print('  다음 단계:');
  print('    1. SKILL.md에 명령어를 정의하세요');
  print('    2. protocol_config.dart에 핸들러를 구현하세요');
  print('    3. 배포: ari build');
  print('');
}

// ──────────────────────────────────────────────────────────────────────────────
// BUILD — flutter build + dist/ 패키징
// ──────────────────────────────────────────────────────────────────────────────

Future<void> _handleBuild(List<String> args) async {
  _requirePubspec();

  if (!File('dist/app_info.json').existsSync()) {
    _printError('dist/app_info.json이 없습니다. 먼저 ari init을 실행하세요.');
    exit(1);
  }

  final appInfo = _readJson('dist/app_info.json');
  final appId = appInfo['app_id'] as String? ?? 'my_app';
  final version = appInfo['version'] as String? ?? '0.1.0';

  // 플랫폼 결정
  final isWin = args.contains('--win');
  final isMac = args.contains('--mac');
  late final String platform;
  if (isWin) {
    platform = 'windows';
  } else if (isMac) {
    platform = 'macos';
  } else {
    platform = Platform.isMacOS ? 'macos' : 'windows';
  }

  final skipBuild = args.contains('--skip-build');

  _printHeader();
  print('  command  : build');
  print('  app_id   : $appId');
  print('  version  : $version');
  print('  platform : $platform');
  _printDivider();

  // 1. ari_plugin 최신화
  _step('ari_plugin 업데이트');
  final upgrade = await Process.run(
    'flutter', ['pub', 'upgrade', 'ari_plugin'],
  );
  if (upgrade.exitCode != 0) {
    _msg('건너뜀 (실패해도 계속 진행)');
  } else {
    _done();
  }

  // 2. Flutter build
  if (skipBuild) {
    _step('flutter build');
    _msg('--skip-build 로 건너뜀');
  } else {
    _step('flutter build $platform --release');
    print('');
    final build = await Process.run('flutter', [
      'build', platform, '--release',
      '--split-debug-info=build/debug-info',
      '--obfuscate',
    ]);
    if (build.exitCode != 0) {
      _printError('빌드 실패:\n${build.stderr}');
      exit(1);
    }
    _step('flutter build');
    _done();
  }

  // 3. dist/ 디렉토리 준비 (배포 메타파일 보존)
  final distDir = Directory('dist');
  final preserveFiles = ['app_info.json', 'SKILL.md', 'icon.png'];
  final saved = <String, List<int>>{};
  for (final name in preserveFiles) {
    final f = File('dist/$name');
    if (f.existsSync()) saved[name] = f.readAsBytesSync();
  }
  if (distDir.existsSync()) {
    distDir.deleteSync(recursive: true);
  }
  distDir.createSync();
  for (final entry in saved.entries) {
    File('dist/${entry.key}').writeAsBytesSync(entry.value);
  }

  // 4. 바이너리 복사 + 이름 변경
  _step('바이너리 패키징');
  if (platform == 'macos') {
    final buildDir = Directory('build/macos/Build/Products/Release');
    if (!buildDir.existsSync()) {
      _printError('빌드 결과를 찾을 수 없습니다: ${buildDir.path}');
      exit(1);
    }
    // .app 번들 찾기
    final appBundle = buildDir.listSync().whereType<Directory>().firstWhere(
      (d) => d.path.endsWith('.app'),
      orElse: () {
        _printError('.app 번들을 찾을 수 없습니다.');
        exit(1);
      },
    );
    // app.app으로 복사
    _copyDirectory(appBundle, Directory('dist/app.app'));
    _done();
  } else {
    // Windows
    final buildDir = Directory('build/windows/x64/runner/Release');
    if (!buildDir.existsSync()) {
      _printError('빌드 결과를 찾을 수 없습니다: ${buildDir.path}');
      exit(1);
    }
    // Release 폴더 전체 → dist/ 하위로 복사 후 exe 이름 변경
    for (final entity in buildDir.listSync()) {
      final destName = entity.path.split('/').last;
      if (entity is File) {
        if (destName.endsWith('.exe')) {
          entity.copySync('dist/app.exe');
        } else {
          entity.copySync('dist/$destName');
        }
      } else if (entity is Directory) {
        _copyDirectory(entity, Directory('dist/$destName'));
      }
    }
    _done();
  }

  // 5. dist/app_info.json platform 갱신
  _step('dist/app_info.json 갱신');
  appInfo['platform'] = platform == 'macos' ? 'mac' : 'win';
  _writeJson('dist/app_info.json', appInfo);
  _done();

  // 6. dist/ 기존 파일 확인
  _step('dist/SKILL.md');
  if (File('dist/SKILL.md').existsSync()) {
    _msg('보존');
  } else {
    print('');
    _printError('dist/SKILL.md가 없습니다. ari init을 먼저 실행하세요.');
    exit(1);
  }

  _step('dist/icon.png');
  if (File('dist/icon.png').existsSync()) {
    _msg('보존');
  } else {
    print('');
    _printError('dist/icon.png가 없습니다. ari init을 먼저 실행하세요.');
    exit(1);
  }

  // Summary
  print('');
  _printDivider();
  print('  빌드 완료!');
  _printDivider();
  print('');

  // dist 목록 출력
  print('  dist/');
  _printTree(distDir, '  ');

  print('');
  print('  로컬 설치:');
  print('    cp -r dist/ ~/.ari-agent/apps/$appId/');
  print('');
}

// ──────────────────────────────────────────────────────────────────────────────
// Pubspec patching
// ──────────────────────────────────────────────────────────────────────────────

void _patchPubspec(String path) {
  final file = File(path);
  var content = file.readAsStringSync();

  const ariDep = '''
  ari_plugin:
    git:
      url: https://github.com/rightsna/ARIAgent.git
      ref: main
      path: ari-framework/plugin''';

  final flutterSdkPattern = RegExp(
    r'(  flutter:\n    sdk: flutter\n)',
    multiLine: true,
  );
  if (flutterSdkPattern.hasMatch(content)) {
    content = content.replaceFirst(
      flutterSdkPattern,
      '  flutter:\n    sdk: flutter\n$ariDep\n',
    );
  }

  file.writeAsStringSync(content);
}

// ──────────────────────────────────────────────────────────────────────────────
// Templates
// ──────────────────────────────────────────────────────────────────────────────

String _skillTemplate(String appId, String name) => '''---
name: $appId
description: $name 플러그인
allowed-tools: control_app read_app_state
---

# $name

## 개요

[앱이 무엇을 하는지 2-3줄로 설명합니다.]

## 명령어 목록

### 1. 상태 조회

| 명령어 | 설명 | 파라미터 |
|--------|------|----------|
| `GET_APP_STATUS` | 앱 상태 조�� | 없음 |

```json
{ "command": "GET_APP_STATUS", "params": {} }
```

### 2. 핵심 기능

[카테고리별로 명령어를 정리합니다.]

| 명령어 | 설명 | 파라미터 |
|--------|------|----------|
| `EXAMPLE_COMMAND` | 예시 명령 | `param1`: 설명 |

```json
{ "command": "EXAMPLE_COMMAND", "params": { "param1": "value" } }
```

## 실행 흐름

1. 앱 상태 확인 (`GET_APP_STATUS`)
2. 필요한 데이터 조회
3. 핵심 작업 수행
4. 결과 확인

## 자연어 요청 대응 가이드

| 사용자 요청 | 매핑 명령어 |
|-------------|-------------|
| "[예시 자연어 요청]" | `EXAMPLE_COMMAND` |
''';

String _protocolConfigTemplate(String appId) => '''import 'package:ari_plugin/ari_plugin.dart';

class ProtocolConfig {
  static const String appId = '$appId';

  /// 현재 앱 상태를 에이전트에 전달
  static Map<String, dynamic> getAppState() {
    return {
      'status': 'ready',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// 프로토콜 핸들러 생성
  static AppProtocolHandler createHandler() {
    return AppProtocolHandler(
      appId: appId,
      onCommand: (command, params) => handleCommand(
        command: command,
        params: params,
      ),
      onGetState: getAppState,
    );
  }

  /// 수신 명령 처리
  static dynamic handleCommand({
    required String command,
    required Map<String, dynamic> params,
  }) {
    switch (command) {
      case 'GET_APP_STATUS':
        return getAppState();
      // TODO: 명령어를 추가하세요
      default:
        return {
          'status': 'error',
          'message': 'Unknown command: \$command',
        };
    }
  }
}
''';

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

void _requirePubspec() {
  if (!File('pubspec.yaml').existsSync()) {
    _printError('pubspec.yaml을 찾을 수 없습니다. Flutter 프로젝트 루트에서 실행하세요.');
    exit(1);
  }
}

void _validateAppId(String appId) {
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(appId)) {
    _printError("Invalid app_id: '$appId' — snake_case만 허용 (예: my_app). --app-id로 지정하세요.");
    exit(1);
  }
}

void _validateCategory(String category) {
  if (!_validCategories.contains(category)) {
    _printError("Invalid category: '$category' — 허용 값: ${_validCategories.join(', ')}");
    exit(1);
  }
}

Map<String, String> _parsePubspec(String content) {
  final result = <String, String>{};
  for (final line in content.split('\n')) {
    final match = RegExp(r'^(\w+):\s*(.+)$').firstMatch(line);
    if (match != null) {
      final key = match.group(1)!;
      var value = match.group(2)!.trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      result[key] = value;
    }
  }
  return result;
}

Map<String, dynamic> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

void _writeJson(String path, Map<String, dynamic> data) {
  File(path).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(data) + '\n',
  );
}

int _extractVersionCode(String version) {
  final plusIdx = version.indexOf('+');
  if (plusIdx != -1) {
    return int.tryParse(version.substring(plusIdx + 1)) ?? 1;
  }
  return 1;
}

String _cleanVersion(String version) {
  final plusIdx = version.indexOf('+');
  if (plusIdx != -1) return version.substring(0, plusIdx);
  return version;
}

String _defaultName(String appId) {
  return appId
      .split('_')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

String? _getArg(List<String> args, String flag) {
  final idx = args.indexOf(flag);
  if (idx == -1 || idx + 1 >= args.length) return null;
  return args[idx + 1];
}

void _copyDirectory(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final entity in source.listSync(recursive: false)) {
    final destPath = '${destination.path}/${entity.path.split('/').last}';
    if (entity is File) {
      entity.copySync(destPath);
    } else if (entity is Directory) {
      _copyDirectory(entity, Directory(destPath));
    }
  }
}

void _printTree(Directory dir, String indent) {
  final entries = dir.listSync()..sort((a, b) => a.path.compareTo(b.path));
  for (var i = 0; i < entries.length; i++) {
    final entity = entries[i];
    final isLast = i == entries.length - 1;
    final name = entity.path.split('/').last;
    final prefix = isLast ? '└── ' : '├── ';
    if (entity is Directory) {
      print('$indent$prefix$name/');
      _printTree(entity, '$indent${isLast ? "    " : "│   "}');
    } else {
      print('$indent$prefix$name');
    }
  }
}

void _step(String msg) => stdout.write('  [$msg] ');
void _done() => print('... done');
void _msg(String msg) => print('... $msg');
void _printError(String msg) => print('[ERROR] $msg');

void _printHeader() {
  print('');
  print('┌─────────────────────────────────────────┐');
  print('│        ARI Framework CLI  v$_version        │');
  print('└─────────────────────────────────────────┘');
}

void _printDivider() => print('─────────────────────────────────────────');

void _printUsage() {
  print('''
ARI Framework CLI v$_version

ARI 앱 프로젝트 초기화 및 배포 패키징 도구

Usage:
  ari <command> [options]

Commands:
  init     프로젝트 초기 세팅 (ARI 연동 파일 생성)
  build    빌드 + dist/ 패키징

Init Options:
  --app-id    <id>          앱 ID (기본값: pubspec.yaml name)
  --name      <name>        앱 표시 이름
  --desc      <description> 앱 설명
  --category  <category>    카테고리 (${_validCategories.join(' | ')})
  --github    <url>         GitHub URL

Build Options:
  --mac          macOS 빌드 (기본값: 현재 OS)
  --win          Windows 빌드
  --skip-build   빌드 건너뛰고 패키징만

Examples:
  ari init
  ari init --name "My App" --category productivity
  ari build
  ari build --skip-build
''');
}
