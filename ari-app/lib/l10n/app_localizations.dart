import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'ARI Agent'**
  String get appTitle;

  /// No description provided for @tabChat.
  ///
  /// In ko, this message translates to:
  /// **'채팅'**
  String get tabChat;

  /// No description provided for @tabPlace.
  ///
  /// In ko, this message translates to:
  /// **'플레이스'**
  String get tabPlace;

  /// No description provided for @tabList.
  ///
  /// In ko, this message translates to:
  /// **'리스트'**
  String get tabList;

  /// No description provided for @tabAvatar.
  ///
  /// In ko, this message translates to:
  /// **'아바타'**
  String get tabAvatar;

  /// No description provided for @tabSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get tabSettings;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get save;

  /// No description provided for @confirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get delete;

  /// No description provided for @minimize.
  ///
  /// In ko, this message translates to:
  /// **'최소화'**
  String get minimize;

  /// No description provided for @close.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In ko, this message translates to:
  /// **'재시도'**
  String get retry;

  /// No description provided for @copy.
  ///
  /// In ko, this message translates to:
  /// **'복사'**
  String get copy;

  /// No description provided for @edit.
  ///
  /// In ko, this message translates to:
  /// **'편집'**
  String get edit;

  /// No description provided for @done.
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get done;

  /// No description provided for @reset.
  ///
  /// In ko, this message translates to:
  /// **'초기화'**
  String get reset;

  /// No description provided for @apply.
  ///
  /// In ko, this message translates to:
  /// **'적용'**
  String get apply;

  /// No description provided for @back.
  ///
  /// In ko, this message translates to:
  /// **'뒤로'**
  String get back;

  /// No description provided for @trayOpen.
  ///
  /// In ko, this message translates to:
  /// **'ARI 열기'**
  String get trayOpen;

  /// No description provided for @trayHide.
  ///
  /// In ko, this message translates to:
  /// **'ARI 숨기기'**
  String get trayHide;

  /// No description provided for @trayQuit.
  ///
  /// In ko, this message translates to:
  /// **'종료'**
  String get trayQuit;

  /// No description provided for @chatHint.
  ///
  /// In ko, this message translates to:
  /// **'ARI에게 물어보세요...'**
  String get chatHint;

  /// No description provided for @messageCopied.
  ///
  /// In ko, this message translates to:
  /// **'메시지를 복사했습니다.'**
  String get messageCopied;

  /// No description provided for @settingsDataManagement.
  ///
  /// In ko, this message translates to:
  /// **'데이터 관리'**
  String get settingsDataManagement;

  /// No description provided for @settingsDataManagementDesc.
  ///
  /// In ko, this message translates to:
  /// **'에이전트의 기억과 대화 기록, 토큰을 관리해요.'**
  String get settingsDataManagementDesc;

  /// No description provided for @settingsTokenManagement.
  ///
  /// In ko, this message translates to:
  /// **'토큰 관리'**
  String get settingsTokenManagement;

  /// No description provided for @settingsResetMemory.
  ///
  /// In ko, this message translates to:
  /// **'기억 초기화'**
  String get settingsResetMemory;

  /// No description provided for @settingsResetConversation.
  ///
  /// In ko, this message translates to:
  /// **'대화 초기화'**
  String get settingsResetConversation;

  /// No description provided for @settingsDangerZone.
  ///
  /// In ko, this message translates to:
  /// **'위험 구역'**
  String get settingsDangerZone;

  /// No description provided for @settingsDangerZoneDesc.
  ///
  /// In ko, this message translates to:
  /// **'한 번 실행하면 되돌릴 수 없어요. 신중하게 눌러주세요.'**
  String get settingsDangerZoneDesc;

  /// No description provided for @settingsDeleteAvatar.
  ///
  /// In ko, this message translates to:
  /// **'아바타 삭제'**
  String get settingsDeleteAvatar;

  /// No description provided for @settingsOpenFolder.
  ///
  /// In ko, this message translates to:
  /// **'설정 폴더 열기'**
  String get settingsOpenFolder;

  /// No description provided for @settingsShowAdvancedTools.
  ///
  /// In ko, this message translates to:
  /// **'고급 도구 표시'**
  String get settingsShowAdvancedTools;

  /// No description provided for @settingsEnableExperimental.
  ///
  /// In ko, this message translates to:
  /// **'실험기능 활성화'**
  String get settingsEnableExperimental;

  /// No description provided for @settingsPinToDesktop.
  ///
  /// In ko, this message translates to:
  /// **'데스크탑에 고정 (항상 위)'**
  String get settingsPinToDesktop;

  /// No description provided for @settingsPinToDesktopDesc.
  ///
  /// In ko, this message translates to:
  /// **'ARI 창이 다른 창 위에 항상 떠 있도록 유지합니다.'**
  String get settingsPinToDesktopDesc;

  /// No description provided for @settingsAvatarSize.
  ///
  /// In ko, this message translates to:
  /// **'아바타 크기'**
  String get settingsAvatarSize;

  /// No description provided for @settingsAvatarSizeSmall.
  ///
  /// In ko, this message translates to:
  /// **'작게'**
  String get settingsAvatarSizeSmall;

  /// No description provided for @settingsAvatarSizeMedium.
  ///
  /// In ko, this message translates to:
  /// **'중간'**
  String get settingsAvatarSizeMedium;

  /// No description provided for @settingsLanguage.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get settingsLanguage;

  /// No description provided for @settingsHomeDirNotFound.
  ///
  /// In ko, this message translates to:
  /// **'사용자 홈 디렉토리를 찾을 수 없습니다.'**
  String get settingsHomeDirNotFound;

  /// No description provided for @settingsActionCompleted.
  ///
  /// In ko, this message translates to:
  /// **'{title} 완료되었습니다.'**
  String settingsActionCompleted(String title);

  /// No description provided for @serverAddress.
  ///
  /// In ko, this message translates to:
  /// **'서버 주소 (URL)'**
  String get serverAddress;

  /// No description provided for @longLivedAccessToken.
  ///
  /// In ko, this message translates to:
  /// **'롱리브 액세스 토큰'**
  String get longLivedAccessToken;

  /// No description provided for @errorAppNotFound.
  ///
  /// In ko, this message translates to:
  /// **'앱을 찾을 수 없음'**
  String get errorAppNotFound;

  /// No description provided for @errorAppNotFoundMessage.
  ///
  /// In ko, this message translates to:
  /// **'\"ARIAgent\" 앱을 찾을 수 없습니다.\n앱을 수동으로 종료하신 뒤 다시 실행해 주세요.'**
  String get errorAppNotFoundMessage;

  /// No description provided for @errorIntegrationFailed.
  ///
  /// In ko, this message translates to:
  /// **'연동 실패'**
  String get errorIntegrationFailed;

  /// No description provided for @errorUnknown.
  ///
  /// In ko, this message translates to:
  /// **'알 수 없는 오류가 발생했습니다.'**
  String get errorUnknown;

  /// No description provided for @errorLoadMemoryFailed.
  ///
  /// In ko, this message translates to:
  /// **'기억을 불러오는데 실패했습니다'**
  String get errorLoadMemoryFailed;

  /// No description provided for @errorLoadMemoryFailedWith.
  ///
  /// In ko, this message translates to:
  /// **'기억을 불러오는데 실패했습니다: {error}'**
  String errorLoadMemoryFailedWith(String error);

  /// No description provided for @errorSaveFailedWith.
  ///
  /// In ko, this message translates to:
  /// **'저장 실패: {error}'**
  String errorSaveFailedWith(String error);

  /// No description provided for @errorRestartApp.
  ///
  /// In ko, this message translates to:
  /// **'앱을 수동으로 종료하신 뒤 다시 실행해 주세요.'**
  String get errorRestartApp;

  /// No description provided for @errorLoadData.
  ///
  /// In ko, this message translates to:
  /// **'데이터를 불러올 수 없습니다'**
  String get errorLoadData;

  /// No description provided for @errorLoadTools.
  ///
  /// In ko, this message translates to:
  /// **'도구 정보를 가져오지 못했습니다.'**
  String get errorLoadTools;

  /// No description provided for @errorLoadSkills.
  ///
  /// In ko, this message translates to:
  /// **'스킬 정보를 가져오지 못했습니다.'**
  String get errorLoadSkills;

  /// No description provided for @memoryLongTermUpdated.
  ///
  /// In ko, this message translates to:
  /// **'장기 기억이 업데이트되었습니다.'**
  String get memoryLongTermUpdated;

  /// No description provided for @memoryLongTermHint.
  ///
  /// In ko, this message translates to:
  /// **'장기 기억 내용을 입력하세요...'**
  String get memoryLongTermHint;

  /// No description provided for @memoryNoLongTerm.
  ///
  /// In ko, this message translates to:
  /// **'아직 저장된 장기 기억이 없습니다.'**
  String get memoryNoLongTerm;

  /// No description provided for @memoryNoDailyLog.
  ///
  /// In ko, this message translates to:
  /// **'최근 일일 로그가 존재하지 않습니다.'**
  String get memoryNoDailyLog;

  /// No description provided for @memoryCoreTitle.
  ///
  /// In ko, this message translates to:
  /// **'Core Memory'**
  String get memoryCoreTitle;

  /// No description provided for @memoryCoreDesc.
  ///
  /// In ko, this message translates to:
  /// **'에이전트의 가치관과 장기적으로 기억해야 할 것들이에요.'**
  String get memoryCoreDesc;

  /// No description provided for @memoryDailyTitle.
  ///
  /// In ko, this message translates to:
  /// **'Recent Daily Logs'**
  String get memoryDailyTitle;

  /// No description provided for @memoryDailyDesc.
  ///
  /// In ko, this message translates to:
  /// **'에이전트가 최근에 무얼 했는지 기록이에요.'**
  String get memoryDailyDesc;

  /// No description provided for @logCopied.
  ///
  /// In ko, this message translates to:
  /// **'로그를 복사했습니다.'**
  String get logCopied;

  /// No description provided for @logEmpty.
  ///
  /// In ko, this message translates to:
  /// **'복사할 로그가 없습니다.'**
  String get logEmpty;

  /// No description provided for @logRealtime.
  ///
  /// In ko, this message translates to:
  /// **'실시간 에이전트 로그'**
  String get logRealtime;

  /// No description provided for @skillDelete.
  ///
  /// In ko, this message translates to:
  /// **'스킬 삭제'**
  String get skillDelete;

  /// No description provided for @skillDeleteConfirm.
  ///
  /// In ko, this message translates to:
  /// **'\"{name}\" 스킬을 삭제하시겠습니까?'**
  String skillDeleteConfirm(String name);

  /// No description provided for @chatClearTitle.
  ///
  /// In ko, this message translates to:
  /// **'대화 목록 지우기'**
  String get chatClearTitle;

  /// No description provided for @chatClearMessage.
  ///
  /// In ko, this message translates to:
  /// **'현재 아바타와의 대화 기록을 모두 지우시겠습니까?\n이 작업은 되돌릴 수 없습니다.'**
  String get chatClearMessage;

  /// No description provided for @chatClearButton.
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get chatClearButton;

  /// No description provided for @chatTooltipExpand.
  ///
  /// In ko, this message translates to:
  /// **'펼쳐보기'**
  String get chatTooltipExpand;

  /// No description provided for @chatTooltipCollapse.
  ///
  /// In ko, this message translates to:
  /// **'접기'**
  String get chatTooltipCollapse;

  /// No description provided for @chatTooltipClearHistory.
  ///
  /// In ko, this message translates to:
  /// **'대화 기록 지우기'**
  String get chatTooltipClearHistory;

  /// No description provided for @modelProvidersPriority.
  ///
  /// In ko, this message translates to:
  /// **'AI Providers (우선순위 순)'**
  String get modelProvidersPriority;

  /// No description provided for @modelSaving.
  ///
  /// In ko, this message translates to:
  /// **'저장 중...'**
  String get modelSaving;

  /// No description provided for @modelSaved.
  ///
  /// In ko, this message translates to:
  /// **'저장됨'**
  String get modelSaved;

  /// No description provided for @modelSaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'저장 실패'**
  String get modelSaveFailed;

  /// No description provided for @modelUnsaved.
  ///
  /// In ko, this message translates to:
  /// **'저장되지 않음'**
  String get modelUnsaved;

  /// No description provided for @modelApiKeyHint.
  ///
  /// In ko, this message translates to:
  /// **'API Key 입력 (sk-...)'**
  String get modelApiKeyHint;

  /// No description provided for @oauthLoginComplete.
  ///
  /// In ko, this message translates to:
  /// **'✅ 로그인 완료'**
  String get oauthLoginComplete;

  /// No description provided for @oauthBrowserAuth.
  ///
  /// In ko, this message translates to:
  /// **'🌐 브라우저에서 인증을 완료하세요'**
  String get oauthBrowserAuth;

  /// No description provided for @oauthCodeRequired.
  ///
  /// In ko, this message translates to:
  /// **'✏️ 코드 입력 필요'**
  String get oauthCodeRequired;

  /// No description provided for @oauthInProgress.
  ///
  /// In ko, this message translates to:
  /// **'진행 중...'**
  String get oauthInProgress;

  /// No description provided for @oauthError.
  ///
  /// In ko, this message translates to:
  /// **'❌ {message}'**
  String oauthError(String message);

  /// No description provided for @oauthStarting.
  ///
  /// In ko, this message translates to:
  /// **'로그인 시작 중...'**
  String get oauthStarting;

  /// No description provided for @oauthLoggedIn.
  ///
  /// In ko, this message translates to:
  /// **'✅ 로그인됨 (OAuth)'**
  String get oauthLoggedIn;

  /// No description provided for @oauthLoginRequired.
  ///
  /// In ko, this message translates to:
  /// **'OAuth 로그인이 필요합니다'**
  String get oauthLoginRequired;

  /// No description provided for @oauthLoginButton.
  ///
  /// In ko, this message translates to:
  /// **'OAuth 로그인'**
  String get oauthLoginButton;

  /// No description provided for @oauthLoggedInButton.
  ///
  /// In ko, this message translates to:
  /// **'로그인됨'**
  String get oauthLoggedInButton;

  /// No description provided for @oauthLogout.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get oauthLogout;

  /// No description provided for @oauthCodeInput.
  ///
  /// In ko, this message translates to:
  /// **'코드 입력'**
  String get oauthCodeInput;

  /// No description provided for @oauthCodeHint.
  ///
  /// In ko, this message translates to:
  /// **'코드를 입력하세요'**
  String get oauthCodeHint;

  /// No description provided for @oauthBrowserAuthTitle.
  ///
  /// In ko, this message translates to:
  /// **'브라우저 인증'**
  String get oauthBrowserAuthTitle;

  /// No description provided for @oauthErrorDefault.
  ///
  /// In ko, this message translates to:
  /// **'오류 발생'**
  String get oauthErrorDefault;

  /// No description provided for @oauthBrowserAutoProgress.
  ///
  /// In ko, this message translates to:
  /// **'브라우저에서 인증을 완료하면 자동으로 진행됩니다.'**
  String get oauthBrowserAutoProgress;

  /// No description provided for @oauthOpenBrowser.
  ///
  /// In ko, this message translates to:
  /// **'브라우저 열기'**
  String get oauthOpenBrowser;

  /// No description provided for @haConnectBrain.
  ///
  /// In ko, this message translates to:
  /// **'스마트 홈의 두뇌와 연결하세요'**
  String get haConnectBrain;

  /// No description provided for @haEditConnection.
  ///
  /// In ko, this message translates to:
  /// **'서버 연결 정보를 수정합니다'**
  String get haEditConnection;

  /// No description provided for @haServerUrlHelper.
  ///
  /// In ko, this message translates to:
  /// **'로컬 IP 또는 외부 접속 도메인을 입력하세요.'**
  String get haServerUrlHelper;

  /// No description provided for @haTokenHint.
  ///
  /// In ko, this message translates to:
  /// **'eyJ... 로 시작하는 토큰 문자열'**
  String get haTokenHint;

  /// No description provided for @haTokenHelper.
  ///
  /// In ko, this message translates to:
  /// **'HA 프로필 하단에서 생성한 토큰을 입력하세요.'**
  String get haTokenHelper;

  /// No description provided for @haSaveChanges.
  ///
  /// In ko, this message translates to:
  /// **'변경사항 저장하기'**
  String get haSaveChanges;

  /// No description provided for @haStartIntegration.
  ///
  /// In ko, this message translates to:
  /// **'Home Assistant 연동 시작'**
  String get haStartIntegration;

  /// No description provided for @haNoHaYet.
  ///
  /// In ko, this message translates to:
  /// **'아직 Home Assistant가 없으신가요?'**
  String get haNoHaYet;

  /// No description provided for @haOfficialSite.
  ///
  /// In ko, this message translates to:
  /// **'공식 사이트'**
  String get haOfficialSite;

  /// No description provided for @haInstallGuide.
  ///
  /// In ko, this message translates to:
  /// **'설치 가이드 보기'**
  String get haInstallGuide;

  /// No description provided for @haAskAri.
  ///
  /// In ko, this message translates to:
  /// **'아리에게 묻기'**
  String get haAskAri;

  /// No description provided for @haAskAriDesc.
  ///
  /// In ko, this message translates to:
  /// **'설치 방법 상담'**
  String get haAskAriDesc;

  /// No description provided for @haAskAriChat.
  ///
  /// In ko, this message translates to:
  /// **'채팅 탭에서 \"HA 설치 도와줘\"라고 물어보세요!'**
  String get haAskAriChat;

  /// No description provided for @haConnected.
  ///
  /// In ko, this message translates to:
  /// **'연결됨'**
  String get haConnected;

  /// No description provided for @haIntegrationSuccess.
  ///
  /// In ko, this message translates to:
  /// **'✅ Home Assistant 서버 연동에 성공했습니다.'**
  String get haIntegrationSuccess;

  /// No description provided for @officeTitle.
  ///
  /// In ko, this message translates to:
  /// **'에이전트 오피스'**
  String get officeTitle;

  /// No description provided for @officeInvite.
  ///
  /// In ko, this message translates to:
  /// **'초대'**
  String get officeInvite;

  /// No description provided for @officeInvited.
  ///
  /// In ko, this message translates to:
  /// **'초대됨'**
  String get officeInvited;

  /// No description provided for @officeInvitingApp.
  ///
  /// In ko, this message translates to:
  /// **'\'{name}\' 초대 중...'**
  String officeInvitingApp(String name);

  /// No description provided for @officeInvitedApp.
  ///
  /// In ko, this message translates to:
  /// **'\'{name}\' 초대 완료'**
  String officeInvitedApp(String name);

  /// No description provided for @officeInviteFailed.
  ///
  /// In ko, this message translates to:
  /// **'초대 실패: {error}'**
  String officeInviteFailed(String error);

  /// No description provided for @officeNoAgents.
  ///
  /// In ko, this message translates to:
  /// **'가능한 에이전트가 없습니다.'**
  String get officeNoAgents;

  /// No description provided for @officeNoPlatformBuild.
  ///
  /// In ko, this message translates to:
  /// **'{name}: 현재 플랫폼용 빌드가 없습니다.'**
  String officeNoPlatformBuild(String name);

  /// No description provided for @appsTitle.
  ///
  /// In ko, this message translates to:
  /// **'앱'**
  String get appsTitle;

  /// No description provided for @appsDesc.
  ///
  /// In ko, this message translates to:
  /// **'에이전트가 연동해서 활용하는 앱들이에요.'**
  String get appsDesc;

  /// No description provided for @appsStore.
  ///
  /// In ko, this message translates to:
  /// **'앱스토어'**
  String get appsStore;

  /// No description provided for @appsNoApps.
  ///
  /// In ko, this message translates to:
  /// **'설치된 앱이 없습니다.'**
  String get appsNoApps;

  /// No description provided for @appsCheckFolder.
  ///
  /// In ko, this message translates to:
  /// **'~/.ari-agent/apps 폴더를 확인해주세요.'**
  String get appsCheckFolder;

  /// No description provided for @appsConnected.
  ///
  /// In ko, this message translates to:
  /// **'연결됨'**
  String get appsConnected;

  /// No description provided for @appsOffline.
  ///
  /// In ko, this message translates to:
  /// **'오프라인'**
  String get appsOffline;

  /// No description provided for @appsDeleteConfirm.
  ///
  /// In ko, this message translates to:
  /// **'\"{title}\" 앱을 삭제하시겠습니까?'**
  String appsDeleteConfirm(String title);

  /// No description provided for @appsDeleteTitle.
  ///
  /// In ko, this message translates to:
  /// **'앱 삭제'**
  String get appsDeleteTitle;

  /// No description provided for @skillsTitle.
  ///
  /// In ko, this message translates to:
  /// **'스킬'**
  String get skillsTitle;

  /// No description provided for @skillsDesc.
  ///
  /// In ko, this message translates to:
  /// **'에이전트가 할 수 있는 능력들이에요.'**
  String get skillsDesc;

  /// No description provided for @skillsNoSkills.
  ///
  /// In ko, this message translates to:
  /// **'등록된 스킬이 없습니다.'**
  String get skillsNoSkills;

  /// No description provided for @skillsCollapse.
  ///
  /// In ko, this message translates to:
  /// **'접기'**
  String get skillsCollapse;

  /// No description provided for @skillsExpand.
  ///
  /// In ko, this message translates to:
  /// **'더보기'**
  String get skillsExpand;

  /// No description provided for @toolsTitle.
  ///
  /// In ko, this message translates to:
  /// **'도구'**
  String get toolsTitle;

  /// No description provided for @toolsDesc.
  ///
  /// In ko, this message translates to:
  /// **'에이전트가 작업할 때 꺼내 쓰는 도구들이에요.'**
  String get toolsDesc;

  /// No description provided for @toolsNoTools.
  ///
  /// In ko, this message translates to:
  /// **'등록된 도구가 없습니다.'**
  String get toolsNoTools;

  /// No description provided for @toolsCollapse.
  ///
  /// In ko, this message translates to:
  /// **'접기'**
  String get toolsCollapse;

  /// No description provided for @toolsExpand.
  ///
  /// In ko, this message translates to:
  /// **'더보기'**
  String get toolsExpand;

  /// No description provided for @tokenTotalUsage.
  ///
  /// In ko, this message translates to:
  /// **'전체 사용량'**
  String get tokenTotalUsage;

  /// No description provided for @tokenByModel.
  ///
  /// In ko, this message translates to:
  /// **'모델별 사용량'**
  String get tokenByModel;

  /// No description provided for @tokenDailyTrend.
  ///
  /// In ko, this message translates to:
  /// **'일별 사용 추이'**
  String get tokenDailyTrend;

  /// No description provided for @tokenTotal.
  ///
  /// In ko, this message translates to:
  /// **'총 사용 토큰'**
  String get tokenTotal;

  /// No description provided for @tokenRefresh.
  ///
  /// In ko, this message translates to:
  /// **'새로고침'**
  String get tokenRefresh;

  /// No description provided for @tokenNoUsage.
  ///
  /// In ko, this message translates to:
  /// **'아직 토큰 사용 기록이 없습니다'**
  String get tokenNoUsage;

  /// No description provided for @tokenNoUsageDesc.
  ///
  /// In ko, this message translates to:
  /// **'아바타와 대화를 나누면\n사용량이 여기에 표시됩니다.'**
  String get tokenNoUsageDesc;

  /// No description provided for @scheduleTitle.
  ///
  /// In ko, this message translates to:
  /// **'{name}의 스케줄'**
  String scheduleTitle(String name);

  /// No description provided for @scheduleDesc.
  ///
  /// In ko, this message translates to:
  /// **'에이전트가 정해진 시간에 알아서 처리하는 일들이에요.'**
  String get scheduleDesc;

  /// No description provided for @scheduleDayView.
  ///
  /// In ko, this message translates to:
  /// **'하루보기'**
  String get scheduleDayView;

  /// No description provided for @scheduleWeekView.
  ///
  /// In ko, this message translates to:
  /// **'주간보기'**
  String get scheduleWeekView;

  /// No description provided for @scheduleEmpty.
  ///
  /// In ko, this message translates to:
  /// **'등록된 스케줄이 없습니다\n채팅에서 \"매일 9시에 뉴스 요약해줘\" 라고 말해보세요'**
  String get scheduleEmpty;

  /// No description provided for @scheduleRoutineCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}개의 루틴'**
  String scheduleRoutineCount(int count);

  /// No description provided for @scheduleThisWeek.
  ///
  /// In ko, this message translates to:
  /// **'이번주'**
  String get scheduleThisWeek;

  /// No description provided for @scheduleWeekOrdinal1.
  ///
  /// In ko, this message translates to:
  /// **'첫째'**
  String get scheduleWeekOrdinal1;

  /// No description provided for @scheduleWeekOrdinal2.
  ///
  /// In ko, this message translates to:
  /// **'둘째'**
  String get scheduleWeekOrdinal2;

  /// No description provided for @scheduleWeekOrdinal3.
  ///
  /// In ko, this message translates to:
  /// **'셋째'**
  String get scheduleWeekOrdinal3;

  /// No description provided for @scheduleWeekOrdinal4.
  ///
  /// In ko, this message translates to:
  /// **'넷째'**
  String get scheduleWeekOrdinal4;

  /// No description provided for @scheduleWeekOrdinal5.
  ///
  /// In ko, this message translates to:
  /// **'다섯째'**
  String get scheduleWeekOrdinal5;

  /// No description provided for @scheduleMonthWeek.
  ///
  /// In ko, this message translates to:
  /// **'{month}월 {ordinal} 주'**
  String scheduleMonthWeek(int month, String ordinal);

  /// No description provided for @scheduleDateRangeSameMonth.
  ///
  /// In ko, this message translates to:
  /// **'{month}월 {startDay}일 - {endDay}일'**
  String scheduleDateRangeSameMonth(int month, int startDay, int endDay);

  /// No description provided for @scheduleDateRangeDiffMonth.
  ///
  /// In ko, this message translates to:
  /// **'{startMonth}월 {startDay}일 - {endMonth}월 {endDay}일'**
  String scheduleDateRangeDiffMonth(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  );

  /// No description provided for @scheduleRoutineDetail.
  ///
  /// In ko, this message translates to:
  /// **'루틴 상세'**
  String get scheduleRoutineDetail;

  /// No description provided for @scheduleLastRun.
  ///
  /// In ko, this message translates to:
  /// **'마지막 실행: {time}'**
  String scheduleLastRun(String time);

  /// No description provided for @channelsTitle.
  ///
  /// In ko, this message translates to:
  /// **'채널'**
  String get channelsTitle;

  /// No description provided for @channelsDesc.
  ///
  /// In ko, this message translates to:
  /// **'에이전트가 외부와 소통하는 메시지 채널이에요.'**
  String get channelsDesc;

  /// No description provided for @channelsTest.
  ///
  /// In ko, this message translates to:
  /// **'테스트'**
  String get channelsTest;

  /// No description provided for @channelsSaved.
  ///
  /// In ko, this message translates to:
  /// **'저장됨'**
  String get channelsSaved;

  /// No description provided for @channelsSaveSuccess.
  ///
  /// In ko, this message translates to:
  /// **'저장되었습니다.'**
  String get channelsSaveSuccess;

  /// No description provided for @channelsSaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'저장 실패'**
  String get channelsSaveFailed;

  /// No description provided for @channelsConnecting.
  ///
  /// In ko, this message translates to:
  /// **'● 연결 중'**
  String get channelsConnecting;

  /// No description provided for @channelsStarting.
  ///
  /// In ko, this message translates to:
  /// **'● 시작 중...'**
  String get channelsStarting;

  /// No description provided for @channelsReady.
  ///
  /// In ko, this message translates to:
  /// **'연결 준비됨'**
  String get channelsReady;

  /// No description provided for @channelsSetupNeeded.
  ///
  /// In ko, this message translates to:
  /// **'설정 필요'**
  String get channelsSetupNeeded;

  /// No description provided for @channelsTokenInvalid.
  ///
  /// In ko, this message translates to:
  /// **'토큰 형식이 올바르지 않습니다. (예: 123456:ABCdef)'**
  String get channelsTokenInvalid;

  /// No description provided for @channelsTokenRequired.
  ///
  /// In ko, this message translates to:
  /// **'Bot Token을 먼저 입력하세요.'**
  String get channelsTokenRequired;

  /// No description provided for @channelsTokenSaveFirst.
  ///
  /// In ko, this message translates to:
  /// **'Bot Token을 먼저 저장하세요.'**
  String get channelsTokenSaveFirst;

  /// No description provided for @channelsConnectionSuccess.
  ///
  /// In ko, this message translates to:
  /// **'@{botName} 연결 성공'**
  String channelsConnectionSuccess(String botName);

  /// No description provided for @channelsConnectionFailed.
  ///
  /// In ko, this message translates to:
  /// **'연결 실패'**
  String get channelsConnectionFailed;

  /// No description provided for @channelsMaskedTokenHint.
  ///
  /// In ko, this message translates to:
  /// **'{masked}  •  변경하려면 아래에 새 토큰을 입력하세요.'**
  String channelsMaskedTokenHint(String masked);

  /// No description provided for @channelsNewTokenHint.
  ///
  /// In ko, this message translates to:
  /// **'새 토큰 입력 (변경 시)'**
  String get channelsNewTokenHint;

  /// No description provided for @channelsErrorOccurred.
  ///
  /// In ko, this message translates to:
  /// **'오류가 발생했습니다.'**
  String get channelsErrorOccurred;

  /// No description provided for @placeConnected.
  ///
  /// In ko, this message translates to:
  /// **'연결됨'**
  String get placeConnected;

  /// No description provided for @placeAppTooltipConnected.
  ///
  /// In ko, this message translates to:
  /// **'{title} (연결됨)'**
  String placeAppTooltipConnected(String title);

  /// No description provided for @profileSystemPromptHint.
  ///
  /// In ko, this message translates to:
  /// **'LLM에게 부여할 역할이나 말투 등을 입력하세요. (예: 친절하고 다정한 어조로 답변해줘)'**
  String get profileSystemPromptHint;

  /// No description provided for @profileDescription.
  ///
  /// In ko, this message translates to:
  /// **'이곳에서 프로필 사진과 이름을 변경하면 채팅창 위젯에도 즉시 반영됩니다.\nPersona는 이 에이전트의 AI 성격 및 역할 정의에 사용됩니다.'**
  String get profileDescription;

  /// No description provided for @serverPortSaved.
  ///
  /// In ko, this message translates to:
  /// **'✅ 포트 저장 완료. (변경 시 에이전트 재시작 필요)'**
  String get serverPortSaved;

  /// No description provided for @serverPortSaveFailedNoResponse.
  ///
  /// In ko, this message translates to:
  /// **'❌ 저장 실패 (에이전트 응답하지 않음)'**
  String get serverPortSaveFailedNoResponse;

  /// No description provided for @serverPortSaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'❌ 저장 실패'**
  String get serverPortSaveFailed;

  /// No description provided for @serverLogEmpty.
  ///
  /// In ko, this message translates to:
  /// **'아직 로그가 없습니다.'**
  String get serverLogEmpty;

  /// No description provided for @serverPortChange.
  ///
  /// In ko, this message translates to:
  /// **'변경'**
  String get serverPortChange;

  /// No description provided for @serverLogAlreadyRunning.
  ///
  /// In ko, this message translates to:
  /// **'⚠️ 에이전트가 이미 실행 중'**
  String get serverLogAlreadyRunning;

  /// No description provided for @serverLogProcessExited.
  ///
  /// In ko, this message translates to:
  /// **'프로세스 종료 (코드: {code})'**
  String serverLogProcessExited(String code);

  /// No description provided for @serverLogRestarting.
  ///
  /// In ko, this message translates to:
  /// **'🔄 재시작...'**
  String get serverLogRestarting;

  /// No description provided for @agentStopped.
  ///
  /// In ko, this message translates to:
  /// **'에이전트가 정지되었습니다'**
  String get agentStopped;

  /// No description provided for @agentStoppedDesc.
  ///
  /// In ko, this message translates to:
  /// **'채팅을 시작하려면 위쪽의 전원 버튼을\n눌러 에이전트를 실행해주세요.'**
  String get agentStoppedDesc;

  /// No description provided for @serverConnectionRequired.
  ///
  /// In ko, this message translates to:
  /// **'에이전트 연결이 필요합니다'**
  String get serverConnectionRequired;

  /// No description provided for @serverConnectionRequiredDesc.
  ///
  /// In ko, this message translates to:
  /// **'설정 > Agent 에서 에이전트를 먼저 실행해주세요.'**
  String get serverConnectionRequiredDesc;

  /// No description provided for @modelSetupRequired.
  ///
  /// In ko, this message translates to:
  /// **'모델 설정이 필요합니다'**
  String get modelSetupRequired;

  /// No description provided for @goToSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정으로 이동'**
  String get goToSettings;

  /// No description provided for @currentAgent.
  ///
  /// In ko, this message translates to:
  /// **'현재 에이전트'**
  String get currentAgent;

  /// No description provided for @pmAgentSection.
  ///
  /// In ko, this message translates to:
  /// **'PM Agent'**
  String get pmAgentSection;

  /// No description provided for @domainAgentSection.
  ///
  /// In ko, this message translates to:
  /// **'Domain Agent'**
  String get domainAgentSection;

  /// No description provided for @addDomainAgent.
  ///
  /// In ko, this message translates to:
  /// **'에이전트 추가하기'**
  String get addDomainAgent;

  /// No description provided for @newAvatar.
  ///
  /// In ko, this message translates to:
  /// **'새로운 아바타'**
  String get newAvatar;

  /// No description provided for @defaultAvatarName.
  ///
  /// In ko, this message translates to:
  /// **'아리'**
  String get defaultAvatarName;

  /// No description provided for @dayNameSun.
  ///
  /// In ko, this message translates to:
  /// **'일'**
  String get dayNameSun;

  /// No description provided for @dayNameMon.
  ///
  /// In ko, this message translates to:
  /// **'월'**
  String get dayNameMon;

  /// No description provided for @dayNameTue.
  ///
  /// In ko, this message translates to:
  /// **'화'**
  String get dayNameTue;

  /// No description provided for @dayNameWed.
  ///
  /// In ko, this message translates to:
  /// **'수'**
  String get dayNameWed;

  /// No description provided for @dayNameThu.
  ///
  /// In ko, this message translates to:
  /// **'목'**
  String get dayNameThu;

  /// No description provided for @dayNameFri.
  ///
  /// In ko, this message translates to:
  /// **'금'**
  String get dayNameFri;

  /// No description provided for @dayNameSat.
  ///
  /// In ko, this message translates to:
  /// **'토'**
  String get dayNameSat;

  /// No description provided for @scheduleToday.
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get scheduleToday;

  /// No description provided for @scheduleTomorrow.
  ///
  /// In ko, this message translates to:
  /// **'내일'**
  String get scheduleTomorrow;

  /// No description provided for @scheduleMonthDay.
  ///
  /// In ko, this message translates to:
  /// **'{month}월 {day}일'**
  String scheduleMonthDay(int month, int day);

  /// No description provided for @scheduleTapForToday.
  ///
  /// In ko, this message translates to:
  /// **'(탭하면 오늘)'**
  String get scheduleTapForToday;

  /// No description provided for @scheduleTask.
  ///
  /// In ko, this message translates to:
  /// **'작업'**
  String get scheduleTask;

  /// No description provided for @schedulePrompt.
  ///
  /// In ko, this message translates to:
  /// **'프롬프트:'**
  String get schedulePrompt;

  /// No description provided for @scheduleLastResult.
  ///
  /// In ko, this message translates to:
  /// **'마지막 결과 ({time}):'**
  String scheduleLastResult(String time);

  /// No description provided for @settingsServerDesc.
  ///
  /// In ko, this message translates to:
  /// **'로컬 에이전트 상태 확인 및 제어'**
  String get settingsServerDesc;

  /// No description provided for @settingsAppearanceDesc.
  ///
  /// In ko, this message translates to:
  /// **'화면 스타일 및 윈도우 핀 설정'**
  String get settingsAppearanceDesc;

  /// No description provided for @settingsNotificationDesc.
  ///
  /// In ko, this message translates to:
  /// **'데몬 상태에서 수신하는 OS 레벨 알림 설정'**
  String get settingsNotificationDesc;

  /// No description provided for @settingsExperimentalDesc.
  ///
  /// In ko, this message translates to:
  /// **'고급 도구 및 실험적인 기능을 설정하는 메뉴'**
  String get settingsExperimentalDesc;

  /// No description provided for @settingsExperimentalDescDisabled.
  ///
  /// In ko, this message translates to:
  /// **'고급 도구 및 실험적인 기능을 설정하는 메뉴 (에이전트 실행 필요)'**
  String get settingsExperimentalDescDisabled;

  /// No description provided for @settingsTokenDesc.
  ///
  /// In ko, this message translates to:
  /// **'이 아바타의 AI 모델 토큰 사용량을 확인하고 한도를 설정합니다.'**
  String get settingsTokenDesc;

  /// No description provided for @settingsResetMemoryDesc.
  ///
  /// In ko, this message translates to:
  /// **'이 아바타가 학습하고 기억한 벡터 데이터를 초기화합니다.\n장기 기억이 삭제되지만 페르소나는 유지됩니다.'**
  String get settingsResetMemoryDesc;

  /// No description provided for @settingsResetMemoryConfirm.
  ///
  /// In ko, this message translates to:
  /// **'정말로 이 아바타의 모든 기억을 초기화하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'**
  String get settingsResetMemoryConfirm;

  /// No description provided for @settingsResetConversationDesc.
  ///
  /// In ko, this message translates to:
  /// **'이 아바타와 나눈 모든 채팅 로그를 삭제합니다.\n기록 탭의 내용이 모두 비워집니다.'**
  String get settingsResetConversationDesc;

  /// No description provided for @settingsResetConversationConfirm.
  ///
  /// In ko, this message translates to:
  /// **'현재 아바타와의 모든 대화 내용을 삭제하시겠습니까?'**
  String get settingsResetConversationConfirm;

  /// No description provided for @settingsDeleteAvatarDesc.
  ///
  /// In ko, this message translates to:
  /// **'이 아바타의 모든 데이터(프로필, 로그, 설정)를 영구히 삭제합니다.\n기본 아바타(ARI)는 삭제할 수 없습니다.'**
  String get settingsDeleteAvatarDesc;

  /// No description provided for @settingsDeleteAvatarConfirm.
  ///
  /// In ko, this message translates to:
  /// **'정말로 \"{name}\" 아바타를 영구 삭제하시겠습니까?\n모든 관련 데이터가 즉시 삭제됩니다.'**
  String settingsDeleteAvatarConfirm(String name);

  /// No description provided for @settingsOpenFolderDesc.
  ///
  /// In ko, this message translates to:
  /// **'모든 아바타 정보와 로그가 저장된 .ari-agent 폴더를 탐색기에서 엽니다.'**
  String get settingsOpenFolderDesc;

  /// No description provided for @notificationDaemonTitle.
  ///
  /// In ko, this message translates to:
  /// **'데몬 상태 메시지 알림'**
  String get notificationDaemonTitle;

  /// No description provided for @notificationDaemonDesc.
  ///
  /// In ko, this message translates to:
  /// **'창이 숨겨진 상태에서 새 응답이 오면 macOS/Windows 알림을 표시합니다.'**
  String get notificationDaemonDesc;

  /// No description provided for @notificationAutoTaskTitle.
  ///
  /// In ko, this message translates to:
  /// **'자동 작업 결과 채팅창 표시'**
  String get notificationAutoTaskTitle;

  /// No description provided for @notificationAutoTaskDesc.
  ///
  /// In ko, this message translates to:
  /// **'자동 작업이 완료되면 결과를 채팅창에 표시합니다.'**
  String get notificationAutoTaskDesc;

  /// No description provided for @experimentalShowAdvancedTools.
  ///
  /// In ko, this message translates to:
  /// **'고급 도구 표시'**
  String get experimentalShowAdvancedTools;

  /// No description provided for @experimentalShowAdvancedToolsDesc.
  ///
  /// In ko, this message translates to:
  /// **'스킬, 도구 탭 등 개발자용 고급 기능을 표시합니다.'**
  String get experimentalShowAdvancedToolsDesc;

  /// No description provided for @experimentalEnableExperimental.
  ///
  /// In ko, this message translates to:
  /// **'실험기능 활성화'**
  String get experimentalEnableExperimental;

  /// No description provided for @experimentalEnableExperimentalDesc.
  ///
  /// In ko, this message translates to:
  /// **'정식 배포 전에 테스트 중인 기능을 미리 표시합니다.'**
  String get experimentalEnableExperimentalDesc;

  /// No description provided for @experimentalAdvancedIntelligence.
  ///
  /// In ko, this message translates to:
  /// **'고급 관계 지능 활성화'**
  String get experimentalAdvancedIntelligence;

  /// No description provided for @experimentalAdvancedIntelligenceDesc.
  ///
  /// In ko, this message translates to:
  /// **'의미론적 벡터 기억 및 관계 그래프를 활성화합니다. (아바타 > 메모리 탭에서 확인 가능)'**
  String get experimentalAdvancedIntelligenceDesc;

  /// No description provided for @experimentalModelReady.
  ///
  /// In ko, this message translates to:
  /// **'임베딩 모델 준비 완료'**
  String get experimentalModelReady;

  /// No description provided for @experimentalModelLoading.
  ///
  /// In ko, this message translates to:
  /// **'임베딩 모델 로드 중...'**
  String get experimentalModelLoading;

  /// No description provided for @experimentalModelDownloading.
  ///
  /// In ko, this message translates to:
  /// **'임베딩 모델 다운로드 중... (~280MB)'**
  String get experimentalModelDownloading;

  /// No description provided for @experimentalModelFailed.
  ///
  /// In ko, this message translates to:
  /// **'모델 로드 실패 — 재시작 후 다시 시도'**
  String get experimentalModelFailed;

  /// No description provided for @experimentalModelNotInstalled.
  ///
  /// In ko, this message translates to:
  /// **'모델 미설치 — 활성화 시 자동 다운로드 (~280MB)'**
  String get experimentalModelNotInstalled;

  /// No description provided for @advMemoryStatsFailed.
  ///
  /// In ko, this message translates to:
  /// **'통계를 불러올 수 없습니다.'**
  String get advMemoryStatsFailed;

  /// No description provided for @advMemoryGraphDesc.
  ///
  /// In ko, this message translates to:
  /// **'에이전트 메모리의 관계 그래프 현황입니다.'**
  String get advMemoryGraphDesc;

  /// No description provided for @advMemoryNodeTitle.
  ///
  /// In ko, this message translates to:
  /// **'메모리 노드'**
  String get advMemoryNodeTitle;

  /// No description provided for @advMemoryCoreLabel.
  ///
  /// In ko, this message translates to:
  /// **'핵심 기억 (Core)'**
  String get advMemoryCoreLabel;

  /// No description provided for @advMemoryDailyLabel.
  ///
  /// In ko, this message translates to:
  /// **'일일 로그 (Daily)'**
  String get advMemoryDailyLabel;

  /// No description provided for @advMemoryTotal.
  ///
  /// In ko, this message translates to:
  /// **'합계'**
  String get advMemoryTotal;

  /// No description provided for @advMemoryEntityTitle.
  ///
  /// In ko, this message translates to:
  /// **'엔티티'**
  String get advMemoryEntityTitle;

  /// No description provided for @advMemoryEntitySubtitle.
  ///
  /// In ko, this message translates to:
  /// **'사람, 도구, 개념...'**
  String get advMemoryEntitySubtitle;

  /// No description provided for @advMemoryTopicTitle.
  ///
  /// In ko, this message translates to:
  /// **'토픽'**
  String get advMemoryTopicTitle;

  /// No description provided for @advMemoryTopicSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'주제 카테고리'**
  String get advMemoryTopicSubtitle;

  /// No description provided for @advMemoryRelTitle.
  ///
  /// In ko, this message translates to:
  /// **'관계 (Relationships)'**
  String get advMemoryRelTitle;

  /// No description provided for @advMemoryRelMentions.
  ///
  /// In ko, this message translates to:
  /// **'MENTIONS (기억 → 엔티티)'**
  String get advMemoryRelMentions;

  /// No description provided for @advMemoryRelAbout.
  ///
  /// In ko, this message translates to:
  /// **'ABOUT (기억 → 토픽)'**
  String get advMemoryRelAbout;

  /// No description provided for @advMemoryRelFollows.
  ///
  /// In ko, this message translates to:
  /// **'FOLLOWS (시간 순서 체인)'**
  String get advMemoryRelFollows;

  /// No description provided for @advMemoryRelTotal.
  ///
  /// In ko, this message translates to:
  /// **'총 관계 수'**
  String get advMemoryRelTotal;

  /// No description provided for @aboutSlogan.
  ///
  /// In ko, this message translates to:
  /// **'함께 일하고, 함께 쉬는 AI'**
  String get aboutSlogan;

  /// No description provided for @aboutDescription.
  ///
  /// In ko, this message translates to:
  /// **'기억과 실행을 바탕으로 함께하는 AI 동반자입니다. 질문에 답하는 데서 멈추지 않고, 사용자의 흐름 안에서 자연스럽게 이어지는 경험을 지향합니다.'**
  String get aboutDescription;

  /// No description provided for @aboutFeature1Title.
  ///
  /// In ko, this message translates to:
  /// **'기억하는 대화'**
  String get aboutFeature1Title;

  /// No description provided for @aboutFeature1Desc.
  ///
  /// In ko, this message translates to:
  /// **'이전 맥락을 바탕으로 더 자연스럽게 이어집니다.'**
  String get aboutFeature1Desc;

  /// No description provided for @aboutFeature2Title.
  ///
  /// In ko, this message translates to:
  /// **'실행으로 이어짐'**
  String get aboutFeature2Title;

  /// No description provided for @aboutFeature2Desc.
  ///
  /// In ko, this message translates to:
  /// **'말만 하지 않고 필요한 행동과 흐름으로 이어집니다.'**
  String get aboutFeature2Desc;

  /// No description provided for @aboutFeature3Title.
  ///
  /// In ko, this message translates to:
  /// **'앱과 함께 움직임'**
  String get aboutFeature3Title;

  /// No description provided for @aboutFeature3Desc.
  ///
  /// In ko, this message translates to:
  /// **'여러 앱을 오가며 하나의 경험처럼 연결합니다.'**
  String get aboutFeature3Desc;

  /// No description provided for @aboutFeature4Title.
  ///
  /// In ko, this message translates to:
  /// **'일과 놀이를 함께'**
  String get aboutFeature4Title;

  /// No description provided for @aboutFeature4Desc.
  ///
  /// In ko, this message translates to:
  /// **'집중하는 시간도 쉬는 시간도 같은 흐름 안에서 함께합니다.'**
  String get aboutFeature4Desc;

  /// No description provided for @aboutPhilosophy1Title.
  ///
  /// In ko, this message translates to:
  /// **'사용자의 공간 안에 머무르기'**
  String get aboutPhilosophy1Title;

  /// No description provided for @aboutPhilosophy1Desc.
  ///
  /// In ko, this message translates to:
  /// **'멀리 있는 서비스처럼 느껴지기보다, 내 자리에 함께 있는 존재처럼 작동합니다.'**
  String get aboutPhilosophy1Desc;

  /// No description provided for @aboutPhilosophy2Title.
  ///
  /// In ko, this message translates to:
  /// **'대화보다 실제 도움'**
  String get aboutPhilosophy2Title;

  /// No description provided for @aboutPhilosophy2Desc.
  ///
  /// In ko, this message translates to:
  /// **'좋은 말보다 다음 행동으로 이어지는 도움을 더 중요하게 생각합니다.'**
  String get aboutPhilosophy2Desc;

  /// No description provided for @aboutPhilosophy3Title.
  ///
  /// In ko, this message translates to:
  /// **'생산성만이 아닌 사용감'**
  String get aboutPhilosophy3Title;

  /// No description provided for @aboutPhilosophy3Desc.
  ///
  /// In ko, this message translates to:
  /// **'일할 때만 유용한 도구가 아니라, 쉬고 놀 때도 자연스럽게 곁에 두는 동반자를 지향합니다.'**
  String get aboutPhilosophy3Desc;

  /// No description provided for @aboutUsageTitle.
  ///
  /// In ko, this message translates to:
  /// **'이렇게 사용해보세요!'**
  String get aboutUsageTitle;

  /// No description provided for @aboutUsage1.
  ///
  /// In ko, this message translates to:
  /// **'\"오늘 할 일 같이 정리해줘\"'**
  String get aboutUsage1;

  /// No description provided for @aboutUsage1Cat.
  ///
  /// In ko, this message translates to:
  /// **'일상 정리'**
  String get aboutUsage1Cat;

  /// No description provided for @aboutUsage2.
  ///
  /// In ko, this message translates to:
  /// **'\"30분 뒤에 커피 마시라고 알려줘\"'**
  String get aboutUsage2;

  /// No description provided for @aboutUsage2Cat.
  ///
  /// In ko, this message translates to:
  /// **'리마인더'**
  String get aboutUsage2Cat;

  /// No description provided for @aboutUsage3.
  ///
  /// In ko, this message translates to:
  /// **'\"지금 하던 작업 맥락 이어서 도와줘\"'**
  String get aboutUsage3;

  /// No description provided for @aboutUsage3Cat.
  ///
  /// In ko, this message translates to:
  /// **'업무 흐름 이어가기'**
  String get aboutUsage3Cat;

  /// No description provided for @aboutUsage4.
  ///
  /// In ko, this message translates to:
  /// **'\"게임하기 전에 필요한 것들 같이 챙겨줘\"'**
  String get aboutUsage4;

  /// No description provided for @aboutUsage4Cat.
  ///
  /// In ko, this message translates to:
  /// **'놀이 준비'**
  String get aboutUsage4Cat;

  /// No description provided for @aboutUsage5.
  ///
  /// In ko, this message translates to:
  /// **'\"방금 우리 대화 내용 기억해?\"'**
  String get aboutUsage5;

  /// No description provided for @aboutUsage5Cat.
  ///
  /// In ko, this message translates to:
  /// **'개인화된 관계'**
  String get aboutUsage5Cat;

  /// No description provided for @helpOAuth.
  ///
  /// In ko, this message translates to:
  /// **'구독형 서비스를 이미 사용하고 있다면(ChatGPT 등) 별도의 키 발급 없이 편리하게 사용합니다.'**
  String get helpOAuth;

  /// No description provided for @helpApiKey.
  ///
  /// In ko, this message translates to:
  /// **'자신이 소유한 API 키를 직접 사용하여 가장 저렴하고 빠른 성능을 보장합니다.'**
  String get helpApiKey;

  /// No description provided for @helpPriority.
  ///
  /// In ko, this message translates to:
  /// **'상단에 위치한 프로바이더를 먼저 시도하며, 오류 발생 시 아래 순서로 자동 전환됩니다.'**
  String get helpPriority;

  /// No description provided for @helpKeyIssue.
  ///
  /// In ko, this message translates to:
  /// **'키 발급 주소:'**
  String get helpKeyIssue;

  /// No description provided for @addProvider.
  ///
  /// In ko, this message translates to:
  /// **'프로바이더 추가'**
  String get addProvider;

  /// No description provided for @updateAvailable.
  ///
  /// In ko, this message translates to:
  /// **'새 버전 {version} 사용 가능{mandatory}'**
  String updateAvailable(String version, String mandatory);

  /// No description provided for @updateMandatory.
  ///
  /// In ko, this message translates to:
  /// **' · 필수 업데이트'**
  String get updateMandatory;

  /// No description provided for @updateButton.
  ///
  /// In ko, this message translates to:
  /// **'업데이트'**
  String get updateButton;

  /// No description provided for @homeServerRequired.
  ///
  /// In ko, this message translates to:
  /// **'에이전트 연결 필요'**
  String get homeServerRequired;

  /// No description provided for @homeServerRequiredDesc.
  ///
  /// In ko, this message translates to:
  /// **'이 기능을 사용하려면 에이전트 실행이 필요합니다.\n설정 탭에서 에이전트를 켜 주세요.'**
  String get homeServerRequiredDesc;

  /// No description provided for @chatEmptyPrompt.
  ///
  /// In ko, this message translates to:
  /// **'💬 ARI에게 무엇이든 물어보세요!'**
  String get chatEmptyPrompt;

  /// No description provided for @chatFollowUpPending.
  ///
  /// In ko, this message translates to:
  /// **'대기 중'**
  String get chatFollowUpPending;

  /// No description provided for @chatFollowUpPendingCount.
  ///
  /// In ko, this message translates to:
  /// **'대기 {count}건'**
  String chatFollowUpPendingCount(Object count);

  /// No description provided for @modelSetupDesc.
  ///
  /// In ko, this message translates to:
  /// **'ARI가 답변하기 위해 사용할\nAI 프로바이더 및 API 키를 등록해주세요.'**
  String get modelSetupDesc;

  /// No description provided for @settingsModelDesc.
  ///
  /// In ko, this message translates to:
  /// **'AI 모델 및 API 키 설정'**
  String get settingsModelDesc;

  /// No description provided for @settingsModelDescDisabled.
  ///
  /// In ko, this message translates to:
  /// **'AI 모델 및 API 키 설정 (에이전트 실행 필요)'**
  String get settingsModelDescDisabled;

  /// No description provided for @settingsAboutDesc.
  ///
  /// In ko, this message translates to:
  /// **'ARI Agent 소개 및 버전 정보'**
  String get settingsAboutDesc;

  /// No description provided for @aboutPhilosophyHeading.
  ///
  /// In ko, this message translates to:
  /// **'ARI가 중요하게 생각하는 것'**
  String get aboutPhilosophyHeading;

  /// No description provided for @relativeSoon.
  ///
  /// In ko, this message translates to:
  /// **'곧'**
  String get relativeSoon;

  /// No description provided for @relativeInMinutes.
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분 후'**
  String relativeInMinutes(int minutes);

  /// No description provided for @relativeInHours.
  ///
  /// In ko, this message translates to:
  /// **'{hours}시간 후'**
  String relativeInHours(int hours);

  /// No description provided for @relativeInDays.
  ///
  /// In ko, this message translates to:
  /// **'{days}일 후'**
  String relativeInDays(int days);

  /// No description provided for @notificationTitleBackground.
  ///
  /// In ko, this message translates to:
  /// **'ARI 백그라운드 응답'**
  String get notificationTitleBackground;

  /// No description provided for @notificationTitleNewMessage.
  ///
  /// In ko, this message translates to:
  /// **'ARI 새 메시지'**
  String get notificationTitleNewMessage;

  /// No description provided for @helpGuideTitle.
  ///
  /// In ko, this message translates to:
  /// **'AI 프로바이더 설정 가이드'**
  String get helpGuideTitle;

  /// No description provided for @helpOAuthTitle.
  ///
  /// In ko, this message translates to:
  /// **'☁️ OAuth 서비스 연동 (추천)'**
  String get helpOAuthTitle;

  /// No description provided for @helpApiKeyTitle.
  ///
  /// In ko, this message translates to:
  /// **'🔑 API 키 직접 입력'**
  String get helpApiKeyTitle;

  /// No description provided for @helpPriorityTitle.
  ///
  /// In ko, this message translates to:
  /// **'🔝 우선순위 오버라이드'**
  String get helpPriorityTitle;

  /// No description provided for @chatSuggestion1.
  ///
  /// In ko, this message translates to:
  /// **'비트코인 거래앱 설치해줘!'**
  String get chatSuggestion1;

  /// No description provided for @chatSuggestion2.
  ///
  /// In ko, this message translates to:
  /// **'주식 자동매매 하고 싶어!'**
  String get chatSuggestion2;

  /// No description provided for @chatSuggestionSetupGreet.
  ///
  /// In ko, this message translates to:
  /// **'👋 안녕'**
  String get chatSuggestionSetupGreet;

  /// No description provided for @chatSuggestionSetupHowto.
  ///
  /// In ko, this message translates to:
  /// **'🛠️ 사용법을 알려줘'**
  String get chatSuggestionSetupHowto;

  /// No description provided for @chatSuggestionSetupApiKey.
  ///
  /// In ko, this message translates to:
  /// **'🔑 API 키가 뭐야?'**
  String get chatSuggestionSetupApiKey;

  /// No description provided for @chatSuggestionSetupCheapest.
  ///
  /// In ko, this message translates to:
  /// **'💳 어떤 방식이 제일 저렴해?'**
  String get chatSuggestionSetupCheapest;

  /// No description provided for @chatSuggestionSetupChatgpt.
  ///
  /// In ko, this message translates to:
  /// **'⭐ ChatGPT로 연결하고 싶어'**
  String get chatSuggestionSetupChatgpt;

  /// No description provided for @chatSuggestionSetupOauth.
  ///
  /// In ko, this message translates to:
  /// **'🔓 OAuth가 뭐야?'**
  String get chatSuggestionSetupOauth;

  /// No description provided for @chatSuggestionNormalGreet.
  ///
  /// In ko, this message translates to:
  /// **'👋 안녕 ARI!'**
  String get chatSuggestionNormalGreet;

  /// No description provided for @chatSuggestionNormalDisk.
  ///
  /// In ko, this message translates to:
  /// **'💾 디스크 용량 확인'**
  String get chatSuggestionNormalDisk;

  /// No description provided for @chatSuggestionNormalFile.
  ///
  /// In ko, this message translates to:
  /// **'🔍 파일 찾아줘'**
  String get chatSuggestionNormalFile;

  /// No description provided for @chatSuggestionNormalRemind.
  ///
  /// In ko, this message translates to:
  /// **'1분뒤 알려줘!'**
  String get chatSuggestionNormalRemind;

  /// No description provided for @chatSuggestionNormalMusic.
  ///
  /// In ko, this message translates to:
  /// **'🎵 감성적인 노래 들려줘!'**
  String get chatSuggestionNormalMusic;

  /// No description provided for @appearanceGray.
  ///
  /// In ko, this message translates to:
  /// **'그레이'**
  String get appearanceGray;

  /// No description provided for @appearanceDark.
  ///
  /// In ko, this message translates to:
  /// **'다크'**
  String get appearanceDark;

  /// No description provided for @appearanceBlue.
  ///
  /// In ko, this message translates to:
  /// **'블루'**
  String get appearanceBlue;

  /// No description provided for @appearancePurple.
  ///
  /// In ko, this message translates to:
  /// **'퍼플'**
  String get appearancePurple;

  /// No description provided for @appearanceBgTheme.
  ///
  /// In ko, this message translates to:
  /// **'배경 테마'**
  String get appearanceBgTheme;

  /// No description provided for @appearanceLarge.
  ///
  /// In ko, this message translates to:
  /// **'크게'**
  String get appearanceLarge;

  /// No description provided for @appearanceLanguage.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get appearanceLanguage;

  /// No description provided for @appearanceSpaceUsage.
  ///
  /// In ko, this message translates to:
  /// **'공간 사용'**
  String get appearanceSpaceUsage;

  /// No description provided for @appearanceUnifySpace.
  ///
  /// In ko, this message translates to:
  /// **'플레이스와 리스트 통합'**
  String get appearanceUnifySpace;

  /// No description provided for @appearanceUnifySpaceDesc.
  ///
  /// In ko, this message translates to:
  /// **'활성화하면 플레이스 탭에 공간 화면이 표시됩니다. 끄면 에이전트 목록이 표시됩니다.'**
  String get appearanceUnifySpaceDesc;

  /// No description provided for @placeWorking.
  ///
  /// In ko, this message translates to:
  /// **'작업중'**
  String get placeWorking;

  /// No description provided for @placeIdle.
  ///
  /// In ko, this message translates to:
  /// **'대기중'**
  String get placeIdle;

  /// No description provided for @placeResting.
  ///
  /// In ko, this message translates to:
  /// **'쉬는중'**
  String get placeResting;

  /// No description provided for @skillsCheckFolder.
  ///
  /// In ko, this message translates to:
  /// **'에이전트의 skills 폴더를 확인해주세요.'**
  String get skillsCheckFolder;

  /// No description provided for @toolsCheckFolder.
  ///
  /// In ko, this message translates to:
  /// **'에이전트의 tools 폴더를 확인해주세요.'**
  String get toolsCheckFolder;

  /// No description provided for @refresh.
  ///
  /// In ko, this message translates to:
  /// **'새로고침'**
  String get refresh;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'ko':
      return SKo();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
