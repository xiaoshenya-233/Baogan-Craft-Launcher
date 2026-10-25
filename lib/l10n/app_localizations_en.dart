// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Baogan Craft Launcher';

  @override
  String get navGroupLauncher => 'Launcher';

  @override
  String get navHome => 'Home';

  @override
  String get navVersions => 'Versions';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get navSettings => 'Settings';

  @override
  String get navTools => 'Utilities';

  @override
  String get navTasks => 'Download tasks';

  @override
  String get navWorkbench => 'Workbench';

  @override
  String get settingsLanguage => '语言 (Language)';

  @override
  String get settingsLanguageHint =>
      'Applies immediately and is saved on this device.';

  @override
  String get settingsLanguageZh => '简体中文';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get setupTitle => 'Choose launcher root folder';

  @override
  String get setupSubtitle =>
      'The first launch requires a root folder. Logs, databases and cache files are not created until it is configured.';

  @override
  String get setupDirectoryExampleTitle =>
      'For example, choosing a game folder creates:';

  @override
  String get setupInvalidDirectory =>
      'Select a valid launcher root folder to continue.';

  @override
  String setupCreateFailed(String error) {
    return 'Could not create the launcher folder: $error';
  }

  @override
  String get setupWritableHint =>
      'Make sure the launcher program folder is writable and the selected disk has enough space.';

  @override
  String setupPickerUnavailable(String error) {
    return 'The folder picker could not be opened ($error). Enter the full root path instead.';
  }

  @override
  String get setupPathHint => 'e.g. Games';

  @override
  String get setupUseThisFolder => 'Use this folder';

  @override
  String get setupSelectFolder => 'Select root folder';

  @override
  String get setupCreatingFolder => 'Creating folder…';

  @override
  String get setupCancelHint =>
      'Cancelling the folder picker keeps you on this screen; please try again.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionMinimize => 'Minimize';

  @override
  String get actionClose => 'Close';

  @override
  String get networkCheckTitle => 'Network check failed';

  @override
  String get networkCheckMessage =>
      'The network environment could not be verified, so downloads are unavailable. Check your network or system proxy and try again.';

  @override
  String get networkCheckRetryFailed =>
      'The network check still fails. Check your network or system proxy and try again.';

  @override
  String networkStartFailed(String error) {
    return 'Failed to start: $error';
  }

  @override
  String get networkChecking => 'Checking…';

  @override
  String get actionRetry => 'Retry';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowRestore => 'Restore';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowClose => 'Close';

  @override
  String get homeCurrentClient => 'Current client';

  @override
  String get homeScanningClients => 'Scanning clients…';

  @override
  String get homeNoClientSelected => 'No client selected';

  @override
  String get homeSelectClientHint =>
      'Pick a client card below to choose the version you want to launch.';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get homeLoginMethod => 'Sign-in method';

  @override
  String get homeCurrentAccount => 'Current account';

  @override
  String homeManageAccount(String type) {
    return '$type · Tap to manage account';
  }

  @override
  String homePlayerName(String name) {
    return 'Local Username: $name';
  }

  @override
  String get homeMicrosoftHint =>
      'Microsoft Login: shows a device code instantly.';

  @override
  String homeAuthSwitched(String mode) {
    return 'Sign-in method switched to $mode.';
  }

  @override
  String homeMicrosoftSignedIn(String name) {
    return 'Signed in as Microsoft account $name; it will be used when launching.';
  }

  @override
  String get homeSelectClient => 'Select client';

  @override
  String get homeClickSelectClient => 'Tap to choose an installed client';

  @override
  String get homeVersionUnknown => 'Unknown version';

  @override
  String get homeSwitch => 'Switch';

  @override
  String get homeViewClientConfig => 'View client settings';

  @override
  String get homeSelectClientFirst => 'Select a client first.';

  @override
  String get homeVersionTypeUnknown => 'Unknown version type';

  @override
  String get homeLaunchGame => 'Launch Game';

  @override
  String get homeNoClient => 'No client selected';

  @override
  String get versionVanilla => 'Vanilla';

  @override
  String homeJavaAutoDetected(int count) {
    return 'Auto (detected $count)';
  }

  @override
  String get homeJavaAutoLaunch => 'Auto at launch';

  @override
  String homeLocalProfile(String name) {
    return 'Local Profile · $name';
  }

  @override
  String get homeMicrosoftAccount => 'Microsoft Login';

  @override
  String get homeThirdPartyAccount => 'Third-party Auth';

  @override
  String get accountManagerTitle => 'Accounts';

  @override
  String accountCount(int count) {
    return '$count accounts';
  }

  @override
  String get accountManagerEmpty =>
      'No saved accounts yet. Use the button below to add a Microsoft Login, Local Profile or Third-party Auth account.';

  @override
  String get accountAddNew => 'Add account';

  @override
  String get accountCurrent => 'In use';

  @override
  String get accountRemoveTitle => 'Remove account';

  @override
  String accountRemoveConfirm(String name) {
    return 'Remove \"$name\" from the launcher?';
  }

  @override
  String get accountRemoveHint =>
      'The encrypted credentials stored on this device are deleted as well.';

  @override
  String get actionRemove => 'Remove';

  @override
  String get settingsSubtitle => 'Customize the launcher\'s look and feel.';

  @override
  String get settingsSectionGameDefaults => 'Game defaults';

  @override
  String get settingsSectionChannels => 'Resource channels';

  @override
  String get settingsSectionAppearance => 'Appearance & theme';

  @override
  String get settingsSectionJava => 'Java';

  @override
  String get settingsSectionDebug => 'Debugging & logs';

  @override
  String get settingsSectionAbout => 'About & credits';

  @override
  String settingsJavaRemoved(String path) {
    return 'Removed from the Java list: $path';
  }

  @override
  String get settingsThemeMode => 'Theme mode';

  @override
  String get settingsThemeModeHint =>
      'Auto mode follows local time and sunrise/sunset.';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeAuto => 'Auto (sunrise/sunset)';

  @override
  String settingsTimeZone(String offset, String longitude) {
    return 'Local time zone UTC$offset · estimated longitude $longitude°';
  }

  @override
  String get settingsSolarApprox =>
      'The position is estimated from the time zone (latitude assumed at the equator) for reference only; 06:30 / 18:30 is used when the network is unavailable.';

  @override
  String settingsSunriseSunset(String sunrise, String sunset, String source) {
    return 'Sunrise $sunrise  ·  Sunset $sunset  ·  $source';
  }

  @override
  String get settingsSolarOnline => 'online';

  @override
  String get settingsSolarDefault => 'default times';

  @override
  String settingsSolarError(String error) {
    return '$error; 06:30 / 18:30 is used for now.';
  }

  @override
  String get settingsCheckingSolar => 'Detecting sunrise/sunset…';

  @override
  String get settingsRefreshSolar => 'Refresh sunrise/sunset';

  @override
  String get settingsWallpaper => 'Wallpaper';

  @override
  String get settingsWallpaperHint =>
      'Set wallpapers for the light and dark themes; the matching image switches automatically.';

  @override
  String get settingsDarkWallpaper => 'Dark theme wallpaper';

  @override
  String get settingsLightWallpaper => 'Light theme wallpaper';

  @override
  String get settingsWallpaperNone =>
      'Not set; the other theme\'s wallpaper is used as a fallback.';

  @override
  String get settingsWallpaperEffect => 'Wallpaper fit';

  @override
  String get settingsWallpaperCover => 'Cover';

  @override
  String get settingsWallpaperStretch => 'Stretch';

  @override
  String get settingsWallpaperZoom => 'Zoom';

  @override
  String get settingsChooseImage => 'Choose image';

  @override
  String get settingsChangeImage => 'Change image';

  @override
  String get settingsRecrop => 'Recrop';

  @override
  String get settingsResetWallpaper => 'Reset to default';

  @override
  String settingsResetDone(String mode) {
    return 'Restored the default $mode theme background.';
  }

  @override
  String get settingsDebugMode => 'Debug mode';

  @override
  String get settingsDebugDescription =>
      'On by default. Records launcher actions, downloads, version scans, launch arguments and game output; the log window runs separately so the whole process stays visible.';

  @override
  String get settingsLogNotReady => 'The log file is not ready yet.';

  @override
  String get settingsOpenLogWindow => 'Open log window';

  @override
  String get settingsOpenLogFolder => 'Open log folder';

  @override
  String get settingsRecordState => 'Record current state';

  @override
  String get settingsCloseLogWindow => 'Close log window';

  @override
  String settingsOpenLogFailed(String error) {
    return 'Could not open the log folder: $error';
  }

  @override
  String settingsOpenBrowserFailed(String error) {
    return 'Could not open the browser: $error';
  }

  @override
  String aboutVersion(String version) {
    return 'Baogan Craft Launcher · version $version';
  }

  @override
  String get aboutLicenseDescription =>
      'This project is open source under GPLv3. Thanks to PCL2, HMCL, XMCL and BMCLAPI.';

  @override
  String get aboutLicenseButton => 'License & credits';

  @override
  String get aboutRepoButton => 'GitHub repository';

  @override
  String get actionDefault => 'Default';

  @override
  String get channelClientSource => 'Client download source';

  @override
  String get channelClientSourceHint =>
      'Where game files come from; version and loader metadata is always provided by BMCLAPI.';

  @override
  String get channelModSource => 'Mod resource source';

  @override
  String get channelMcimHint =>
      'With MCIM enabled, CurseForge requests go through the mod.mcimirror.top mirror.';

  @override
  String get channelAggregate => 'Aggregate search preference';

  @override
  String get channelAggregateHint =>
      'When a mod exists on both Modrinth and CurseForge, keep only the preferred platform\'s result.';

  @override
  String get sourceMojang => 'Official (Mojang)';

  @override
  String get sourceBmclapi => 'BMCLAPI mirror';

  @override
  String get sourceMcim => 'MCIM mirror';

  @override
  String get aggregateBalanced => 'Show all';

  @override
  String get aggregateModrinth => 'Prefer Modrinth';

  @override
  String get aggregateCurseForge => 'Prefer CurseForge';

  @override
  String get settingsDefaultsHint =>
      'These defaults apply to new clients; clients with their own settings keep theirs.';

  @override
  String get settingsDefaultJava => 'Default Java';

  @override
  String get settingsJavaAutoChoice => 'Match the game version';

  @override
  String get settingsJavaAutoHint =>
      'With \"Match the game version\", the launcher picks Java from the Java version declared by the client.';

  @override
  String get settingsDefaultMemory => 'Default memory';

  @override
  String get settingsMemoryPlaceholder =>
      'Display-only for now; not passed to the game yet.';

  @override
  String get javaNoneDetected =>
      'No Java detected yet. Open \"Manage Java\" to scan this device or add one manually.';

  @override
  String get javaCurrent => 'In use';

  @override
  String get actionManageJava => 'Manage Java';

  @override
  String aboutVersionLabel(String version) {
    return 'Version $version · GPLv3';
  }

  @override
  String get aboutLicenseTitle => 'License';

  @override
  String get aboutLicenseBody =>
      'This project is licensed under GPLv3: you may use, modify and redistribute it, but derivative works must also be open-sourced under GPLv3 and keep the original copyright notice.';

  @override
  String get aboutCreditsTitle => 'Core credits';

  @override
  String get aboutThanks =>
      'Thanks to all open-source projects and community contributors.';

  @override
  String get aboutCreditsPcl =>
      'Plain Craft Launcher 2 · reference for UI interaction and modpack installation';

  @override
  String get aboutCreditsHmcl =>
      'Hello Minecraft! Launcher · reference for loader detection and Java management';

  @override
  String get aboutCreditsXmcl =>
      'X Minecraft Launcher · reference for resource management and visual design';

  @override
  String get aboutCreditsBmclapi =>
      'Provides download acceleration for Minecraft resources';

  @override
  String get javaEnterPath =>
      'Enter the full path to the Java executable first.';

  @override
  String javaPathMissing(String path) {
    return 'The Java executable does not exist: $path';
  }

  @override
  String get javaUnrecognized =>
      'Could not recognize that Java; make sure the path points to java.exe.';

  @override
  String javaAdded(String path) {
    return 'Added to the Java list: $path';
  }

  @override
  String get javaBackToSettings => 'Back to settings';

  @override
  String get javaPageTitle => 'Java management';

  @override
  String get javaPageSubtitle =>
      'Scan this device for Java or add an executable manually. This page only maintains the list; choose the default Java in the settings dropdown.';

  @override
  String get javaAutoScan => 'Auto scan';

  @override
  String get javaAddPath => 'Add path manually';

  @override
  String get javaNoRuntime => 'No usable Java found; add a path manually.';

  @override
  String get javaNotScanned =>
      'Java has not been scanned yet; click \"Auto scan\" to start.';

  @override
  String get javaRemoveTooltip => 'Remove from list (does not delete files)';

  @override
  String get javaDialogTitle => 'Add a Java path manually';

  @override
  String get javaDialogHint =>
      'Enter the full path to java.exe; this only adds it to the list and does not make it the default.';

  @override
  String get javaPathExample => 'e.g. Java installation\\bin\\java.exe';

  @override
  String get javaDetecting => 'Checking…';

  @override
  String get actionAdd => 'Add';

  @override
  String get authModeLocalProfile => 'Local Profile';

  @override
  String get authModeMicrosoft => 'Microsoft Login';

  @override
  String get authModeThirdParty => 'Third-party Auth';

  @override
  String get authModeLocalProfileDesc =>
      'Use a local profile name for single-player worlds, or for servers that explicitly allow local profiles.';

  @override
  String get authModeMicrosoftDesc =>
      'Microsoft Login: shows a device code instantly, with no extra configuration.';

  @override
  String get authModeThirdPartyDesc =>
      'Uses Yggdrasil services such as LittleSkin; authlib-injector is bundled with the launcher.';

  @override
  String get loginMethodTitle => 'Sign-in Method';

  @override
  String loginMethodCurrent(String mode) {
    return 'Current: $mode';
  }

  @override
  String get loginMethodHint =>
      'Your choice is saved immediately. Account details are applied when you launch the game; the local username and auth server stay on this device.';

  @override
  String get microsoftDeviceCodeTitle => 'Complete Microsoft Login';

  @override
  String microsoftDeviceCodeBody(String uri, String code) {
    return 'Open $uri and enter this code:\n\n$code\n\nThis window closes automatically when sign-in completes.';
  }

  @override
  String microsoftDeviceCodeExpiry(int minutes) {
    return 'The code expires in about $minutes minutes.';
  }

  @override
  String get actionOpenBrowser => 'Open browser';

  @override
  String get microsoftNoOwnership =>
      'This Microsoft account does not own a valid copy of Minecraft: Java Edition. Please purchase the game to play online.';

  @override
  String get localProfileTitle => 'Local Profile';

  @override
  String get localProfileNameLabel => 'Local Username';

  @override
  String get localProfileNameHint => '3–16 letters, digits or underscores';

  @override
  String get homeQuickJoinNoAccount =>
      'No usable account configured; quick join was cancelled. Sign in or set a Local Username first.';

  @override
  String get actionContinue => 'Continue';

  @override
  String get homeNeedInstalledVersion =>
      'Select an installed Minecraft version first.';

  @override
  String get homeLaunchBusy =>
      'A launch is already in progress. Please try again shortly.';

  @override
  String homeMissingLaunchConfig(String version) {
    return 'Launch settings for $version were not found. Refresh the version list and try again.';
  }

  @override
  String get homeJavaNotSelectedQuickJoin =>
      'No Java runtime is selected for this client. Choose Java in Settings → Java before quick joining.';

  @override
  String homeJavaRuntimeMissing(String error) {
    return 'No usable Java runtime was found: $error. Choose Java in Settings → Java first.';
  }

  @override
  String get homeJavaNotSelected =>
      'No Java runtime is selected for this client. Choose Java in Settings → Java first.';

  @override
  String homeLaunching(String version) {
    return 'Launching Minecraft $version.';
  }

  @override
  String homeLaunchingJoin(String version, String server, String address) {
    return 'Launching $version and joining $server ($address).';
  }

  @override
  String homeLaunchFilesUnavailable(String error) {
    return 'Launch files are unavailable: $error';
  }

  @override
  String homeJavaStartFailed(String error) {
    return 'Could not start Java: $error. Choose another Java in Settings → Java.';
  }

  @override
  String homeAuthConnectFailed(String error) {
    return 'Could not connect to the authentication service: $error';
  }

  @override
  String homeAuthRequestFailed(String error) {
    return 'Authentication request failed: $error';
  }

  @override
  String homeAuthTlsFailed(String error) {
    return 'TLS connection to the authentication service failed: $error';
  }

  @override
  String get homeAuthTimeout =>
      'Authentication timed out. Check your network and try again.';

  @override
  String get homeAuthlibFailed =>
      'Failed to unpack the bundled authlib-injector. Check write permission for the launcher folder.';

  @override
  String get homeLoginAndLaunch => 'Sign in and Launch';

  @override
  String get homeThirdPartyLoginTitle => 'Third-party Server Login';

  @override
  String get homeYggdrasilAddress => 'Yggdrasil API URL';

  @override
  String get homeEmailOrUsername => 'Email or username';

  @override
  String get homePassword => 'Password';

  @override
  String get homeClientFallback => 'Client';

  @override
  String homeClientJavaSaved(String name, String java) {
    return 'Saved a dedicated Java for $name: $java';
  }

  @override
  String homeClientJavaFollowGlobal(String name) {
    return '$name now follows the global Java setting.';
  }

  @override
  String homeClientMemorySaved(String name, String memory) {
    return 'Saved dedicated memory for $name: $memory GB';
  }

  @override
  String homeGlobalJavaMissing(String path) {
    return 'The global Java no longer exists ($path). Choose another one in Settings.';
  }

  @override
  String homeSettingsReadFailed(String error) {
    return 'Could not read launcher settings: $error';
  }

  @override
  String homeSettingsSaveFailed(String error) {
    return 'Could not save launcher settings: $error';
  }

  @override
  String get homeJavaAutoRestored => 'Restored automatic Java selection.';

  @override
  String get homeJavaUnrecognized =>
      'Could not recognize that Java. Make sure it is a runnable Java executable.';

  @override
  String homeJavaAdded(String name) {
    return 'Added Java: $name';
  }

  @override
  String get homeDebugEnabled =>
      'Debug logging is on and the log window is open.';

  @override
  String get homeDebugDisabled => 'Debug logging is off.';

  @override
  String get homePickJavaTitle => 'Select a Java executable';

  @override
  String homePickJavaFailed(String error) {
    return 'Could not select the Java file: $error';
  }

  @override
  String get homeNoClientsFound =>
      'No clients found yet. Choose a game folder or download Minecraft first.';

  @override
  String get homeInstallPickClientTitle => 'Select install target';

  @override
  String get homeInstallPickFabricClientTitle => 'Select Fabric client';

  @override
  String get homeInstallTargetLabel => 'Install resources into';

  @override
  String get homeRememberAndContinue => 'Remember and continue';

  @override
  String homeSaveClientSelectionFailed(String error) {
    return 'Could not save the client selection: $error';
  }

  @override
  String homeNetworkFailed(String error) {
    return 'Network connection failed: $error';
  }

  @override
  String homeCatalogReadFailed(String error) {
    return 'Could not read BMCLAPI: $error';
  }

  @override
  String get homeCatalogTimeout =>
      'The BMCLAPI request timed out. Please try again later.';

  @override
  String homeVersionDataInvalid(String error) {
    return 'Invalid version data: $error';
  }

  @override
  String homeLoaderFetchStatus(String loader, String version) {
    return 'Fetching $loader loader versions (Minecraft $version)';
  }

  @override
  String homeLoaderDataInvalid(String error) {
    return 'Invalid loader version data: $error';
  }

  @override
  String get homeChooseMinecraftFolder =>
      'Could not determine the default Minecraft folder. Choose a .minecraft folder in Versions first.';

  @override
  String get homeDownloadBusy =>
      'A download is already running. Wait for it to finish or cancel it first.';

  @override
  String get homeSelectMinecraftVersionFirst =>
      'Select a Minecraft version first.';

  @override
  String homeSelectLoaderVersionFirst(String loader) {
    return 'Select a valid $loader version first.';
  }

  @override
  String get homeInvalidClientName =>
      'Invalid client name: it cannot contain \\ / : * ? \" < > | or use a reserved system name.';

  @override
  String homeClientNameExists(String name) {
    return 'A client named \"$name\" already exists. Choose another name.';
  }

  @override
  String homePreparingDownload(String version) {
    return 'Preparing to download Minecraft $version…';
  }

  @override
  String homeInstallerLabel(String loader, String version) {
    return '$loader $version installer';
  }

  @override
  String homeInstallFinished(String summary) {
    return '$summary installation complete.';
  }

  @override
  String get homeFabricApiIncomplete =>
      ' Fabric API did not finish; retry from the resources page.';

  @override
  String get homeOptifineClosedRescan =>
      'The OptiFine installer was closed. Rescan the version list to confirm the installation.';

  @override
  String homeInstalledTo(String summary, String path) {
    return '$summary installed to $path.';
  }

  @override
  String get homeOptifineClosedConfirm =>
      'The OptiFine installer was closed. Confirm the result and rescan versions.';

  @override
  String get homeClientInstallDoneCancelRest =>
      'The client finished installing; remaining downloads were cancelled.';

  @override
  String get homeDownloadCancelled =>
      'Download cancelled; temporary files were cleaned up.';

  @override
  String homeDownloadServerError(String error) {
    return 'The download server returned an error: $error';
  }

  @override
  String homeDownloadConnectFailed(String error) {
    return 'Download connection failed: $error';
  }

  @override
  String get homeInstallTimeout =>
      'Installation timed out. Check your network proxy and try again.';

  @override
  String homeMinecraftDataInvalid(String error) {
    return 'Invalid Minecraft version data: $error';
  }

  @override
  String homeWriteFilesFailed(String error) {
    return 'Could not write Minecraft files: $error';
  }

  @override
  String homeMinecraftDownloadFailed(String error) {
    return 'Minecraft download failed: $error';
  }

  @override
  String get targetClientTitle => 'Select target client';

  @override
  String get targetClientSubtitle =>
      'Choose which client the resource should be installed into.';

  @override
  String targetClientSubtitleNamed(String name) {
    return 'Choose where to install \"$name\".';
  }

  @override
  String get targetClientEmpty =>
      'No clients available yet. Install one in Versions first.';

  @override
  String targetClientPickFolderFailed(String error) {
    return 'Could not select the folder: $error';
  }

  @override
  String get targetClientFolderDialogTitle =>
      'Select client folder (version folder)';

  @override
  String get targetClientChooseFolder => 'Choose the folder myself';

  @override
  String get targetClientConfirm => 'Confirm install';

  @override
  String get targetClientBadgeCompatible => 'Compatible';

  @override
  String get targetClientBadgeVersionMismatch => 'Version mismatch';

  @override
  String get targetClientBadgeLoaderMismatch => 'Loader mismatch';

  @override
  String get targetClientBadgeBothMismatch => 'Version & loader mismatch';

  @override
  String get targetClientWarning =>
      'Warning: this mod may not load in the selected client. Make sure you use a cross-loader tool such as Sinytra Connector.';

  @override
  String targetClientSupportVersions(String versions) {
    return 'Supported versions: $versions';
  }

  @override
  String targetClientSupportLoaders(String loaders) {
    return 'Supported loaders: $loaders';
  }

  @override
  String get targetClientSupportNone =>
      'This resource declares no version or loader limits, so any client can be used.';

  @override
  String get commonUnknownVersion => 'Unknown version';

  @override
  String get pluginsTitle => 'Plugin Center';

  @override
  String get pluginsSubtitle =>
      'Browse installed plugins and open their JSON UI.';

  @override
  String get pluginsEmpty =>
      'No plugins installed yet. Drop a plugin into BGCL/plugins and refresh.';

  @override
  String get pluginsRefresh => 'Refresh plugin list';

  @override
  String get pluginOpenFolder => 'Open plugin folder';

  @override
  String get pluginFolderUnavailable =>
      'The plugin folder is not ready. Finish launcher setup first.';

  @override
  String pluginsLoadFailed(String error) {
    return 'Could not load the plugin: $error';
  }

  @override
  String get pluginsNoUi => 'This plugin has no UI document.';

  @override
  String pluginsVersionAuthor(String version, String author) {
    return '$version · $author';
  }

  @override
  String pluginsPermissions(String permissions) {
    return 'Permissions: $permissions';
  }

  @override
  String get pluginBack => 'Back to plugins';

  @override
  String get pluginLoading => 'Loading plugin…';

  @override
  String pluginPermissionDenied(String permission, String action) {
    return 'Permission denied: the plugin lacks the $permission permission for $action.';
  }

  @override
  String pluginActionFailed(String error) {
    return 'Plugin action failed: $error';
  }

  @override
  String pluginActionInvalid(String action) {
    return 'Unknown or unsupported plugin action: $action';
  }

  @override
  String pluginFileSaved(String path) {
    return 'Saved to the plugin folder: $path';
  }

  @override
  String pluginFileRead(String path) {
    return 'Read: $path';
  }

  @override
  String pluginFileDownloaded(String path) {
    return 'Download complete: $path';
  }

  @override
  String get pluginWebviewPermissionDenied =>
      'Permission denied: the webview node requires the webview permission.';

  @override
  String pluginWebviewPlaceholder(String url) {
    return 'Webview: $url (coming in a later version)';
  }

  @override
  String get workbenchHubTitle => 'Feature Hub';

  @override
  String get workbenchHubSubtitle =>
      'One place for plugins, system monitors and utilities.';

  @override
  String get workbenchPluginCenterDescription =>
      'Browse, run and manage installed plugin UIs.';

  @override
  String get workbenchSystemMonitor => 'System Monitor';

  @override
  String get workbenchSystemMonitorDescription =>
      'Check Windows memory and CPU usage.';

  @override
  String get workbenchSystemMonitorPlaceholder =>
      'Windows memory and CPU status will appear here.';

  @override
  String get workbenchNbtViewer => 'NBT Viewer';

  @override
  String get workbenchNbtViewerDescription =>
      'Browse and validate save-file NBT data.';

  @override
  String get workbenchNbtPlaceholder => 'NBT data will be browsable here.';

  @override
  String get workbenchSaveBackup => 'Save Backup Center';

  @override
  String get workbenchSaveBackupDescription =>
      'Back up and restore local world saves in one click';

  @override
  String get workbenchSaveBackupPlaceholder =>
      'One-click save archiving will arrive here so your worlds are never lost.';

  @override
  String get workbenchComingSoon => 'In development';

  @override
  String get workbenchBack => 'Back to feature hub';
}
