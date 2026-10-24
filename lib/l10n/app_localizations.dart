import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('zh'),
  ];

  /// Window title of the launcher.
  ///
  /// In zh, this message translates to:
  /// **'Baogan Craft Launcher'**
  String get appTitle;

  /// Sidebar group label for the main launcher pages.
  ///
  /// In zh, this message translates to:
  /// **'启动器'**
  String get navGroupLauncher;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'主页'**
  String get navHome;

  /// No description provided for @navVersions.
  ///
  /// In zh, this message translates to:
  /// **'版本管理'**
  String get navVersions;

  /// No description provided for @navDownloads.
  ///
  /// In zh, this message translates to:
  /// **'资源下载'**
  String get navDownloads;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @navTools.
  ///
  /// In zh, this message translates to:
  /// **'实用工具'**
  String get navTools;

  /// No description provided for @navTasks.
  ///
  /// In zh, this message translates to:
  /// **'下载任务'**
  String get navTasks;

  /// No description provided for @navWorkbench.
  ///
  /// In zh, this message translates to:
  /// **'工作台'**
  String get navWorkbench;

  /// Title of the language selector in the settings page.
  ///
  /// In zh, this message translates to:
  /// **'语言 (Language)'**
  String get settingsLanguage;

  /// Helper text under the language selector.
  ///
  /// In zh, this message translates to:
  /// **'切换后立即生效，并保存到本机。'**
  String get settingsLanguageHint;

  /// No description provided for @settingsLanguageZh.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get settingsLanguageZh;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// Title of the first-launch setup card and of the folder picker dialog.
  ///
  /// In zh, this message translates to:
  /// **'选择启动器根目录'**
  String get setupTitle;

  /// No description provided for @setupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'首次启动必须完成目录设置，配置完成前不会创建日志、数据库或缓存文件。'**
  String get setupSubtitle;

  /// No description provided for @setupDirectoryExampleTitle.
  ///
  /// In zh, this message translates to:
  /// **'例如选择 E:\\Games 后，将创建：'**
  String get setupDirectoryExampleTitle;

  /// No description provided for @setupInvalidDirectory.
  ///
  /// In zh, this message translates to:
  /// **'必须选择一个有效的启动器根目录才能继续。'**
  String get setupInvalidDirectory;

  /// No description provided for @setupCreateFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法创建启动器目录：{error}'**
  String setupCreateFailed(String error);

  /// No description provided for @setupWritableHint.
  ///
  /// In zh, this message translates to:
  /// **'请确认启动器程序目录可写，且所选磁盘有足够空间。'**
  String get setupWritableHint;

  /// No description provided for @setupPickerUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'文件夹选择器无法打开（{error}）。请直接输入根目录的完整路径。'**
  String setupPickerUnavailable(String error);

  /// No description provided for @setupPathHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 E:\\Games'**
  String get setupPathHint;

  /// No description provided for @setupUseThisFolder.
  ///
  /// In zh, this message translates to:
  /// **'使用此目录'**
  String get setupUseThisFolder;

  /// No description provided for @setupSelectFolder.
  ///
  /// In zh, this message translates to:
  /// **'选择根目录'**
  String get setupSelectFolder;

  /// No description provided for @setupCreatingFolder.
  ///
  /// In zh, this message translates to:
  /// **'正在创建目录…'**
  String get setupCreatingFolder;

  /// No description provided for @setupCancelHint.
  ///
  /// In zh, this message translates to:
  /// **'取消文件夹选择不会进入主界面，请重新选择。'**
  String get setupCancelHint;

  /// No description provided for @actionCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get actionCancel;

  /// No description provided for @actionMinimize.
  ///
  /// In zh, this message translates to:
  /// **'最小化'**
  String get actionMinimize;

  /// No description provided for @actionClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get actionClose;

  /// No description provided for @networkCheckTitle.
  ///
  /// In zh, this message translates to:
  /// **'网络环境检测失败'**
  String get networkCheckTitle;

  /// No description provided for @networkCheckMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法确认当前网络环境，下载功能暂不可用。请检查网络或系统代理设置后重试。'**
  String get networkCheckMessage;

  /// No description provided for @networkCheckRetryFailed.
  ///
  /// In zh, this message translates to:
  /// **'网络检测仍然失败，请检查网络或系统代理设置后重试。'**
  String get networkCheckRetryFailed;

  /// No description provided for @networkStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'启动失败：{error}'**
  String networkStartFailed(String error);

  /// No description provided for @networkChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在检测…'**
  String get networkChecking;

  /// No description provided for @actionRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get actionRetry;

  /// No description provided for @windowMinimize.
  ///
  /// In zh, this message translates to:
  /// **'最小化'**
  String get windowMinimize;

  /// No description provided for @windowRestore.
  ///
  /// In zh, this message translates to:
  /// **'还原'**
  String get windowRestore;

  /// No description provided for @windowMaximize.
  ///
  /// In zh, this message translates to:
  /// **'最大化'**
  String get windowMaximize;

  /// No description provided for @windowClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get windowClose;

  /// No description provided for @homeCurrentClient.
  ///
  /// In zh, this message translates to:
  /// **'当前客户端'**
  String get homeCurrentClient;

  /// No description provided for @homeScanningClients.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描客户端…'**
  String get homeScanningClients;

  /// No description provided for @homeNoClientSelected.
  ///
  /// In zh, this message translates to:
  /// **'尚未选择客户端'**
  String get homeNoClientSelected;

  /// No description provided for @homeSelectClientHint.
  ///
  /// In zh, this message translates to:
  /// **'点击下方客户端卡片选择要启动的客户端版本。'**
  String get homeSelectClientHint;

  /// No description provided for @commonUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get commonUnknown;

  /// No description provided for @homeLoginMethod.
  ///
  /// In zh, this message translates to:
  /// **'登录方式'**
  String get homeLoginMethod;

  /// No description provided for @homeCurrentAccount.
  ///
  /// In zh, this message translates to:
  /// **'当前账号'**
  String get homeCurrentAccount;

  /// No description provided for @homeManageAccount.
  ///
  /// In zh, this message translates to:
  /// **'{type} · 点击管理账号'**
  String homeManageAccount(String type);

  /// No description provided for @homePlayerName.
  ///
  /// In zh, this message translates to:
  /// **'玩家：{name}'**
  String homePlayerName(String name);

  /// No description provided for @homeMicrosoftHint.
  ///
  /// In zh, this message translates to:
  /// **'点击后立即显示设备码，登录 Microsoft 账号'**
  String get homeMicrosoftHint;

  /// No description provided for @homeAuthSwitched.
  ///
  /// In zh, this message translates to:
  /// **'登录方式已切换为 {mode}。'**
  String homeAuthSwitched(String mode);

  /// No description provided for @homeMicrosoftSignedIn.
  ///
  /// In zh, this message translates to:
  /// **'已登录 Microsoft 账号：{name}，启动时将直接使用该账号。'**
  String homeMicrosoftSignedIn(String name);

  /// No description provided for @homeSelectClient.
  ///
  /// In zh, this message translates to:
  /// **'选择客户端'**
  String get homeSelectClient;

  /// No description provided for @homeClickSelectClient.
  ///
  /// In zh, this message translates to:
  /// **'点击选择已安装客户端'**
  String get homeClickSelectClient;

  /// No description provided for @homeVersionUnknown.
  ///
  /// In zh, this message translates to:
  /// **'版本未知'**
  String get homeVersionUnknown;

  /// No description provided for @homeSwitch.
  ///
  /// In zh, this message translates to:
  /// **'切换'**
  String get homeSwitch;

  /// No description provided for @homeViewClientConfig.
  ///
  /// In zh, this message translates to:
  /// **'查看客户端配置'**
  String get homeViewClientConfig;

  /// No description provided for @homeSelectClientFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先选择一个客户端。'**
  String get homeSelectClientFirst;

  /// No description provided for @homeVersionTypeUnknown.
  ///
  /// In zh, this message translates to:
  /// **'版本类型未知'**
  String get homeVersionTypeUnknown;

  /// No description provided for @homeLaunchGame.
  ///
  /// In zh, this message translates to:
  /// **'开始游戏'**
  String get homeLaunchGame;

  /// No description provided for @homeNoClient.
  ///
  /// In zh, this message translates to:
  /// **'未选择客户端'**
  String get homeNoClient;

  /// No description provided for @versionVanilla.
  ///
  /// In zh, this message translates to:
  /// **'原版'**
  String get versionVanilla;

  /// No description provided for @homeJavaAutoDetected.
  ///
  /// In zh, this message translates to:
  /// **'自动匹配（已检测 {count} 个）'**
  String homeJavaAutoDetected(int count);

  /// No description provided for @homeJavaAutoLaunch.
  ///
  /// In zh, this message translates to:
  /// **'启动时自动匹配'**
  String get homeJavaAutoLaunch;

  /// No description provided for @homeLocalProfile.
  ///
  /// In zh, this message translates to:
  /// **'本地档案 · {name}'**
  String homeLocalProfile(String name);

  /// No description provided for @homeMicrosoftAccount.
  ///
  /// In zh, this message translates to:
  /// **'Microsoft 登录'**
  String get homeMicrosoftAccount;

  /// No description provided for @homeThirdPartyAccount.
  ///
  /// In zh, this message translates to:
  /// **'第三方验证'**
  String get homeThirdPartyAccount;

  /// No description provided for @accountManagerTitle.
  ///
  /// In zh, this message translates to:
  /// **'账号管理'**
  String get accountManagerTitle;

  /// No description provided for @accountCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 个账号'**
  String accountCount(int count);

  /// No description provided for @accountManagerEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有保存的账号。点击下方按钮添加 Microsoft、本地档案或第三方账号。'**
  String get accountManagerEmpty;

  /// No description provided for @accountAddNew.
  ///
  /// In zh, this message translates to:
  /// **'添加新账号'**
  String get accountAddNew;

  /// No description provided for @accountCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前使用'**
  String get accountCurrent;

  /// No description provided for @accountRemoveTitle.
  ///
  /// In zh, this message translates to:
  /// **'移除账号'**
  String get accountRemoveTitle;

  /// No description provided for @accountRemoveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要从启动器移除「{name}」吗？'**
  String accountRemoveConfirm(String name);

  /// No description provided for @accountRemoveHint.
  ///
  /// In zh, this message translates to:
  /// **'本机保存的加密登录凭据也会一并清除。'**
  String get accountRemoveHint;

  /// No description provided for @actionRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get actionRemove;

  /// No description provided for @settingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义启动器外观与使用体验。'**
  String get settingsSubtitle;

  /// No description provided for @settingsSectionGameDefaults.
  ///
  /// In zh, this message translates to:
  /// **'全局游戏默认设置'**
  String get settingsSectionGameDefaults;

  /// No description provided for @settingsSectionChannels.
  ///
  /// In zh, this message translates to:
  /// **'游戏资源获取渠道'**
  String get settingsSectionChannels;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In zh, this message translates to:
  /// **'个性化与主题'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionJava.
  ///
  /// In zh, this message translates to:
  /// **'Java 管理'**
  String get settingsSectionJava;

  /// No description provided for @settingsSectionDebug.
  ///
  /// In zh, this message translates to:
  /// **'调试与日志'**
  String get settingsSectionDebug;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于与鸣谢'**
  String get settingsSectionAbout;

  /// No description provided for @settingsJavaRemoved.
  ///
  /// In zh, this message translates to:
  /// **'已从 Java 列表移除：{path}'**
  String settingsJavaRemoved(String path);

  /// No description provided for @settingsThemeMode.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get settingsThemeMode;

  /// No description provided for @settingsThemeModeHint.
  ///
  /// In zh, this message translates to:
  /// **'自动模式根据本地时间和日出日落切换主题。'**
  String get settingsThemeModeHint;

  /// No description provided for @settingsThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLight.
  ///
  /// In zh, this message translates to:
  /// **'亮色'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeAuto.
  ///
  /// In zh, this message translates to:
  /// **'日出日落自动'**
  String get settingsThemeAuto;

  /// No description provided for @settingsTimeZone.
  ///
  /// In zh, this message translates to:
  /// **'本地时区 UTC{offset} · 推算经度 {longitude}°'**
  String settingsTimeZone(String offset, String longitude);

  /// No description provided for @settingsSolarApprox.
  ///
  /// In zh, this message translates to:
  /// **'位置仅按时区估算（纬度按赤道近似），仅供参考；联网失败时使用 06:30 / 18:30。'**
  String get settingsSolarApprox;

  /// No description provided for @settingsSunriseSunset.
  ///
  /// In zh, this message translates to:
  /// **'日出 {sunrise}  ·  日落 {sunset}  ·  {source}'**
  String settingsSunriseSunset(String sunrise, String sunset, String source);

  /// No description provided for @settingsSolarOnline.
  ///
  /// In zh, this message translates to:
  /// **'联网获取'**
  String get settingsSolarOnline;

  /// No description provided for @settingsSolarDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认时间'**
  String get settingsSolarDefault;

  /// No description provided for @settingsSolarError.
  ///
  /// In zh, this message translates to:
  /// **'{error}，当前使用 06:30 / 18:30。'**
  String settingsSolarError(String error);

  /// No description provided for @settingsCheckingSolar.
  ///
  /// In zh, this message translates to:
  /// **'正在检测日出日落时间…'**
  String get settingsCheckingSolar;

  /// No description provided for @settingsRefreshSolar.
  ///
  /// In zh, this message translates to:
  /// **'刷新日出日落'**
  String get settingsRefreshSolar;

  /// No description provided for @settingsWallpaper.
  ///
  /// In zh, this message translates to:
  /// **'壁纸'**
  String get settingsWallpaper;

  /// No description provided for @settingsWallpaperHint.
  ///
  /// In zh, this message translates to:
  /// **'分别为亮色和深色主题设置壁纸，切换主题时自动切换对应图片。'**
  String get settingsWallpaperHint;

  /// No description provided for @settingsDarkWallpaper.
  ///
  /// In zh, this message translates to:
  /// **'深色模式壁纸'**
  String get settingsDarkWallpaper;

  /// No description provided for @settingsLightWallpaper.
  ///
  /// In zh, this message translates to:
  /// **'亮色模式壁纸'**
  String get settingsLightWallpaper;

  /// No description provided for @settingsWallpaperNone.
  ///
  /// In zh, this message translates to:
  /// **'尚未选择；未设置时会暂用另一主题的壁纸。'**
  String get settingsWallpaperNone;

  /// No description provided for @settingsWallpaperEffect.
  ///
  /// In zh, this message translates to:
  /// **'壁纸效果'**
  String get settingsWallpaperEffect;

  /// No description provided for @settingsWallpaperCover.
  ///
  /// In zh, this message translates to:
  /// **'铺满'**
  String get settingsWallpaperCover;

  /// No description provided for @settingsWallpaperStretch.
  ///
  /// In zh, this message translates to:
  /// **'拉伸'**
  String get settingsWallpaperStretch;

  /// No description provided for @settingsWallpaperZoom.
  ///
  /// In zh, this message translates to:
  /// **'放大'**
  String get settingsWallpaperZoom;

  /// No description provided for @settingsChooseImage.
  ///
  /// In zh, this message translates to:
  /// **'选择图片'**
  String get settingsChooseImage;

  /// No description provided for @settingsChangeImage.
  ///
  /// In zh, this message translates to:
  /// **'更换图片'**
  String get settingsChangeImage;

  /// No description provided for @settingsRecrop.
  ///
  /// In zh, this message translates to:
  /// **'重新裁切'**
  String get settingsRecrop;

  /// No description provided for @settingsResetWallpaper.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get settingsResetWallpaper;

  /// No description provided for @settingsResetDone.
  ///
  /// In zh, this message translates to:
  /// **'已恢复{mode}模式默认背景。'**
  String settingsResetDone(String mode);

  /// No description provided for @settingsDebugMode.
  ///
  /// In zh, this message translates to:
  /// **'调试模式'**
  String get settingsDebugMode;

  /// No description provided for @settingsDebugDescription.
  ///
  /// In zh, this message translates to:
  /// **'默认开启。记录启动器操作、下载、版本扫描、启动参数和游戏进程输出；日志窗口独立于启动器运行，便于观察完整过程。'**
  String get settingsDebugDescription;

  /// No description provided for @settingsLogNotReady.
  ///
  /// In zh, this message translates to:
  /// **'日志文件尚未初始化。'**
  String get settingsLogNotReady;

  /// No description provided for @settingsOpenLogWindow.
  ///
  /// In zh, this message translates to:
  /// **'打开日志窗口'**
  String get settingsOpenLogWindow;

  /// No description provided for @settingsOpenLogFolder.
  ///
  /// In zh, this message translates to:
  /// **'打开日志文件夹'**
  String get settingsOpenLogFolder;

  /// No description provided for @settingsRecordState.
  ///
  /// In zh, this message translates to:
  /// **'记录当前状态'**
  String get settingsRecordState;

  /// No description provided for @settingsCloseLogWindow.
  ///
  /// In zh, this message translates to:
  /// **'关闭日志窗口'**
  String get settingsCloseLogWindow;

  /// No description provided for @settingsOpenLogFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开日志文件夹：{error}'**
  String settingsOpenLogFailed(String error);

  /// No description provided for @settingsOpenBrowserFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开浏览器：{error}'**
  String settingsOpenBrowserFailed(String error);

  /// No description provided for @aboutVersion.
  ///
  /// In zh, this message translates to:
  /// **'Baogan Craft Launcher · 版本 {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutLicenseDescription.
  ///
  /// In zh, this message translates to:
  /// **'本项目基于 GPLv3 协议开源，感谢 PCL2、HMCL、XMCL 与 BMCLAPI 等开源项目。'**
  String get aboutLicenseDescription;

  /// No description provided for @aboutLicenseButton.
  ///
  /// In zh, this message translates to:
  /// **'开源协议与鸣谢'**
  String get aboutLicenseButton;

  /// No description provided for @aboutRepoButton.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 仓库'**
  String get aboutRepoButton;

  /// No description provided for @actionDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get actionDefault;

  /// No description provided for @channelClientSource.
  ///
  /// In zh, this message translates to:
  /// **'客户端下载源'**
  String get channelClientSource;

  /// No description provided for @channelClientSourceHint.
  ///
  /// In zh, this message translates to:
  /// **'游戏文件下载来源；版本与加载器信息始终由 BMCLAPI 提供。'**
  String get channelClientSourceHint;

  /// No description provided for @channelModSource.
  ///
  /// In zh, this message translates to:
  /// **'模组资源源'**
  String get channelModSource;

  /// No description provided for @channelMcimHint.
  ///
  /// In zh, this message translates to:
  /// **'启用 MCIM 后 CurseForge 请求会走 mod.mcimirror.top 镜像。'**
  String get channelMcimHint;

  /// No description provided for @channelAggregate.
  ///
  /// In zh, this message translates to:
  /// **'聚合搜索偏好'**
  String get channelAggregate;

  /// No description provided for @channelAggregateHint.
  ///
  /// In zh, this message translates to:
  /// **'同一模组同时出现在 Modrinth 与 CurseForge 时，只保留偏向平台的一条。'**
  String get channelAggregateHint;

  /// No description provided for @sourceMojang.
  ///
  /// In zh, this message translates to:
  /// **'Mojang 官方'**
  String get sourceMojang;

  /// No description provided for @sourceBmclapi.
  ///
  /// In zh, this message translates to:
  /// **'BMCLAPI 加速'**
  String get sourceBmclapi;

  /// No description provided for @sourceMcim.
  ///
  /// In zh, this message translates to:
  /// **'MCIM 镜像站'**
  String get sourceMcim;

  /// No description provided for @aggregateBalanced.
  ///
  /// In zh, this message translates to:
  /// **'全部显示'**
  String get aggregateBalanced;

  /// No description provided for @aggregateModrinth.
  ///
  /// In zh, this message translates to:
  /// **'偏向 Modrinth'**
  String get aggregateModrinth;

  /// No description provided for @aggregateCurseForge.
  ///
  /// In zh, this message translates to:
  /// **'偏向 CurseForge'**
  String get aggregateCurseForge;

  /// No description provided for @settingsDefaultsHint.
  ///
  /// In zh, this message translates to:
  /// **'这些默认值用于新建客户端；已单独配置的客户端仍使用各自的设置。'**
  String get settingsDefaultsHint;

  /// No description provided for @settingsDefaultJava.
  ///
  /// In zh, this message translates to:
  /// **'默认 Java'**
  String get settingsDefaultJava;

  /// No description provided for @settingsJavaAutoChoice.
  ///
  /// In zh, this message translates to:
  /// **'根据游戏版本自动设定'**
  String get settingsJavaAutoChoice;

  /// No description provided for @settingsJavaAutoHint.
  ///
  /// In zh, this message translates to:
  /// **'选择「根据游戏版本自动设定」时，启动器会按客户端声明的 Java 版本自动匹配。'**
  String get settingsJavaAutoHint;

  /// No description provided for @settingsDefaultMemory.
  ///
  /// In zh, this message translates to:
  /// **'默认内存分配'**
  String get settingsDefaultMemory;

  /// No description provided for @settingsMemoryPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'仅用于界面占位，尚未写入启动参数。'**
  String get settingsMemoryPlaceholder;

  /// No description provided for @javaNoneDetected.
  ///
  /// In zh, this message translates to:
  /// **'尚未检测到 Java。点击「管理 Java」扫描本机或手动添加。'**
  String get javaNoneDetected;

  /// No description provided for @javaCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前使用'**
  String get javaCurrent;

  /// No description provided for @actionManageJava.
  ///
  /// In zh, this message translates to:
  /// **'管理 Java'**
  String get actionManageJava;

  /// No description provided for @aboutVersionLabel.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version} · GPLv3 开源'**
  String aboutVersionLabel(String version);

  /// No description provided for @aboutLicenseTitle.
  ///
  /// In zh, this message translates to:
  /// **'开源协议'**
  String get aboutLicenseTitle;

  /// No description provided for @aboutLicenseBody.
  ///
  /// In zh, this message translates to:
  /// **'本项目基于 GPLv3 协议开源：你可以自由使用、修改与分发，但衍生作品必须同样以 GPLv3 开放源代码，并保留原始版权声明。'**
  String get aboutLicenseBody;

  /// No description provided for @aboutCreditsTitle.
  ///
  /// In zh, this message translates to:
  /// **'核心鸣谢'**
  String get aboutCreditsTitle;

  /// No description provided for @aboutThanks.
  ///
  /// In zh, this message translates to:
  /// **'感谢所有开源项目与社区贡献者。'**
  String get aboutThanks;

  /// No description provided for @aboutCreditsPcl.
  ///
  /// In zh, this message translates to:
  /// **'Plain Craft Launcher 2 · 界面交互与整合包安装流程参考'**
  String get aboutCreditsPcl;

  /// No description provided for @aboutCreditsHmcl.
  ///
  /// In zh, this message translates to:
  /// **'Hello Minecraft! Launcher · 加载器识别与 Java 管理思路参考'**
  String get aboutCreditsHmcl;

  /// No description provided for @aboutCreditsXmcl.
  ///
  /// In zh, this message translates to:
  /// **'X Minecraft Launcher · 资源管理与视觉设计参考'**
  String get aboutCreditsXmcl;

  /// No description provided for @aboutCreditsBmclapi.
  ///
  /// In zh, this message translates to:
  /// **'提供 Minecraft 资源下载加速服务'**
  String get aboutCreditsBmclapi;

  /// No description provided for @javaEnterPath.
  ///
  /// In zh, this message translates to:
  /// **'请先填写 Java 可执行文件的完整路径。'**
  String get javaEnterPath;

  /// No description provided for @javaPathMissing.
  ///
  /// In zh, this message translates to:
  /// **'Java 可执行文件不存在：{path}'**
  String javaPathMissing(String path);

  /// No description provided for @javaUnrecognized.
  ///
  /// In zh, this message translates to:
  /// **'无法识别该 Java，请确认路径指向 java.exe。'**
  String get javaUnrecognized;

  /// No description provided for @javaAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加到 Java 列表：{path}'**
  String javaAdded(String path);

  /// No description provided for @javaBackToSettings.
  ///
  /// In zh, this message translates to:
  /// **'返回设置'**
  String get javaBackToSettings;

  /// No description provided for @javaPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'Java 管理'**
  String get javaPageTitle;

  /// No description provided for @javaPageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描本机 Java 或手动添加可执行文件。此页面只维护列表，默认使用哪个 Java 请在设置页的 Java 下拉框中选择。'**
  String get javaPageSubtitle;

  /// No description provided for @javaAutoScan.
  ///
  /// In zh, this message translates to:
  /// **'自动扫描'**
  String get javaAutoScan;

  /// No description provided for @javaAddPath.
  ///
  /// In zh, this message translates to:
  /// **'手动添加路径'**
  String get javaAddPath;

  /// No description provided for @javaNoRuntime.
  ///
  /// In zh, this message translates to:
  /// **'未检测到可用 Java，请手动添加路径。'**
  String get javaNoRuntime;

  /// No description provided for @javaNotScanned.
  ///
  /// In zh, this message translates to:
  /// **'尚未扫描 Java，点击“自动扫描”开始。'**
  String get javaNotScanned;

  /// No description provided for @javaRemoveTooltip.
  ///
  /// In zh, this message translates to:
  /// **'从列表移除（不会删除本地文件）'**
  String get javaRemoveTooltip;

  /// No description provided for @javaDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'手动添加 Java 路径'**
  String get javaDialogTitle;

  /// No description provided for @javaDialogHint.
  ///
  /// In zh, this message translates to:
  /// **'填写 java.exe 的完整路径；仅加入列表，不会自动设为默认。'**
  String get javaDialogHint;

  /// No description provided for @javaPathExample.
  ///
  /// In zh, this message translates to:
  /// **'例如 C:\\Program Files\\Java\\jdk-17\\bin\\java.exe'**
  String get javaPathExample;

  /// No description provided for @javaDetecting.
  ///
  /// In zh, this message translates to:
  /// **'检测中…'**
  String get javaDetecting;

  /// No description provided for @actionAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get actionAdd;

  /// No description provided for @authModeLocalProfile.
  ///
  /// In zh, this message translates to:
  /// **'本地档案'**
  String get authModeLocalProfile;

  /// No description provided for @authModeMicrosoft.
  ///
  /// In zh, this message translates to:
  /// **'Microsoft 登录'**
  String get authModeMicrosoft;

  /// No description provided for @authModeThirdParty.
  ///
  /// In zh, this message translates to:
  /// **'第三方验证'**
  String get authModeThirdParty;

  /// No description provided for @authModeLocalProfileDesc.
  ///
  /// In zh, this message translates to:
  /// **'使用本地档案名称进入单人世界，或进入明确允许本地档案的服务器。'**
  String get authModeLocalProfileDesc;

  /// No description provided for @authModeMicrosoftDesc.
  ///
  /// In zh, this message translates to:
  /// **'一键登录：点击后显示设备码，无需任何额外配置。'**
  String get authModeMicrosoftDesc;

  /// No description provided for @authModeThirdPartyDesc.
  ///
  /// In zh, this message translates to:
  /// **'使用 LittleSkin 等 Yggdrasil 服务；启动器内置 authlib-injector。'**
  String get authModeThirdPartyDesc;

  /// No description provided for @loginMethodTitle.
  ///
  /// In zh, this message translates to:
  /// **'登录方式'**
  String get loginMethodTitle;

  /// No description provided for @loginMethodCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前：{mode}'**
  String loginMethodCurrent(String mode);

  /// No description provided for @loginMethodHint.
  ///
  /// In zh, this message translates to:
  /// **'选择后会立即保存。账号资料将在启动游戏时填写；本地档案名称和认证服务器等信息会保存在本机。'**
  String get loginMethodHint;

  /// No description provided for @microsoftDeviceCodeTitle.
  ///
  /// In zh, this message translates to:
  /// **'完成 Microsoft 登录'**
  String get microsoftDeviceCodeTitle;

  /// No description provided for @microsoftDeviceCodeBody.
  ///
  /// In zh, this message translates to:
  /// **'请打开 {uri} 并输入以下代码：\n\n{code}\n\n登录完成后此窗口会自动关闭。'**
  String microsoftDeviceCodeBody(String uri, String code);

  /// No description provided for @microsoftDeviceCodeExpiry.
  ///
  /// In zh, this message translates to:
  /// **'代码约 {minutes} 分钟内有效。'**
  String microsoftDeviceCodeExpiry(int minutes);

  /// No description provided for @actionOpenBrowser.
  ///
  /// In zh, this message translates to:
  /// **'打开浏览器'**
  String get actionOpenBrowser;

  /// No description provided for @microsoftNoOwnership.
  ///
  /// In zh, this message translates to:
  /// **'该 Microsoft 账号未拥有 Minecraft: Java Edition 的有效副本，请购买游戏后再进行在线游玩。'**
  String get microsoftNoOwnership;

  /// No description provided for @localProfileTitle.
  ///
  /// In zh, this message translates to:
  /// **'本地档案'**
  String get localProfileTitle;

  /// No description provided for @localProfileNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'玩家名称'**
  String get localProfileNameLabel;

  /// No description provided for @localProfileNameHint.
  ///
  /// In zh, this message translates to:
  /// **'3 至 16 位字母、数字或下划线'**
  String get localProfileNameHint;

  /// No description provided for @homeQuickJoinNoAccount.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置可用账号，已取消快速加入。请先登录或设置本地档案名称。'**
  String get homeQuickJoinNoAccount;

  /// No description provided for @actionContinue.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get actionContinue;

  /// No description provided for @homeNeedInstalledVersion.
  ///
  /// In zh, this message translates to:
  /// **'请先选择一个本地已安装的 Minecraft 版本。'**
  String get homeNeedInstalledVersion;

  /// No description provided for @homeLaunchBusy.
  ///
  /// In zh, this message translates to:
  /// **'已有启动任务正在进行，请稍后再试。'**
  String get homeLaunchBusy;

  /// No description provided for @homeMissingLaunchConfig.
  ///
  /// In zh, this message translates to:
  /// **'找不到 {version} 的启动配置，请刷新版本列表后重试。'**
  String homeMissingLaunchConfig(String version);

  /// No description provided for @homeJavaNotSelectedQuickJoin.
  ///
  /// In zh, this message translates to:
  /// **'当前客户端未选择 Java，请先在「设置 → Java 管理」中选择 Java 后再快速加入。'**
  String get homeJavaNotSelectedQuickJoin;

  /// No description provided for @homeJavaRuntimeMissing.
  ///
  /// In zh, this message translates to:
  /// **'未找到可用的 Java 运行时：{error}。请先在「设置 → Java 管理」中选择 Java。'**
  String homeJavaRuntimeMissing(String error);

  /// No description provided for @homeJavaNotSelected.
  ///
  /// In zh, this message translates to:
  /// **'当前客户端未选择 Java，请先在「设置 → Java 管理」中选择 Java。'**
  String get homeJavaNotSelected;

  /// No description provided for @homeLaunching.
  ///
  /// In zh, this message translates to:
  /// **'正在启动 Minecraft {version}。'**
  String homeLaunching(String version);

  /// No description provided for @homeLaunchingJoin.
  ///
  /// In zh, this message translates to:
  /// **'正在启动 {version} 并加入 {server}（{address}）。'**
  String homeLaunchingJoin(String version, String server, String address);

  /// No description provided for @homeLaunchFilesUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'启动文件不可用：{error}'**
  String homeLaunchFilesUnavailable(String error);

  /// No description provided for @homeJavaStartFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法启动 Java：{error}。请在「设置 → Java 管理」中选择其他 Java。'**
  String homeJavaStartFailed(String error);

  /// No description provided for @homeAuthConnectFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接认证服务失败：{error}'**
  String homeAuthConnectFailed(String error);

  /// No description provided for @homeAuthRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'认证请求失败：{error}'**
  String homeAuthRequestFailed(String error);

  /// No description provided for @homeAuthTlsFailed.
  ///
  /// In zh, this message translates to:
  /// **'认证服务 TLS 连接失败：{error}'**
  String homeAuthTlsFailed(String error);

  /// No description provided for @homeAuthTimeout.
  ///
  /// In zh, this message translates to:
  /// **'认证请求超时，请检查网络后重试。'**
  String get homeAuthTimeout;

  /// No description provided for @homeAuthlibFailed.
  ///
  /// In zh, this message translates to:
  /// **'内置 authlib-injector 释放失败，请检查启动器目录的写入权限。'**
  String get homeAuthlibFailed;

  /// No description provided for @homeLoginAndLaunch.
  ///
  /// In zh, this message translates to:
  /// **'登录并启动'**
  String get homeLoginAndLaunch;

  /// No description provided for @homeThirdPartyLoginTitle.
  ///
  /// In zh, this message translates to:
  /// **'第三方服务器登录'**
  String get homeThirdPartyLoginTitle;

  /// No description provided for @homeYggdrasilAddress.
  ///
  /// In zh, this message translates to:
  /// **'Yggdrasil API 地址'**
  String get homeYggdrasilAddress;

  /// No description provided for @homeEmailOrUsername.
  ///
  /// In zh, this message translates to:
  /// **'邮箱或用户名'**
  String get homeEmailOrUsername;

  /// No description provided for @homePassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get homePassword;

  /// No description provided for @homeClientFallback.
  ///
  /// In zh, this message translates to:
  /// **'客户端'**
  String get homeClientFallback;

  /// No description provided for @homeClientJavaSaved.
  ///
  /// In zh, this message translates to:
  /// **'已为 {name} 保存独立 Java：{java}'**
  String homeClientJavaSaved(String name, String java);

  /// No description provided for @homeClientJavaFollowGlobal.
  ///
  /// In zh, this message translates to:
  /// **'已将 {name} 的 Java 设置为跟随全局设置。'**
  String homeClientJavaFollowGlobal(String name);

  /// No description provided for @homeClientMemorySaved.
  ///
  /// In zh, this message translates to:
  /// **'已为 {name} 保存独立内存：{memory} GB'**
  String homeClientMemorySaved(String name, String memory);

  /// No description provided for @homeGlobalJavaMissing.
  ///
  /// In zh, this message translates to:
  /// **'全局设置的 Java 已不存在（{path}），请在设置中重新选择。'**
  String homeGlobalJavaMissing(String path);

  /// No description provided for @homeSettingsReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取启动器设置失败：{error}'**
  String homeSettingsReadFailed(String error);

  /// No description provided for @homeSettingsSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存启动器设置失败：{error}'**
  String homeSettingsSaveFailed(String error);

  /// No description provided for @homeJavaAutoRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复自动选择 Java。'**
  String get homeJavaAutoRestored;

  /// No description provided for @homeJavaUnrecognized.
  ///
  /// In zh, this message translates to:
  /// **'无法识别所选 Java，请确认它是可运行的 Java 可执行文件。'**
  String get homeJavaUnrecognized;

  /// No description provided for @homeJavaAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加 Java：{name}'**
  String homeJavaAdded(String name);

  /// No description provided for @homeDebugEnabled.
  ///
  /// In zh, this message translates to:
  /// **'调试日志已开启，并已打开独立日志窗口。'**
  String get homeDebugEnabled;

  /// No description provided for @homeDebugDisabled.
  ///
  /// In zh, this message translates to:
  /// **'调试日志已关闭。'**
  String get homeDebugDisabled;

  /// No description provided for @homePickJavaTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择 Java 可执行文件'**
  String get homePickJavaTitle;

  /// No description provided for @homePickJavaFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法选择 Java 文件：{error}'**
  String homePickJavaFailed(String error);

  /// No description provided for @homeNoClientsFound.
  ///
  /// In zh, this message translates to:
  /// **'尚未发现客户端，请先选择游戏目录或下载 Minecraft。'**
  String get homeNoClientsFound;

  /// No description provided for @homeInstallPickClientTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择安装客户端'**
  String get homeInstallPickClientTitle;

  /// No description provided for @homeInstallPickFabricClientTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择 Fabric 客户端'**
  String get homeInstallPickFabricClientTitle;

  /// No description provided for @homeInstallTargetLabel.
  ///
  /// In zh, this message translates to:
  /// **'将资源安装到'**
  String get homeInstallTargetLabel;

  /// No description provided for @homeRememberAndContinue.
  ///
  /// In zh, this message translates to:
  /// **'记住并继续'**
  String get homeRememberAndContinue;

  /// No description provided for @homeSaveClientSelectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存客户端选择失败：{error}'**
  String homeSaveClientSelectionFailed(String error);

  /// No description provided for @homeNetworkFailed.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败：{error}'**
  String homeNetworkFailed(String error);

  /// No description provided for @homeCatalogReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取 BMCLAPI 失败：{error}'**
  String homeCatalogReadFailed(String error);

  /// No description provided for @homeCatalogTimeout.
  ///
  /// In zh, this message translates to:
  /// **'请求 BMCLAPI 超时，请稍后重试。'**
  String get homeCatalogTimeout;

  /// No description provided for @homeVersionDataInvalid.
  ///
  /// In zh, this message translates to:
  /// **'版本数据格式无效：{error}'**
  String homeVersionDataInvalid(String error);

  /// No description provided for @homeLoaderFetchStatus.
  ///
  /// In zh, this message translates to:
  /// **'获取 {loader} 加载器版本（Minecraft {version}）'**
  String homeLoaderFetchStatus(String loader, String version);

  /// No description provided for @homeLoaderDataInvalid.
  ///
  /// In zh, this message translates to:
  /// **'加载器版本数据格式无效：{error}'**
  String homeLoaderDataInvalid(String error);

  /// No description provided for @homeChooseMinecraftFolder.
  ///
  /// In zh, this message translates to:
  /// **'无法确定默认 Minecraft 目录，请先在版本管理中选择 .minecraft 文件夹。'**
  String get homeChooseMinecraftFolder;

  /// No description provided for @homeDownloadBusy.
  ///
  /// In zh, this message translates to:
  /// **'已有下载任务正在进行，请等待完成或先取消当前任务。'**
  String get homeDownloadBusy;

  /// No description provided for @homeSelectMinecraftVersionFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先选择一个 Minecraft 版本。'**
  String get homeSelectMinecraftVersionFirst;

  /// No description provided for @homeSelectLoaderVersionFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先选择有效的 {loader} 版本。'**
  String homeSelectLoaderVersionFirst(String loader);

  /// No description provided for @homeInvalidClientName.
  ///
  /// In zh, this message translates to:
  /// **'客户端名称无效：不能包含 \\ / : * ? \" < > |，也不能使用系统保留名称。'**
  String get homeInvalidClientName;

  /// No description provided for @homeClientNameExists.
  ///
  /// In zh, this message translates to:
  /// **'客户端名称「{name}」已存在，请换一个名称。'**
  String homeClientNameExists(String name);

  /// No description provided for @homePreparingDownload.
  ///
  /// In zh, this message translates to:
  /// **'准备下载 Minecraft {version}…'**
  String homePreparingDownload(String version);

  /// No description provided for @homeInstallerLabel.
  ///
  /// In zh, this message translates to:
  /// **'{loader} {version} 安装器'**
  String homeInstallerLabel(String loader, String version);

  /// No description provided for @homeInstallFinished.
  ///
  /// In zh, this message translates to:
  /// **'{summary} 安装完成。'**
  String homeInstallFinished(String summary);

  /// No description provided for @homeFabricApiIncomplete.
  ///
  /// In zh, this message translates to:
  /// **' Fabric API 未完成，可在资源页重试。'**
  String get homeFabricApiIncomplete;

  /// No description provided for @homeOptifineClosedRescan.
  ///
  /// In zh, this message translates to:
  /// **'OptiFine 安装器已关闭，请重新扫描版本列表确认安装结果。'**
  String get homeOptifineClosedRescan;

  /// No description provided for @homeInstalledTo.
  ///
  /// In zh, this message translates to:
  /// **'{summary} 已安装到 {path}。'**
  String homeInstalledTo(String summary, String path);

  /// No description provided for @homeOptifineClosedConfirm.
  ///
  /// In zh, this message translates to:
  /// **'OptiFine 安装器已关闭，请确认安装结果后重新扫描版本。'**
  String get homeOptifineClosedConfirm;

  /// No description provided for @homeClientInstallDoneCancelRest.
  ///
  /// In zh, this message translates to:
  /// **'客户端已完成安装，剩余下载已取消。'**
  String get homeClientInstallDoneCancelRest;

  /// No description provided for @homeDownloadCancelled.
  ///
  /// In zh, this message translates to:
  /// **'下载已取消，临时文件已清理。'**
  String get homeDownloadCancelled;

  /// No description provided for @homeDownloadServerError.
  ///
  /// In zh, this message translates to:
  /// **'下载服务器返回错误：{error}'**
  String homeDownloadServerError(String error);

  /// No description provided for @homeDownloadConnectFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载连接失败：{error}'**
  String homeDownloadConnectFailed(String error);

  /// No description provided for @homeInstallTimeout.
  ///
  /// In zh, this message translates to:
  /// **'安装超时，请检查网络代理后重试。'**
  String get homeInstallTimeout;

  /// No description provided for @homeMinecraftDataInvalid.
  ///
  /// In zh, this message translates to:
  /// **'Minecraft 版本数据无效：{error}'**
  String homeMinecraftDataInvalid(String error);

  /// No description provided for @homeWriteFilesFailed.
  ///
  /// In zh, this message translates to:
  /// **'写入 Minecraft 文件失败：{error}'**
  String homeWriteFilesFailed(String error);

  /// No description provided for @homeMinecraftDownloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'Minecraft 下载失败：{error}'**
  String homeMinecraftDownloadFailed(String error);

  /// No description provided for @targetClientTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择目标客户端'**
  String get targetClientTitle;

  /// No description provided for @targetClientSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择要把资源安装到哪个客户端。'**
  String get targetClientSubtitle;

  /// No description provided for @targetClientSubtitleNamed.
  ///
  /// In zh, this message translates to:
  /// **'为「{name}」选择安装位置。'**
  String targetClientSubtitleNamed(String name);

  /// No description provided for @targetClientEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有可用客户端，请先在版本管理中安装客户端。'**
  String get targetClientEmpty;

  /// No description provided for @targetClientPickFolderFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法选择文件夹：{error}'**
  String targetClientPickFolderFailed(String error);

  /// No description provided for @targetClientFolderDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择客户端目录（version 文件夹）'**
  String get targetClientFolderDialogTitle;

  /// No description provided for @targetClientChooseFolder.
  ///
  /// In zh, this message translates to:
  /// **'让我自己决定放在哪'**
  String get targetClientChooseFolder;

  /// No description provided for @targetClientConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认安装'**
  String get targetClientConfirm;

  /// No description provided for @targetClientBadgeCompatible.
  ///
  /// In zh, this message translates to:
  /// **'兼容'**
  String get targetClientBadgeCompatible;

  /// No description provided for @targetClientBadgeVersionMismatch.
  ///
  /// In zh, this message translates to:
  /// **'版本不匹配'**
  String get targetClientBadgeVersionMismatch;

  /// No description provided for @targetClientBadgeLoaderMismatch.
  ///
  /// In zh, this message translates to:
  /// **'加载器不匹配'**
  String get targetClientBadgeLoaderMismatch;

  /// No description provided for @targetClientBadgeBothMismatch.
  ///
  /// In zh, this message translates to:
  /// **'版本与加载器不匹配'**
  String get targetClientBadgeBothMismatch;

  /// No description provided for @targetClientWarning.
  ///
  /// In zh, this message translates to:
  /// **'警告：该模组可能无法在此客户端中正常加载，请确保你使用了信雅互联等跨加载器工具。'**
  String get targetClientWarning;

  /// No description provided for @targetClientSupportVersions.
  ///
  /// In zh, this message translates to:
  /// **'支持版本：{versions}'**
  String targetClientSupportVersions(String versions);

  /// No description provided for @targetClientSupportLoaders.
  ///
  /// In zh, this message translates to:
  /// **'支持加载器：{loaders}'**
  String targetClientSupportLoaders(String loaders);

  /// No description provided for @targetClientSupportNone.
  ///
  /// In zh, this message translates to:
  /// **'该资源未声明版本或加载器限制，所有客户端均可安装。'**
  String get targetClientSupportNone;

  /// No description provided for @commonUnknownVersion.
  ///
  /// In zh, this message translates to:
  /// **'未知版本'**
  String get commonUnknownVersion;

  /// No description provided for @pluginsTitle.
  ///
  /// In zh, this message translates to:
  /// **'插件中心'**
  String get pluginsTitle;

  /// No description provided for @pluginsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'浏览已安装的插件并打开其 JSON 界面。'**
  String get pluginsSubtitle;

  /// No description provided for @pluginsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'尚未安装插件。将插件放入 BGCL/plugins 后点击刷新。'**
  String get pluginsEmpty;

  /// No description provided for @pluginsRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新插件列表'**
  String get pluginsRefresh;

  /// No description provided for @pluginOpenFolder.
  ///
  /// In zh, this message translates to:
  /// **'打开插件目录'**
  String get pluginOpenFolder;

  /// No description provided for @pluginFolderUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'插件目录尚未初始化，请先完成启动器设置。'**
  String get pluginFolderUnavailable;

  /// No description provided for @pluginsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法加载插件：{error}'**
  String pluginsLoadFailed(String error);

  /// No description provided for @pluginsNoUi.
  ///
  /// In zh, this message translates to:
  /// **'该插件没有可用的 UI 文档。'**
  String get pluginsNoUi;

  /// No description provided for @pluginsVersionAuthor.
  ///
  /// In zh, this message translates to:
  /// **'{version} · {author}'**
  String pluginsVersionAuthor(String version, String author);

  /// No description provided for @pluginsPermissions.
  ///
  /// In zh, this message translates to:
  /// **'权限：{permissions}'**
  String pluginsPermissions(String permissions);

  /// No description provided for @pluginBack.
  ///
  /// In zh, this message translates to:
  /// **'返回插件列表'**
  String get pluginBack;

  /// No description provided for @pluginLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在加载插件…'**
  String get pluginLoading;

  /// No description provided for @pluginPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'权限不足：插件未获得 {permission} 权限，无法执行 {action}。'**
  String pluginPermissionDenied(String permission, String action);

  /// No description provided for @pluginActionFailed.
  ///
  /// In zh, this message translates to:
  /// **'插件操作失败：{error}'**
  String pluginActionFailed(String error);

  /// No description provided for @pluginActionInvalid.
  ///
  /// In zh, this message translates to:
  /// **'未知或不支持的插件操作：{action}'**
  String pluginActionInvalid(String action);

  /// No description provided for @pluginFileSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存到插件目录：{path}'**
  String pluginFileSaved(String path);

  /// No description provided for @pluginFileRead.
  ///
  /// In zh, this message translates to:
  /// **'已读取：{path}'**
  String pluginFileRead(String path);

  /// No description provided for @pluginFileDownloaded.
  ///
  /// In zh, this message translates to:
  /// **'下载完成：{path}'**
  String pluginFileDownloaded(String path);

  /// No description provided for @pluginWebviewPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'权限不足：webview 节点需要 webview 权限。'**
  String get pluginWebviewPermissionDenied;

  /// No description provided for @pluginWebviewPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'Webview: {url}（后续版本接入）'**
  String pluginWebviewPlaceholder(String url);

  /// No description provided for @workbenchHubTitle.
  ///
  /// In zh, this message translates to:
  /// **'功能中枢'**
  String get workbenchHubTitle;

  /// No description provided for @workbenchHubSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'插件、系统监控与实用工具的统一入口。'**
  String get workbenchHubSubtitle;

  /// No description provided for @workbenchPluginCenterDescription.
  ///
  /// In zh, this message translates to:
  /// **'浏览、运行并管理已安装的插件界面。'**
  String get workbenchPluginCenterDescription;

  /// No description provided for @workbenchSystemMonitor.
  ///
  /// In zh, this message translates to:
  /// **'系统监控'**
  String get workbenchSystemMonitor;

  /// No description provided for @workbenchSystemMonitorDescription.
  ///
  /// In zh, this message translates to:
  /// **'查看 Windows 内存与 CPU 状态。'**
  String get workbenchSystemMonitorDescription;

  /// No description provided for @workbenchSystemMonitorPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'未来将在此显示 Windows 内存/CPU 状态。'**
  String get workbenchSystemMonitorPlaceholder;

  /// No description provided for @workbenchNbtViewer.
  ///
  /// In zh, this message translates to:
  /// **'NBT 查看器'**
  String get workbenchNbtViewer;

  /// No description provided for @workbenchNbtViewerDescription.
  ///
  /// In zh, this message translates to:
  /// **'快速浏览与校验存档 NBT 数据。'**
  String get workbenchNbtViewerDescription;

  /// No description provided for @workbenchNbtPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'未来将在此浏览与编辑 NBT 数据。'**
  String get workbenchNbtPlaceholder;

  /// No description provided for @workbenchSaveBackup.
  ///
  /// In zh, this message translates to:
  /// **'存档备份中心'**
  String get workbenchSaveBackup;

  /// No description provided for @workbenchSaveBackupDescription.
  ///
  /// In zh, this message translates to:
  /// **'一键备份与恢复本地世界存档'**
  String get workbenchSaveBackupDescription;

  /// No description provided for @workbenchSaveBackupPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'未来将在此支持一键打包备份存档，防止心血丢失。'**
  String get workbenchSaveBackupPlaceholder;

  /// No description provided for @workbenchComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'开发中'**
  String get workbenchComingSoon;

  /// No description provided for @workbenchBack.
  ///
  /// In zh, this message translates to:
  /// **'返回功能中枢'**
  String get workbenchBack;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
