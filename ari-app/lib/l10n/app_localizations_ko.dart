// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class SKo extends S {
  SKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'ARI Agent';

  @override
  String get tabChat => '채팅';

  @override
  String get tabPlace => '플레이스';

  @override
  String get tabAvatar => '아바타';

  @override
  String get tabSettings => '설정';

  @override
  String get cancel => '취소';

  @override
  String get save => '저장';

  @override
  String get confirm => '확인';

  @override
  String get delete => '삭제';

  @override
  String get minimize => '최소화';

  @override
  String get close => '닫기';

  @override
  String get retry => '재시도';

  @override
  String get copy => '복사';

  @override
  String get edit => '편집';

  @override
  String get done => '완료';

  @override
  String get reset => '초기화';

  @override
  String get apply => '적용';

  @override
  String get back => '뒤로';

  @override
  String get trayOpen => 'ARI 열기';

  @override
  String get trayHide => 'ARI 숨기기';

  @override
  String get trayQuit => '종료';

  @override
  String get chatHint => 'ARI에게 물어보세요...';

  @override
  String get messageCopied => '메시지를 복사했습니다.';

  @override
  String get settingsDataManagement => '데이터 관리';

  @override
  String get settingsDataManagementDesc => '에이전트의 기억과 대화 기록, 토큰을 관리해요.';

  @override
  String get settingsTokenManagement => '토큰 관리';

  @override
  String get settingsResetMemory => '기억 초기화';

  @override
  String get settingsResetConversation => '대화 초기화';

  @override
  String get settingsDangerZone => '위험 구역';

  @override
  String get settingsDangerZoneDesc => '한 번 실행하면 되돌릴 수 없어요. 신중하게 눌러주세요.';

  @override
  String get settingsDeleteAvatar => '아바타 삭제';

  @override
  String get settingsOpenFolder => '설정 폴더 열기';

  @override
  String get settingsShowAdvancedTools => '고급 도구 표시';

  @override
  String get settingsEnableExperimental => '실험기능 활성화';

  @override
  String get settingsPinToDesktop => '데스크탑에 고정 (항상 위)';

  @override
  String get settingsPinToDesktopDesc => 'ARI 창이 다른 창 위에 항상 떠 있도록 유지합니다.';

  @override
  String get settingsAvatarSize => '아바타 크기';

  @override
  String get settingsAvatarSizeSmall => '작게';

  @override
  String get settingsAvatarSizeMedium => '중간';

  @override
  String get settingsLanguage => '언어';

  @override
  String get settingsHomeDirNotFound => '사용자 홈 디렉토리를 찾을 수 없습니다.';

  @override
  String settingsActionCompleted(String title) {
    return '$title 완료되었습니다.';
  }

  @override
  String get serverAddress => '서버 주소 (URL)';

  @override
  String get longLivedAccessToken => '롱리브 액세스 토큰';

  @override
  String get errorAppNotFound => '앱을 찾을 수 없음';

  @override
  String get errorAppNotFoundMessage =>
      '\"ARIAgent\" 앱을 찾을 수 없습니다.\n앱을 수동으로 종료하신 뒤 다시 실행해 주세요.';

  @override
  String get errorIntegrationFailed => '연동 실패';

  @override
  String get errorUnknown => '알 수 없는 오류가 발생했습니다.';

  @override
  String get errorLoadMemoryFailed => '기억을 불러오는데 실패했습니다';

  @override
  String errorLoadMemoryFailedWith(String error) {
    return '기억을 불러오는데 실패했습니다: $error';
  }

  @override
  String errorSaveFailedWith(String error) {
    return '저장 실패: $error';
  }

  @override
  String get errorRestartApp => '앱을 수동으로 종료하신 뒤 다시 실행해 주세요.';

  @override
  String get errorLoadData => '데이터를 불러올 수 없습니다';

  @override
  String get errorLoadTools => '도구 정보를 가져오지 못했습니다.';

  @override
  String get errorLoadSkills => '스킬 정보를 가져오지 못했습니다.';

  @override
  String get memoryLongTermUpdated => '장기 기억이 업데이트되었습니다.';

  @override
  String get memoryLongTermHint => '장기 기억 내용을 입력하세요...';

  @override
  String get memoryNoLongTerm => '아직 저장된 장기 기억이 없습니다.';

  @override
  String get memoryNoDailyLog => '최근 일일 로그가 존재하지 않습니다.';

  @override
  String get memoryCoreTitle => 'Core Memory';

  @override
  String get memoryCoreDesc => '에이전트의 가치관과 장기적으로 기억해야 할 것들이에요.';

  @override
  String get memoryDailyTitle => 'Recent Daily Logs';

  @override
  String get memoryDailyDesc => '에이전트가 최근에 무얼 했는지 기록이에요.';

  @override
  String get logCopied => '로그를 복사했습니다.';

  @override
  String get logEmpty => '복사할 로그가 없습니다.';

  @override
  String get logRealtime => '실시간 에이전트 로그';

  @override
  String get skillDelete => '스킬 삭제';

  @override
  String skillDeleteConfirm(String name) {
    return '\"$name\" 스킬을 삭제하시겠습니까?';
  }

  @override
  String get chatClearTitle => '대화 목록 지우기';

  @override
  String get chatClearMessage =>
      '현재 아바타와의 대화 기록을 모두 지우시겠습니까?\n이 작업은 되돌릴 수 없습니다.';

  @override
  String get chatClearButton => '지우기';

  @override
  String get chatTooltipExpand => '펼쳐보기';

  @override
  String get chatTooltipCollapse => '접기';

  @override
  String get chatTooltipClearHistory => '대화 기록 지우기';

  @override
  String get modelProvidersPriority => 'AI Providers (우선순위 순)';

  @override
  String get modelSaving => '저장 중...';

  @override
  String get modelSaved => '저장됨';

  @override
  String get modelSaveFailed => '저장 실패';

  @override
  String get modelUnsaved => '저장되지 않음';

  @override
  String get modelApiKeyHint => 'API Key 입력 (sk-...)';

  @override
  String get oauthLoginComplete => '✅ 로그인 완료';

  @override
  String get oauthBrowserAuth => '🌐 브라우저에서 인증을 완료하세요';

  @override
  String get oauthCodeRequired => '✏️ 코드 입력 필요';

  @override
  String get oauthInProgress => '진행 중...';

  @override
  String oauthError(String message) {
    return '❌ $message';
  }

  @override
  String get oauthStarting => '로그인 시작 중...';

  @override
  String get oauthLoggedIn => '✅ 로그인됨 (OAuth)';

  @override
  String get oauthLoginRequired => 'OAuth 로그인이 필요합니다';

  @override
  String get oauthLoginButton => 'OAuth 로그인';

  @override
  String get oauthLoggedInButton => '로그인됨';

  @override
  String get oauthLogout => '로그아웃';

  @override
  String get oauthCodeInput => '코드 입력';

  @override
  String get oauthCodeHint => '코드를 입력하세요';

  @override
  String get oauthBrowserAuthTitle => '브라우저 인증';

  @override
  String get oauthErrorDefault => '오류 발생';

  @override
  String get oauthBrowserAutoProgress => '브라우저에서 인증을 완료하면 자동으로 진행됩니다.';

  @override
  String get oauthOpenBrowser => '브라우저 열기';

  @override
  String get haConnectBrain => '스마트 홈의 두뇌와 연결하세요';

  @override
  String get haEditConnection => '서버 연결 정보를 수정합니다';

  @override
  String get haServerUrlHelper => '로컬 IP 또는 외부 접속 도메인을 입력하세요.';

  @override
  String get haTokenHint => 'eyJ... 로 시작하는 토큰 문자열';

  @override
  String get haTokenHelper => 'HA 프로필 하단에서 생성한 토큰을 입력하세요.';

  @override
  String get haSaveChanges => '변경사항 저장하기';

  @override
  String get haStartIntegration => 'Home Assistant 연동 시작';

  @override
  String get haNoHaYet => '아직 Home Assistant가 없으신가요?';

  @override
  String get haOfficialSite => '공식 사이트';

  @override
  String get haInstallGuide => '설치 가이드 보기';

  @override
  String get haAskAri => '아리에게 묻기';

  @override
  String get haAskAriDesc => '설치 방법 상담';

  @override
  String get haAskAriChat => '채팅 탭에서 \"HA 설치 도와줘\"라고 물어보세요!';

  @override
  String get haConnected => '연결됨';

  @override
  String get haIntegrationSuccess => '✅ Home Assistant 서버 연동에 성공했습니다.';

  @override
  String get appsTitle => '앱';

  @override
  String get appsDesc => '에이전트가 연동해서 활용하는 앱들이에요.';

  @override
  String get appsStore => '앱스토어';

  @override
  String get appsNoApps => '설치된 앱이 없습니다.';

  @override
  String get appsCheckFolder => '~/.ari-agent/apps 폴더를 확인해주세요.';

  @override
  String get appsConnected => '연결됨';

  @override
  String get appsOffline => '오프라인';

  @override
  String appsDeleteConfirm(String title) {
    return '\"$title\" 앱을 삭제하시겠습니까?';
  }

  @override
  String get appsDeleteTitle => '앱 삭제';

  @override
  String get skillsTitle => '스킬';

  @override
  String get skillsDesc => '에이전트가 할 수 있는 능력들이에요.';

  @override
  String get skillsNoSkills => '등록된 스킬이 없습니다.';

  @override
  String get skillsCollapse => '접기';

  @override
  String get skillsExpand => '더보기';

  @override
  String get toolsTitle => '도구';

  @override
  String get toolsDesc => '에이전트가 작업할 때 꺼내 쓰는 도구들이에요.';

  @override
  String get toolsNoTools => '등록된 도구가 없습니다.';

  @override
  String get toolsCollapse => '접기';

  @override
  String get toolsExpand => '더보기';

  @override
  String get tokenTotalUsage => '전체 사용량';

  @override
  String get tokenByModel => '모델별 사용량';

  @override
  String get tokenDailyTrend => '일별 사용 추이';

  @override
  String get tokenTotal => '총 사용 토큰';

  @override
  String get tokenRefresh => '새로고침';

  @override
  String get tokenNoUsage => '아직 토큰 사용 기록이 없습니다';

  @override
  String get tokenNoUsageDesc => '아바타와 대화를 나누면\n사용량이 여기에 표시됩니다.';

  @override
  String scheduleTitle(String name) {
    return '$name의 스케줄';
  }

  @override
  String get scheduleDesc => '에이전트가 정해진 시간에 알아서 처리하는 일들이에요.';

  @override
  String get scheduleDayView => '하루보기';

  @override
  String get scheduleWeekView => '주간보기';

  @override
  String get scheduleEmpty => '등록된 스케줄이 없습니다\n채팅에서 \"매일 9시에 뉴스 요약해줘\" 라고 말해보세요';

  @override
  String scheduleRoutineCount(int count) {
    return '$count개의 루틴';
  }

  @override
  String get scheduleThisWeek => '이번주';

  @override
  String get scheduleWeekOrdinal1 => '첫째';

  @override
  String get scheduleWeekOrdinal2 => '둘째';

  @override
  String get scheduleWeekOrdinal3 => '셋째';

  @override
  String get scheduleWeekOrdinal4 => '넷째';

  @override
  String get scheduleWeekOrdinal5 => '다섯째';

  @override
  String scheduleMonthWeek(int month, String ordinal) {
    return '$month월 $ordinal 주';
  }

  @override
  String scheduleDateRangeSameMonth(int month, int startDay, int endDay) {
    return '$month월 $startDay일 - $endDay일';
  }

  @override
  String scheduleDateRangeDiffMonth(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth월 $startDay일 - $endMonth월 $endDay일';
  }

  @override
  String get scheduleRoutineDetail => '루틴 상세';

  @override
  String scheduleLastRun(String time) {
    return '마지막 실행: $time';
  }

  @override
  String get channelsTitle => '채널';

  @override
  String get channelsDesc => '에이전트가 외부와 소통하는 메시지 채널이에요.';

  @override
  String get channelsTest => '테스트';

  @override
  String get channelsSaved => '저장됨';

  @override
  String get channelsSaveSuccess => '저장되었습니다.';

  @override
  String get channelsSaveFailed => '저장 실패';

  @override
  String get channelsConnecting => '● 연결 중';

  @override
  String get channelsStarting => '● 시작 중...';

  @override
  String get channelsReady => '연결 준비됨';

  @override
  String get channelsSetupNeeded => '설정 필요';

  @override
  String get channelsTokenInvalid => '토큰 형식이 올바르지 않습니다. (예: 123456:ABCdef)';

  @override
  String get channelsTokenRequired => 'Bot Token을 먼저 입력하세요.';

  @override
  String get channelsTokenSaveFirst => 'Bot Token을 먼저 저장하세요.';

  @override
  String channelsConnectionSuccess(String botName) {
    return '@$botName 연결 성공';
  }

  @override
  String get channelsConnectionFailed => '연결 실패';

  @override
  String channelsMaskedTokenHint(String masked) {
    return '$masked  •  변경하려면 아래에 새 토큰을 입력하세요.';
  }

  @override
  String get channelsNewTokenHint => '새 토큰 입력 (변경 시)';

  @override
  String get channelsErrorOccurred => '오류가 발생했습니다.';

  @override
  String get placeConnected => '연결됨';

  @override
  String placeAppTooltipConnected(String title) {
    return '$title (연결됨)';
  }

  @override
  String get profileSystemPromptHint =>
      'LLM에게 부여할 역할이나 말투 등을 입력하세요. (예: 친절하고 다정한 어조로 답변해줘)';

  @override
  String get profileDescription =>
      '이곳에서 프로필 사진과 이름을 변경하면 채팅창 위젯에도 즉시 반영됩니다.\nPersona는 이 에이전트의 AI 성격 및 역할 정의에 사용됩니다.';

  @override
  String get serverPortSaved => '✅ 포트 저장 완료. (변경 시 에이전트 재시작 필요)';

  @override
  String get serverPortSaveFailedNoResponse => '❌ 저장 실패 (에이전트 응답하지 않음)';

  @override
  String get serverPortSaveFailed => '❌ 저장 실패';

  @override
  String get serverLogEmpty => '아직 로그가 없습니다.';

  @override
  String get serverPortChange => '변경';

  @override
  String get serverLogAlreadyRunning => '⚠️ 에이전트가 이미 실행 중';

  @override
  String serverLogProcessExited(String code) {
    return '프로세스 종료 (코드: $code)';
  }

  @override
  String get serverLogRestarting => '🔄 재시작...';

  @override
  String get agentStopped => '에이전트가 정지되었습니다';

  @override
  String get agentStoppedDesc => '채팅을 시작하려면 위쪽의 전원 버튼을\n눌러 에이전트를 실행해주세요.';

  @override
  String get serverConnectionRequired => '에이전트 연결이 필요합니다';

  @override
  String get serverConnectionRequiredDesc => '설정 > Agent 에서 에이전트를 먼저 실행해주세요.';

  @override
  String get modelSetupRequired => '모델 설정이 필요합니다';

  @override
  String get goToSettings => '설정으로 이동';

  @override
  String get currentAgent => '현재 에이전트';

  @override
  String get agentSelect => '에이전트 선택';

  @override
  String get newAvatar => '새로운 아바타';

  @override
  String get defaultAvatarName => '아리';

  @override
  String get dayNameSun => '일';

  @override
  String get dayNameMon => '월';

  @override
  String get dayNameTue => '화';

  @override
  String get dayNameWed => '수';

  @override
  String get dayNameThu => '목';

  @override
  String get dayNameFri => '금';

  @override
  String get dayNameSat => '토';

  @override
  String get scheduleToday => '오늘';

  @override
  String get scheduleTomorrow => '내일';

  @override
  String scheduleMonthDay(int month, int day) {
    return '$month월 $day일';
  }

  @override
  String get scheduleTapForToday => '(탭하면 오늘)';

  @override
  String get scheduleTask => '작업';

  @override
  String get schedulePrompt => '프롬프트:';

  @override
  String scheduleLastResult(String time) {
    return '마지막 결과 ($time):';
  }

  @override
  String get settingsServerDesc => '로컬 에이전트 상태 확인 및 제어';

  @override
  String get settingsAppearanceDesc => '화면 스타일 및 윈도우 핀 설정';

  @override
  String get settingsNotificationDesc => '데몬 상태에서 수신하는 OS 레벨 알림 설정';

  @override
  String get settingsExperimentalDesc => '고급 도구 및 실험적인 기능을 설정하는 메뉴';

  @override
  String get settingsExperimentalDescDisabled =>
      '고급 도구 및 실험적인 기능을 설정하는 메뉴 (에이전트 실행 필요)';

  @override
  String get settingsTokenDesc => '이 아바타의 AI 모델 토큰 사용량을 확인하고 한도를 설정합니다.';

  @override
  String get settingsResetMemoryDesc =>
      '이 아바타가 학습하고 기억한 벡터 데이터를 초기화합니다.\n장기 기억이 삭제되지만 페르소나는 유지됩니다.';

  @override
  String get settingsResetMemoryConfirm =>
      '정말로 이 아바타의 모든 기억을 초기화하시겠습니까?\n이 작업은 되돌릴 수 없습니다.';

  @override
  String get settingsResetConversationDesc =>
      '이 아바타와 나눈 모든 채팅 로그를 삭제합니다.\n기록 탭의 내용이 모두 비워집니다.';

  @override
  String get settingsResetConversationConfirm => '현재 아바타와의 모든 대화 내용을 삭제하시겠습니까?';

  @override
  String get settingsDeleteAvatarDesc =>
      '이 아바타의 모든 데이터(프로필, 로그, 설정)를 영구히 삭제합니다.\n기본 아바타(ARI)는 삭제할 수 없습니다.';

  @override
  String settingsDeleteAvatarConfirm(String name) {
    return '정말로 \"$name\" 아바타를 영구 삭제하시겠습니까?\n모든 관련 데이터가 즉시 삭제됩니다.';
  }

  @override
  String get settingsOpenFolderDesc =>
      '모든 아바타 정보와 로그가 저장된 .ari-agent 폴더를 탐색기에서 엽니다.';

  @override
  String get notificationDaemonTitle => '데몬 상태 메시지 알림';

  @override
  String get notificationDaemonDesc =>
      '창이 숨겨진 상태에서 새 응답이 오면 macOS/Windows 알림을 표시합니다.';

  @override
  String get notificationAutoTaskTitle => '자동 작업 결과 채팅창 표시';

  @override
  String get notificationAutoTaskDesc => '자동 작업이 완료되면 결과를 채팅창에 표시합니다.';

  @override
  String get experimentalShowAdvancedTools => '고급 도구 표시';

  @override
  String get experimentalShowAdvancedToolsDesc =>
      '스킬, 도구 탭 등 개발자용 고급 기능을 표시합니다.';

  @override
  String get experimentalEnableExperimental => '실험기능 활성화';

  @override
  String get experimentalEnableExperimentalDesc =>
      '정식 배포 전에 테스트 중인 기능을 미리 표시합니다.';

  @override
  String get experimentalAdvancedIntelligence => '고급 관계 지능 활성화';

  @override
  String get experimentalAdvancedIntelligenceDesc =>
      '의미론적 벡터 기억 및 관계 그래프를 활성화합니다. (아바타 > 메모리 탭에서 확인 가능)';

  @override
  String get experimentalModelReady => '임베딩 모델 준비 완료';

  @override
  String get experimentalModelLoading => '임베딩 모델 로드 중...';

  @override
  String get experimentalModelDownloading => '임베딩 모델 다운로드 중... (~280MB)';

  @override
  String get experimentalModelFailed => '모델 로드 실패 — 재시작 후 다시 시도';

  @override
  String get experimentalModelNotInstalled => '모델 미설치 — 활성화 시 자동 다운로드 (~280MB)';

  @override
  String get advMemoryStatsFailed => '통계를 불러올 수 없습니다.';

  @override
  String get advMemoryGraphDesc => '에이전트 메모리의 관계 그래프 현황입니다.';

  @override
  String get advMemoryNodeTitle => '메모리 노드';

  @override
  String get advMemoryCoreLabel => '핵심 기억 (Core)';

  @override
  String get advMemoryDailyLabel => '일일 로그 (Daily)';

  @override
  String get advMemoryTotal => '합계';

  @override
  String get advMemoryEntityTitle => '엔티티';

  @override
  String get advMemoryEntitySubtitle => '사람, 도구, 개념...';

  @override
  String get advMemoryTopicTitle => '토픽';

  @override
  String get advMemoryTopicSubtitle => '주제 카테고리';

  @override
  String get advMemoryRelTitle => '관계 (Relationships)';

  @override
  String get advMemoryRelMentions => 'MENTIONS (기억 → 엔티티)';

  @override
  String get advMemoryRelAbout => 'ABOUT (기억 → 토픽)';

  @override
  String get advMemoryRelFollows => 'FOLLOWS (시간 순서 체인)';

  @override
  String get advMemoryRelTotal => '총 관계 수';

  @override
  String get aboutSlogan => '함께 일하고, 함께 쉬는 AI';

  @override
  String get aboutDescription =>
      '기억과 실행을 바탕으로 함께하는 AI 동반자입니다. 질문에 답하는 데서 멈추지 않고, 사용자의 흐름 안에서 자연스럽게 이어지는 경험을 지향합니다.';

  @override
  String get aboutFeature1Title => '기억하는 대화';

  @override
  String get aboutFeature1Desc => '이전 맥락을 바탕으로 더 자연스럽게 이어집니다.';

  @override
  String get aboutFeature2Title => '실행으로 이어짐';

  @override
  String get aboutFeature2Desc => '말만 하지 않고 필요한 행동과 흐름으로 이어집니다.';

  @override
  String get aboutFeature3Title => '앱과 함께 움직임';

  @override
  String get aboutFeature3Desc => '여러 앱을 오가며 하나의 경험처럼 연결합니다.';

  @override
  String get aboutFeature4Title => '일과 놀이를 함께';

  @override
  String get aboutFeature4Desc => '집중하는 시간도 쉬는 시간도 같은 흐름 안에서 함께합니다.';

  @override
  String get aboutPhilosophy1Title => '사용자의 공간 안에 머무르기';

  @override
  String get aboutPhilosophy1Desc =>
      '멀리 있는 서비스처럼 느껴지기보다, 내 자리에 함께 있는 존재처럼 작동합니다.';

  @override
  String get aboutPhilosophy2Title => '대화보다 실제 도움';

  @override
  String get aboutPhilosophy2Desc => '좋은 말보다 다음 행동으로 이어지는 도움을 더 중요하게 생각합니다.';

  @override
  String get aboutPhilosophy3Title => '생산성만이 아닌 사용감';

  @override
  String get aboutPhilosophy3Desc =>
      '일할 때만 유용한 도구가 아니라, 쉬고 놀 때도 자연스럽게 곁에 두는 동반자를 지향합니다.';

  @override
  String get aboutUsageTitle => '이렇게 사용해보세요!';

  @override
  String get aboutUsage1 => '\"오늘 할 일 같이 정리해줘\"';

  @override
  String get aboutUsage1Cat => '일상 정리';

  @override
  String get aboutUsage2 => '\"30분 뒤에 커피 마시라고 알려줘\"';

  @override
  String get aboutUsage2Cat => '리마인더';

  @override
  String get aboutUsage3 => '\"지금 하던 작업 맥락 이어서 도와줘\"';

  @override
  String get aboutUsage3Cat => '업무 흐름 이어가기';

  @override
  String get aboutUsage4 => '\"게임하기 전에 필요한 것들 같이 챙겨줘\"';

  @override
  String get aboutUsage4Cat => '놀이 준비';

  @override
  String get aboutUsage5 => '\"방금 우리 대화 내용 기억해?\"';

  @override
  String get aboutUsage5Cat => '개인화된 관계';

  @override
  String get helpOAuth =>
      '구독형 서비스를 이미 사용하고 있다면(ChatGPT 등) 별도의 키 발급 없이 편리하게 사용합니다.';

  @override
  String get helpApiKey => '자신이 소유한 API 키를 직접 사용하여 가장 저렴하고 빠른 성능을 보장합니다.';

  @override
  String get helpPriority => '상단에 위치한 프로바이더를 먼저 시도하며, 오류 발생 시 아래 순서로 자동 전환됩니다.';

  @override
  String get helpKeyIssue => '키 발급 주소:';

  @override
  String get addProvider => '프로바이더 추가';

  @override
  String updateAvailable(String version, String mandatory) {
    return '새 버전 $version 사용 가능$mandatory';
  }

  @override
  String get updateMandatory => ' · 필수 업데이트';

  @override
  String get updateButton => '업데이트';

  @override
  String get homeServerRequired => '에이전트 연결 필요';

  @override
  String get homeServerRequiredDesc =>
      '이 기능을 사용하려면 에이전트 실행이 필요합니다.\n설정 탭에서 에이전트를 켜 주세요.';

  @override
  String get chatEmptyPrompt => '💬 ARI에게 무엇이든 물어보세요!';

  @override
  String get chatFollowUpPending => '대기 중';

  @override
  String chatFollowUpPendingCount(Object count) {
    return '대기 $count건';
  }

  @override
  String get modelSetupDesc => 'ARI가 답변하기 위해 사용할\nAI 프로바이더 및 API 키를 등록해주세요.';

  @override
  String get settingsModelDesc => 'AI 모델 및 API 키 설정';

  @override
  String get settingsModelDescDisabled => 'AI 모델 및 API 키 설정 (에이전트 실행 필요)';

  @override
  String get settingsAboutDesc => 'ARI Agent 소개 및 버전 정보';

  @override
  String get aboutPhilosophyHeading => 'ARI가 중요하게 생각하는 것';

  @override
  String get relativeSoon => '곧';

  @override
  String relativeInMinutes(int minutes) {
    return '$minutes분 후';
  }

  @override
  String relativeInHours(int hours) {
    return '$hours시간 후';
  }

  @override
  String relativeInDays(int days) {
    return '$days일 후';
  }

  @override
  String get notificationTitleBackground => 'ARI 백그라운드 응답';

  @override
  String get notificationTitleNewMessage => 'ARI 새 메시지';

  @override
  String get helpGuideTitle => 'AI 프로바이더 설정 가이드';

  @override
  String get helpOAuthTitle => '☁️ OAuth 서비스 연동 (추천)';

  @override
  String get helpApiKeyTitle => '🔑 API 키 직접 입력';

  @override
  String get helpPriorityTitle => '🔝 우선순위 오버라이드';

  @override
  String get chatSuggestion1 => '비트코인 거래앱 설치해줘!';

  @override
  String get chatSuggestion2 => '주식 자동매매 하고 싶어!';

  @override
  String get chatSuggestionSetupGreet => '👋 안녕';

  @override
  String get chatSuggestionSetupHowto => '🛠️ 사용법을 알려줘';

  @override
  String get chatSuggestionSetupApiKey => '🔑 API 키가 뭐야?';

  @override
  String get chatSuggestionSetupCheapest => '💳 어떤 방식이 제일 저렴해?';

  @override
  String get chatSuggestionSetupChatgpt => '⭐ ChatGPT로 연결하고 싶어';

  @override
  String get chatSuggestionSetupOauth => '🔓 OAuth가 뭐야?';

  @override
  String get chatSuggestionNormalGreet => '👋 안녕 ARI!';

  @override
  String get chatSuggestionNormalDisk => '💾 디스크 용량 확인';

  @override
  String get chatSuggestionNormalFile => '🔍 파일 찾아줘';

  @override
  String get chatSuggestionNormalRemind => '1분뒤 알려줘!';

  @override
  String get chatSuggestionNormalMusic => '🎵 감성적인 노래 들려줘!';

  @override
  String get appearanceGray => '그레이';

  @override
  String get appearanceDark => '다크';

  @override
  String get appearanceBlue => '블루';

  @override
  String get appearancePurple => '퍼플';

  @override
  String get appearanceBgTheme => '배경 테마';

  @override
  String get appearanceLarge => '크게';

  @override
  String get appearanceLanguage => '언어';

  @override
  String get appearanceSpaceUsage => '공간 사용';

  @override
  String get appearanceUnifySpace => '플레이스와 리스트 통합';

  @override
  String get appearanceUnifySpaceDesc =>
      '활성화하면 플레이스 탭에 공간 화면이 표시됩니다. 끄면 에이전트 목록이 표시됩니다.';

  @override
  String get placeWorking => '작업중';

  @override
  String get placeIdle => '대기중';

  @override
  String get placeResting => '쉬는중';

  @override
  String get skillsCheckFolder => '에이전트의 skills 폴더를 확인해주세요.';

  @override
  String get toolsCheckFolder => '에이전트의 tools 폴더를 확인해주세요.';

  @override
  String get refresh => '새로고침';
}
