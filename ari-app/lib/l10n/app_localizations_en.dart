// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ARI Agent';

  @override
  String get tabChat => 'Chat';

  @override
  String get tabPlace => 'Place';

  @override
  String get tabAvatar => 'Avatar';

  @override
  String get tabSettings => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get confirm => 'OK';

  @override
  String get delete => 'Delete';

  @override
  String get minimize => 'Minimize';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get copy => 'Copy';

  @override
  String get edit => 'Edit';

  @override
  String get done => 'Done';

  @override
  String get reset => 'Reset';

  @override
  String get apply => 'Apply';

  @override
  String get back => 'Back';

  @override
  String get trayOpen => 'Open ARI';

  @override
  String get trayHide => 'Hide ARI';

  @override
  String get trayQuit => 'Quit';

  @override
  String get chatHint => 'Ask ARI...';

  @override
  String get messageCopied => 'Message copied.';

  @override
  String get settingsDataManagement => 'Data Management';

  @override
  String get settingsDataManagementDesc =>
      'Manage agent memory, conversation history, and tokens.';

  @override
  String get settingsTokenManagement => 'Token Management';

  @override
  String get settingsResetMemory => 'Reset Memory';

  @override
  String get settingsResetConversation => 'Reset Conversation';

  @override
  String get settingsDangerZone => 'Danger Zone';

  @override
  String get settingsDangerZoneDesc =>
      'These actions cannot be undone. Please proceed with caution.';

  @override
  String get settingsDeleteAvatar => 'Delete Avatar';

  @override
  String get settingsOpenFolder => 'Open Settings Folder';

  @override
  String get settingsShowAdvancedTools => 'Show Advanced Tools';

  @override
  String get settingsEnableExperimental => 'Enable Experimental Features';

  @override
  String get settingsPinToDesktop => 'Pin to Desktop (Always on Top)';

  @override
  String get settingsPinToDesktopDesc =>
      'Keep the ARI window always above other windows.';

  @override
  String get settingsAvatarSize => 'Avatar Size';

  @override
  String get settingsAvatarSizeSmall => 'Small';

  @override
  String get settingsAvatarSizeMedium => 'Medium';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsHomeDirNotFound => 'Could not find home directory.';

  @override
  String settingsActionCompleted(String title) {
    return '$title completed.';
  }

  @override
  String get serverAddress => 'Server Address (URL)';

  @override
  String get longLivedAccessToken => 'Long-lived Access Token';

  @override
  String get errorAppNotFound => 'App not found';

  @override
  String get errorAppNotFoundMessage =>
      '\"ARIAgent\" app could not be found.\nPlease close the app manually and restart.';

  @override
  String get errorIntegrationFailed => 'Integration Failed';

  @override
  String get errorUnknown => 'An unknown error occurred.';

  @override
  String get errorLoadMemoryFailed => 'Failed to load memory';

  @override
  String errorLoadMemoryFailedWith(String error) {
    return 'Failed to load memory: $error';
  }

  @override
  String errorSaveFailedWith(String error) {
    return 'Save failed: $error';
  }

  @override
  String get errorRestartApp => 'Please close the app manually and restart.';

  @override
  String get errorLoadData => 'Could not load data';

  @override
  String get errorLoadTools => 'Failed to load tool information.';

  @override
  String get errorLoadSkills => 'Failed to load skill information.';

  @override
  String get memoryLongTermUpdated => 'Long-term memory updated.';

  @override
  String get memoryLongTermHint => 'Enter long-term memory...';

  @override
  String get memoryNoLongTerm => 'No long-term memory saved yet.';

  @override
  String get memoryNoDailyLog => 'No recent daily logs found.';

  @override
  String get memoryCoreTitle => 'Core Memory';

  @override
  String get memoryCoreDesc =>
      'Core values and things the agent should remember long-term.';

  @override
  String get memoryDailyTitle => 'Recent Daily Logs';

  @override
  String get memoryDailyDesc =>
      'A record of what the agent has been doing recently.';

  @override
  String get logCopied => 'Log copied.';

  @override
  String get logEmpty => 'No logs to copy.';

  @override
  String get logRealtime => 'Realtime Agent Log';

  @override
  String get skillDelete => 'Delete Skill';

  @override
  String skillDeleteConfirm(String name) {
    return 'Are you sure you want to delete the skill \"$name\"?';
  }

  @override
  String get chatClearTitle => 'Clear Conversation';

  @override
  String get chatClearMessage =>
      'Are you sure you want to clear all conversation history with the current avatar?\nThis action cannot be undone.';

  @override
  String get chatClearButton => 'Clear';

  @override
  String get chatTooltipExpand => 'Expand';

  @override
  String get chatTooltipCollapse => 'Collapse';

  @override
  String get chatTooltipClearHistory => 'Clear chat history';

  @override
  String get modelProvidersPriority => 'AI Providers (by priority)';

  @override
  String get modelSaving => 'Saving...';

  @override
  String get modelSaved => 'Saved';

  @override
  String get modelSaveFailed => 'Save failed';

  @override
  String get modelUnsaved => 'Not saved';

  @override
  String get modelApiKeyHint => 'Enter API Key (sk-...)';

  @override
  String get oauthLoginComplete => '✅ Login complete';

  @override
  String get oauthBrowserAuth => '🌐 Complete authentication in your browser';

  @override
  String get oauthCodeRequired => '✏️ Code input required';

  @override
  String get oauthInProgress => 'In progress...';

  @override
  String oauthError(String message) {
    return '❌ $message';
  }

  @override
  String get oauthStarting => 'Starting login...';

  @override
  String get oauthLoggedIn => '✅ Logged in (OAuth)';

  @override
  String get oauthLoginRequired => 'OAuth login required';

  @override
  String get oauthLoginButton => 'OAuth Login';

  @override
  String get oauthLoggedInButton => 'Logged in';

  @override
  String get oauthLogout => 'Logout';

  @override
  String get oauthCodeInput => 'Enter Code';

  @override
  String get oauthCodeHint => 'Enter code';

  @override
  String get oauthBrowserAuthTitle => 'Browser Authentication';

  @override
  String get oauthErrorDefault => 'Error occurred';

  @override
  String get oauthBrowserAutoProgress =>
      'Authentication will proceed automatically once completed in the browser.';

  @override
  String get oauthOpenBrowser => 'Open Browser';

  @override
  String get haConnectBrain => 'Connect to your smart home\'s brain';

  @override
  String get haEditConnection => 'Edit server connection settings';

  @override
  String get haServerUrlHelper => 'Enter local IP or external access domain.';

  @override
  String get haTokenHint => 'Token string starting with eyJ...';

  @override
  String get haTokenHelper =>
      'Enter the token created at the bottom of your HA profile.';

  @override
  String get haSaveChanges => 'Save Changes';

  @override
  String get haStartIntegration => 'Start Home Assistant Integration';

  @override
  String get haNoHaYet => 'Don\'t have Home Assistant yet?';

  @override
  String get haOfficialSite => 'Official Site';

  @override
  String get haInstallGuide => 'View install guide';

  @override
  String get haAskAri => 'Ask ARI';

  @override
  String get haAskAriDesc => 'Get help with installation';

  @override
  String get haAskAriChat => 'Go to Chat and ask \"Help me install HA\"!';

  @override
  String get haConnected => 'Connected';

  @override
  String get haIntegrationSuccess =>
      '✅ Successfully connected to Home Assistant server.';

  @override
  String get appsTitle => 'Apps';

  @override
  String get appsDesc => 'Apps that your agent integrates with.';

  @override
  String get appsStore => 'App Store';

  @override
  String get appsNoApps => 'No apps installed.';

  @override
  String get appsCheckFolder => 'Check the ~/.ari-agent/apps folder.';

  @override
  String get appsConnected => 'Connected';

  @override
  String get appsOffline => 'Offline';

  @override
  String appsDeleteConfirm(String title) {
    return 'Are you sure you want to delete the app \"$title\"?';
  }

  @override
  String get appsDeleteTitle => 'Delete App';

  @override
  String get skillsTitle => 'Skills';

  @override
  String get skillsDesc => 'Abilities your agent can perform.';

  @override
  String get skillsNoSkills => 'No skills registered.';

  @override
  String get skillsCollapse => 'Collapse';

  @override
  String get skillsExpand => 'Show more';

  @override
  String get toolsTitle => 'Tools';

  @override
  String get toolsDesc => 'Tools your agent uses to get things done.';

  @override
  String get toolsNoTools => 'No tools registered.';

  @override
  String get toolsCollapse => 'Collapse';

  @override
  String get toolsExpand => 'Show more';

  @override
  String get tokenTotalUsage => 'Total Usage';

  @override
  String get tokenByModel => 'Usage by Model';

  @override
  String get tokenDailyTrend => 'Daily Usage Trend';

  @override
  String get tokenTotal => 'Total Tokens Used';

  @override
  String get tokenRefresh => 'Refresh';

  @override
  String get tokenNoUsage => 'No token usage yet';

  @override
  String get tokenNoUsageDesc =>
      'Usage will appear here\nonce you start chatting with your avatar.';

  @override
  String scheduleTitle(String name) {
    return '$name\'s Schedule';
  }

  @override
  String get scheduleDesc =>
      'Tasks your agent handles automatically at scheduled times.';

  @override
  String get scheduleDayView => 'Day';

  @override
  String get scheduleWeekView => 'Week';

  @override
  String get scheduleEmpty =>
      'No schedules registered.\nTry saying \"Summarize news every day at 9am\" in chat.';

  @override
  String scheduleRoutineCount(int count) {
    return '$count routines';
  }

  @override
  String get scheduleThisWeek => 'This week';

  @override
  String get scheduleWeekOrdinal1 => '1st';

  @override
  String get scheduleWeekOrdinal2 => '2nd';

  @override
  String get scheduleWeekOrdinal3 => '3rd';

  @override
  String get scheduleWeekOrdinal4 => '4th';

  @override
  String get scheduleWeekOrdinal5 => '5th';

  @override
  String scheduleMonthWeek(int month, String ordinal) {
    return 'Week $ordinal of month $month';
  }

  @override
  String scheduleDateRangeSameMonth(int month, int startDay, int endDay) {
    return '$month/$startDay - $endDay';
  }

  @override
  String scheduleDateRangeDiffMonth(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth/$startDay - $endMonth/$endDay';
  }

  @override
  String get scheduleRoutineDetail => 'Routine Details';

  @override
  String scheduleLastRun(String time) {
    return 'Last run: $time';
  }

  @override
  String get channelsTitle => 'Channels';

  @override
  String get channelsDesc =>
      'Message channels for your agent to communicate externally.';

  @override
  String get channelsTest => 'Test';

  @override
  String get channelsSaved => 'Saved';

  @override
  String get channelsSaveSuccess => 'Saved successfully.';

  @override
  String get channelsSaveFailed => 'Save failed';

  @override
  String get channelsConnecting => '● Connected';

  @override
  String get channelsStarting => '● Starting...';

  @override
  String get channelsReady => 'Ready to connect';

  @override
  String get channelsSetupNeeded => 'Setup needed';

  @override
  String get channelsTokenInvalid =>
      'Invalid token format. (e.g., 123456:ABCdef)';

  @override
  String get channelsTokenRequired => 'Please enter Bot Token first.';

  @override
  String get channelsTokenSaveFirst => 'Please save Bot Token first.';

  @override
  String channelsConnectionSuccess(String botName) {
    return '@$botName connected successfully';
  }

  @override
  String get channelsConnectionFailed => 'Connection failed';

  @override
  String channelsMaskedTokenHint(String masked) {
    return '$masked  •  Enter new token below to change.';
  }

  @override
  String get channelsNewTokenHint => 'New token (to change)';

  @override
  String get channelsErrorOccurred => 'An error occurred.';

  @override
  String get placeConnected => 'Connected';

  @override
  String placeAppTooltipConnected(String title) {
    return '$title (connected)';
  }

  @override
  String get profileSystemPromptHint =>
      'Enter a role or speaking style for the LLM. (e.g., Reply in a friendly and warm tone)';

  @override
  String get profileDescription =>
      'Changes to profile picture and name here are instantly reflected in the chat widget.\nPersona is used to define this agent\'s AI personality and role.';

  @override
  String get serverPortSaved => '✅ Port saved. (Restart agent if changed)';

  @override
  String get serverPortSaveFailedNoResponse =>
      '❌ Save failed (agent not responding)';

  @override
  String get serverPortSaveFailed => '❌ Save failed';

  @override
  String get serverLogEmpty => 'No logs yet.';

  @override
  String get serverPortChange => 'Change';

  @override
  String get serverLogAlreadyRunning => '⚠️ Agent is already running';

  @override
  String serverLogProcessExited(String code) {
    return 'Process exited (code: $code)';
  }

  @override
  String get serverLogRestarting => '🔄 Restarting...';

  @override
  String get agentStopped => 'Agent is stopped';

  @override
  String get agentStoppedDesc =>
      'Press the power button above\nto start the agent and begin chatting.';

  @override
  String get serverConnectionRequired => 'Agent connection required';

  @override
  String get serverConnectionRequiredDesc =>
      'Please start the agent in Settings > Agent first.';

  @override
  String get modelSetupRequired => 'Model setup required';

  @override
  String get goToSettings => 'Go to Settings';

  @override
  String get currentAgent => 'Current Agent';

  @override
  String get pmAgentSection => 'PM Agent';

  @override
  String get domainAgentSection => 'Domain Agent';

  @override
  String get addDomainAgent => 'Add Agent';

  @override
  String get newAvatar => 'New Avatar';

  @override
  String get defaultAvatarName => 'ARI';

  @override
  String get dayNameSun => 'Sun';

  @override
  String get dayNameMon => 'Mon';

  @override
  String get dayNameTue => 'Tue';

  @override
  String get dayNameWed => 'Wed';

  @override
  String get dayNameThu => 'Thu';

  @override
  String get dayNameFri => 'Fri';

  @override
  String get dayNameSat => 'Sat';

  @override
  String get scheduleToday => 'Today';

  @override
  String get scheduleTomorrow => 'Tomorrow';

  @override
  String scheduleMonthDay(int month, int day) {
    return '$month/$day';
  }

  @override
  String get scheduleTapForToday => '(tap for today)';

  @override
  String get scheduleTask => 'Task';

  @override
  String get schedulePrompt => 'Prompt:';

  @override
  String scheduleLastResult(String time) {
    return 'Last result ($time):';
  }

  @override
  String get settingsServerDesc => 'Check and control local agent status';

  @override
  String get settingsAppearanceDesc => 'Screen style and window pin settings';

  @override
  String get settingsNotificationDesc =>
      'OS-level notifications for daemon status';

  @override
  String get settingsExperimentalDesc =>
      'Configure advanced tools and experimental features';

  @override
  String get settingsExperimentalDescDisabled =>
      'Configure advanced tools and experimental features (agent required)';

  @override
  String get settingsTokenDesc =>
      'Check AI model token usage and set limits for this avatar.';

  @override
  String get settingsResetMemoryDesc =>
      'Reset vector data learned and memorized by this avatar.\nLong-term memory will be deleted but persona is preserved.';

  @override
  String get settingsResetMemoryConfirm =>
      'Are you sure you want to reset all memory for this avatar?\nThis action cannot be undone.';

  @override
  String get settingsResetConversationDesc =>
      'Delete all chat logs with this avatar.\nHistory tab contents will be cleared.';

  @override
  String get settingsResetConversationConfirm =>
      'Delete all conversation history with the current avatar?';

  @override
  String get settingsDeleteAvatarDesc =>
      'Permanently delete all data (profile, logs, settings) for this avatar.\nThe default avatar (ARI) cannot be deleted.';

  @override
  String settingsDeleteAvatarConfirm(String name) {
    return 'Are you sure you want to permanently delete the \"$name\" avatar?\nAll related data will be deleted immediately.';
  }

  @override
  String get settingsOpenFolderDesc =>
      'Open the .ari-agent folder where all avatar data and logs are stored.';

  @override
  String get notificationDaemonTitle => 'Daemon status message notifications';

  @override
  String get notificationDaemonDesc =>
      'Show macOS/Windows notifications when new responses arrive while the window is hidden.';

  @override
  String get notificationAutoTaskTitle => 'Show auto task results in chat';

  @override
  String get notificationAutoTaskDesc =>
      'Display results in chat when automatic tasks complete.';

  @override
  String get experimentalShowAdvancedTools => 'Show Advanced Tools';

  @override
  String get experimentalShowAdvancedToolsDesc =>
      'Show developer-oriented features like Skills and Tools tabs.';

  @override
  String get experimentalEnableExperimental => 'Enable Experimental Features';

  @override
  String get experimentalEnableExperimentalDesc =>
      'Show features that are still being tested before official release.';

  @override
  String get experimentalAdvancedIntelligence =>
      'Enable Advanced Relational Intelligence';

  @override
  String get experimentalAdvancedIntelligenceDesc =>
      'Enable semantic vector memory and relationship graphs. (Check in Avatar > Memory tab)';

  @override
  String get experimentalModelReady => 'Embedding model ready';

  @override
  String get experimentalModelLoading => 'Loading embedding model...';

  @override
  String get experimentalModelDownloading =>
      'Downloading embedding model... (~280MB)';

  @override
  String get experimentalModelFailed =>
      'Model load failed — restart and try again';

  @override
  String get experimentalModelNotInstalled =>
      'Model not installed — auto-download on activation (~280MB)';

  @override
  String get advMemoryStatsFailed => 'Could not load statistics.';

  @override
  String get advMemoryGraphDesc => 'Relationship graph status of agent memory.';

  @override
  String get advMemoryNodeTitle => 'Memory Nodes';

  @override
  String get advMemoryCoreLabel => 'Core Memory';

  @override
  String get advMemoryDailyLabel => 'Daily Logs';

  @override
  String get advMemoryTotal => 'Total';

  @override
  String get advMemoryEntityTitle => 'Entities';

  @override
  String get advMemoryEntitySubtitle => 'People, tools, concepts...';

  @override
  String get advMemoryTopicTitle => 'Topics';

  @override
  String get advMemoryTopicSubtitle => 'Subject categories';

  @override
  String get advMemoryRelTitle => 'Relationships';

  @override
  String get advMemoryRelMentions => 'MENTIONS (memory → entity)';

  @override
  String get advMemoryRelAbout => 'ABOUT (memory → topic)';

  @override
  String get advMemoryRelFollows => 'FOLLOWS (time-order chain)';

  @override
  String get advMemoryRelTotal => 'Total relationships';

  @override
  String get aboutSlogan => 'AI that works and rests with you';

  @override
  String get aboutDescription =>
      'An AI companion that works alongside you based on memory and action. Not just answering questions, but naturally continuing within your flow.';

  @override
  String get aboutFeature1Title => 'Conversations with memory';

  @override
  String get aboutFeature1Desc =>
      'Continues more naturally based on previous context.';

  @override
  String get aboutFeature2Title => 'Leads to action';

  @override
  String get aboutFeature2Desc =>
      'Goes beyond words to necessary actions and workflows.';

  @override
  String get aboutFeature3Title => 'Moves with your apps';

  @override
  String get aboutFeature3Desc =>
      'Connects multiple apps into one seamless experience.';

  @override
  String get aboutFeature4Title => 'Work and play together';

  @override
  String get aboutFeature4Desc =>
      'Focus time and rest time flow together naturally.';

  @override
  String get aboutPhilosophy1Title => 'Staying in your space';

  @override
  String get aboutPhilosophy1Desc =>
      'Works like a presence beside you, not a distant service.';

  @override
  String get aboutPhilosophy2Title => 'Real help over conversation';

  @override
  String get aboutPhilosophy2Desc =>
      'Values help that leads to the next action over nice words.';

  @override
  String get aboutPhilosophy3Title => 'Experience, not just productivity';

  @override
  String get aboutPhilosophy3Desc =>
      'Not just a useful tool for work, but a companion you naturally keep around during rest and play too.';

  @override
  String get aboutUsageTitle => 'Try using it like this!';

  @override
  String get aboutUsage1 => '\"Help me organize today\'s tasks\"';

  @override
  String get aboutUsage1Cat => 'Daily planning';

  @override
  String get aboutUsage2 => '\"Remind me to grab coffee in 30 minutes\"';

  @override
  String get aboutUsage2Cat => 'Reminders';

  @override
  String get aboutUsage3 => '\"Continue helping with what I was working on\"';

  @override
  String get aboutUsage3Cat => 'Workflow continuity';

  @override
  String get aboutUsage4 => '\"Help me prep what I need before gaming\"';

  @override
  String get aboutUsage4Cat => 'Leisure prep';

  @override
  String get aboutUsage5 => '\"Remember what we just talked about?\"';

  @override
  String get aboutUsage5Cat => 'Personalized relationship';

  @override
  String get helpOAuth =>
      'If you already use a subscription service (e.g., ChatGPT), use it conveniently without issuing a separate key.';

  @override
  String get helpApiKey =>
      'Use your own API key directly for the most affordable and fastest performance.';

  @override
  String get helpPriority =>
      'Tries the top provider first and automatically falls back to the next one on error.';

  @override
  String get helpKeyIssue => 'Key issue URLs:';

  @override
  String get addProvider => 'Add Provider';

  @override
  String updateAvailable(String version, String mandatory) {
    return 'New version $version available$mandatory';
  }

  @override
  String get updateMandatory => ' · Required update';

  @override
  String get updateButton => 'Update';

  @override
  String get homeServerRequired => 'Agent connection required';

  @override
  String get homeServerRequiredDesc =>
      'Agent must be running to use this feature.\nPlease turn on the agent in the Settings tab.';

  @override
  String get chatEmptyPrompt => '💬 Ask ARI anything!';

  @override
  String get chatFollowUpPending => 'Pending';

  @override
  String chatFollowUpPendingCount(Object count) {
    return '$count pending';
  }

  @override
  String get modelSetupDesc =>
      'Register the AI provider and API key\nthat ARI will use to respond.';

  @override
  String get settingsModelDesc => 'AI model and API key settings';

  @override
  String get settingsModelDescDisabled =>
      'AI model and API key settings (agent must be running)';

  @override
  String get settingsAboutDesc => 'ARI Agent overview and version info';

  @override
  String get aboutPhilosophyHeading => 'What ARI cares about';

  @override
  String get relativeSoon => 'Soon';

  @override
  String relativeInMinutes(int minutes) {
    return 'in $minutes min';
  }

  @override
  String relativeInHours(int hours) {
    return 'in ${hours}h';
  }

  @override
  String relativeInDays(int days) {
    return 'in ${days}d';
  }

  @override
  String get notificationTitleBackground => 'ARI background response';

  @override
  String get notificationTitleNewMessage => 'ARI new message';

  @override
  String get helpGuideTitle => 'AI Provider setup guide';

  @override
  String get helpOAuthTitle => '☁️ OAuth service integration (recommended)';

  @override
  String get helpApiKeyTitle => '🔑 Enter API key directly';

  @override
  String get helpPriorityTitle => '🔝 Priority override';

  @override
  String get chatSuggestion1 => 'Install a Bitcoin trading app!';

  @override
  String get chatSuggestion2 => 'I want to do automated stock trading!';

  @override
  String get chatSuggestionSetupGreet => '👋 Hi';

  @override
  String get chatSuggestionSetupHowto => '🛠️ Show me how to use this';

  @override
  String get chatSuggestionSetupApiKey => '🔑 What is an API key?';

  @override
  String get chatSuggestionSetupCheapest => '💳 Which option is cheapest?';

  @override
  String get chatSuggestionSetupChatgpt => '⭐ I want to connect with ChatGPT';

  @override
  String get chatSuggestionSetupOauth => '🔓 What is OAuth?';

  @override
  String get chatSuggestionNormalGreet => '👋 Hi ARI!';

  @override
  String get chatSuggestionNormalDisk => '💾 Check disk usage';

  @override
  String get chatSuggestionNormalFile => '🔍 Find a file';

  @override
  String get chatSuggestionNormalRemind => 'Remind me in 1 minute!';

  @override
  String get chatSuggestionNormalMusic => '🎵 Play me a mellow song!';

  @override
  String get appearanceGray => 'Gray';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appearanceBlue => 'Blue';

  @override
  String get appearancePurple => 'Purple';

  @override
  String get appearanceBgTheme => 'Background Theme';

  @override
  String get appearanceLarge => 'Large';

  @override
  String get appearanceLanguage => 'Language';

  @override
  String get appearanceSpaceUsage => 'Space Usage';

  @override
  String get appearanceUnifySpace => 'Unify Place and List';

  @override
  String get appearanceUnifySpaceDesc =>
      'When enabled, the Place tab shows the space view. When disabled, it shows the agent list.';

  @override
  String get placeWorking => 'Working';

  @override
  String get placeIdle => 'Idle';

  @override
  String get placeResting => 'Resting';

  @override
  String get skillsCheckFolder => 'Check the agent\'s skills folder.';

  @override
  String get toolsCheckFolder => 'Check the agent\'s tools folder.';

  @override
  String get refresh => 'Refresh';
}
