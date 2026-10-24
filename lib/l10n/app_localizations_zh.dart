// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Baogan Craft Launcher';

  @override
  String get navGroupLauncher => '启动器';

  @override
  String get navHome => '主页';

  @override
  String get navVersions => '版本管理';

  @override
  String get navDownloads => '资源下载';

  @override
  String get navSettings => '设置';

  @override
  String get navTools => '实用工具';

  @override
  String get navTasks => '下载任务';

  @override
  String get navWorkbench => '工作台';

  @override
  String get settingsLanguage => '语言 (Language)';

  @override
  String get settingsLanguageHint => '切换后立即生效，并保存到本机。';

  @override
  String get settingsLanguageZh => '简体中文';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get setupTitle => '选择启动器根目录';

  @override
  String get setupSubtitle => '首次启动必须完成目录设置，配置完成前不会创建日志、数据库或缓存文件。';

  @override
  String get setupDirectoryExampleTitle => '例如选择 E:\\Games 后，将创建：';

  @override
  String get setupInvalidDirectory => '必须选择一个有效的启动器根目录才能继续。';

  @override
  String setupCreateFailed(String error) {
    return '无法创建启动器目录：$error';
  }

  @override
  String get setupWritableHint => '请确认启动器程序目录可写，且所选磁盘有足够空间。';

  @override
  String setupPickerUnavailable(String error) {
    return '文件夹选择器无法打开（$error）。请直接输入根目录的完整路径。';
  }

  @override
  String get setupPathHint => '例如 E:\\Games';

  @override
  String get setupUseThisFolder => '使用此目录';

  @override
  String get setupSelectFolder => '选择根目录';

  @override
  String get setupCreatingFolder => '正在创建目录…';

  @override
  String get setupCancelHint => '取消文件夹选择不会进入主界面，请重新选择。';

  @override
  String get actionCancel => '取消';

  @override
  String get actionMinimize => '最小化';

  @override
  String get actionClose => '关闭';

  @override
  String get networkCheckTitle => '网络环境检测失败';

  @override
  String get networkCheckMessage => '无法确认当前网络环境，下载功能暂不可用。请检查网络或系统代理设置后重试。';

  @override
  String get networkCheckRetryFailed => '网络检测仍然失败，请检查网络或系统代理设置后重试。';

  @override
  String networkStartFailed(String error) {
    return '启动失败：$error';
  }

  @override
  String get networkChecking => '正在检测…';

  @override
  String get actionRetry => '重试';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowRestore => '还原';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowClose => '关闭';

  @override
  String get homeCurrentClient => '当前客户端';

  @override
  String get homeScanningClients => '正在扫描客户端…';

  @override
  String get homeNoClientSelected => '尚未选择客户端';

  @override
  String get homeSelectClientHint => '点击下方客户端卡片选择要启动的客户端版本。';

  @override
  String get commonUnknown => '未知';

  @override
  String get homeLoginMethod => '登录方式';

  @override
  String get homeCurrentAccount => '当前账号';

  @override
  String homeManageAccount(String type) {
    return '$type · 点击管理账号';
  }

  @override
  String homePlayerName(String name) {
    return '玩家：$name';
  }

  @override
  String get homeMicrosoftHint => '点击后立即显示设备码，登录 Microsoft 账号';

  @override
  String homeAuthSwitched(String mode) {
    return '登录方式已切换为 $mode。';
  }

  @override
  String homeMicrosoftSignedIn(String name) {
    return '已登录 Microsoft 账号：$name，启动时将直接使用该账号。';
  }

  @override
  String get homeSelectClient => '选择客户端';

  @override
  String get homeClickSelectClient => '点击选择已安装客户端';

  @override
  String get homeVersionUnknown => '版本未知';

  @override
  String get homeSwitch => '切换';

  @override
  String get homeViewClientConfig => '查看客户端配置';

  @override
  String get homeSelectClientFirst => '请先选择一个客户端。';

  @override
  String get homeVersionTypeUnknown => '版本类型未知';

  @override
  String get homeLaunchGame => '开始游戏';

  @override
  String get homeNoClient => '未选择客户端';

  @override
  String get versionVanilla => '原版';

  @override
  String homeJavaAutoDetected(int count) {
    return '自动匹配（已检测 $count 个）';
  }

  @override
  String get homeJavaAutoLaunch => '启动时自动匹配';

  @override
  String homeLocalProfile(String name) {
    return '本地档案 · $name';
  }

  @override
  String get homeMicrosoftAccount => 'Microsoft 登录';

  @override
  String get homeThirdPartyAccount => '第三方验证';

  @override
  String get accountManagerTitle => '账号管理';

  @override
  String accountCount(int count) {
    return '共 $count 个账号';
  }

  @override
  String get accountManagerEmpty => '还没有保存的账号。点击下方按钮添加 Microsoft、本地档案或第三方账号。';

  @override
  String get accountAddNew => '添加新账号';

  @override
  String get accountCurrent => '当前使用';

  @override
  String get accountRemoveTitle => '移除账号';

  @override
  String accountRemoveConfirm(String name) {
    return '确定要从启动器移除「$name」吗？';
  }

  @override
  String get accountRemoveHint => '本机保存的加密登录凭据也会一并清除。';

  @override
  String get actionRemove => '移除';

  @override
  String get settingsSubtitle => '自定义启动器外观与使用体验。';

  @override
  String get settingsSectionGameDefaults => '全局游戏默认设置';

  @override
  String get settingsSectionChannels => '游戏资源获取渠道';

  @override
  String get settingsSectionAppearance => '个性化与主题';

  @override
  String get settingsSectionJava => 'Java 管理';

  @override
  String get settingsSectionDebug => '调试与日志';

  @override
  String get settingsSectionAbout => '关于与鸣谢';

  @override
  String settingsJavaRemoved(String path) {
    return '已从 Java 列表移除：$path';
  }

  @override
  String get settingsThemeMode => '主题模式';

  @override
  String get settingsThemeModeHint => '自动模式根据本地时间和日出日落切换主题。';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsThemeLight => '亮色';

  @override
  String get settingsThemeAuto => '日出日落自动';

  @override
  String settingsTimeZone(String offset, String longitude) {
    return '本地时区 UTC$offset · 推算经度 $longitude°';
  }

  @override
  String get settingsSolarApprox =>
      '位置仅按时区估算（纬度按赤道近似），仅供参考；联网失败时使用 06:30 / 18:30。';

  @override
  String settingsSunriseSunset(String sunrise, String sunset, String source) {
    return '日出 $sunrise  ·  日落 $sunset  ·  $source';
  }

  @override
  String get settingsSolarOnline => '联网获取';

  @override
  String get settingsSolarDefault => '默认时间';

  @override
  String settingsSolarError(String error) {
    return '$error，当前使用 06:30 / 18:30。';
  }

  @override
  String get settingsCheckingSolar => '正在检测日出日落时间…';

  @override
  String get settingsRefreshSolar => '刷新日出日落';

  @override
  String get settingsWallpaper => '壁纸';

  @override
  String get settingsWallpaperHint => '分别为亮色和深色主题设置壁纸，切换主题时自动切换对应图片。';

  @override
  String get settingsDarkWallpaper => '深色模式壁纸';

  @override
  String get settingsLightWallpaper => '亮色模式壁纸';

  @override
  String get settingsWallpaperNone => '尚未选择；未设置时会暂用另一主题的壁纸。';

  @override
  String get settingsWallpaperEffect => '壁纸效果';

  @override
  String get settingsWallpaperCover => '铺满';

  @override
  String get settingsWallpaperStretch => '拉伸';

  @override
  String get settingsWallpaperZoom => '放大';

  @override
  String get settingsChooseImage => '选择图片';

  @override
  String get settingsChangeImage => '更换图片';

  @override
  String get settingsRecrop => '重新裁切';

  @override
  String get settingsResetWallpaper => '恢复默认';

  @override
  String settingsResetDone(String mode) {
    return '已恢复$mode模式默认背景。';
  }

  @override
  String get settingsDebugMode => '调试模式';

  @override
  String get settingsDebugDescription =>
      '默认开启。记录启动器操作、下载、版本扫描、启动参数和游戏进程输出；日志窗口独立于启动器运行，便于观察完整过程。';

  @override
  String get settingsLogNotReady => '日志文件尚未初始化。';

  @override
  String get settingsOpenLogWindow => '打开日志窗口';

  @override
  String get settingsOpenLogFolder => '打开日志文件夹';

  @override
  String get settingsRecordState => '记录当前状态';

  @override
  String get settingsCloseLogWindow => '关闭日志窗口';

  @override
  String settingsOpenLogFailed(String error) {
    return '无法打开日志文件夹：$error';
  }

  @override
  String settingsOpenBrowserFailed(String error) {
    return '无法打开浏览器：$error';
  }

  @override
  String aboutVersion(String version) {
    return 'Baogan Craft Launcher · 版本 $version';
  }

  @override
  String get aboutLicenseDescription =>
      '本项目基于 GPLv3 协议开源，感谢 PCL2、HMCL、XMCL 与 BMCLAPI 等开源项目。';

  @override
  String get aboutLicenseButton => '开源协议与鸣谢';

  @override
  String get aboutRepoButton => 'GitHub 仓库';

  @override
  String get actionDefault => '默认';

  @override
  String get channelClientSource => '客户端下载源';

  @override
  String get channelClientSourceHint => '游戏文件下载来源；版本与加载器信息始终由 BMCLAPI 提供。';

  @override
  String get channelModSource => '模组资源源';

  @override
  String get channelMcimHint =>
      '启用 MCIM 后 CurseForge 请求会走 mod.mcimirror.top 镜像。';

  @override
  String get channelAggregate => '聚合搜索偏好';

  @override
  String get channelAggregateHint =>
      '同一模组同时出现在 Modrinth 与 CurseForge 时，只保留偏向平台的一条。';

  @override
  String get sourceMojang => 'Mojang 官方';

  @override
  String get sourceBmclapi => 'BMCLAPI 加速';

  @override
  String get sourceMcim => 'MCIM 镜像站';

  @override
  String get aggregateBalanced => '全部显示';

  @override
  String get aggregateModrinth => '偏向 Modrinth';

  @override
  String get aggregateCurseForge => '偏向 CurseForge';

  @override
  String get settingsDefaultsHint => '这些默认值用于新建客户端；已单独配置的客户端仍使用各自的设置。';

  @override
  String get settingsDefaultJava => '默认 Java';

  @override
  String get settingsJavaAutoChoice => '根据游戏版本自动设定';

  @override
  String get settingsJavaAutoHint => '选择「根据游戏版本自动设定」时，启动器会按客户端声明的 Java 版本自动匹配。';

  @override
  String get settingsDefaultMemory => '默认内存分配';

  @override
  String get settingsMemoryPlaceholder => '仅用于界面占位，尚未写入启动参数。';

  @override
  String get javaNoneDetected => '尚未检测到 Java。点击「管理 Java」扫描本机或手动添加。';

  @override
  String get javaCurrent => '当前使用';

  @override
  String get actionManageJava => '管理 Java';

  @override
  String aboutVersionLabel(String version) {
    return '版本 $version · GPLv3 开源';
  }

  @override
  String get aboutLicenseTitle => '开源协议';

  @override
  String get aboutLicenseBody =>
      '本项目基于 GPLv3 协议开源：你可以自由使用、修改与分发，但衍生作品必须同样以 GPLv3 开放源代码，并保留原始版权声明。';

  @override
  String get aboutCreditsTitle => '核心鸣谢';

  @override
  String get aboutThanks => '感谢所有开源项目与社区贡献者。';

  @override
  String get aboutCreditsPcl => 'Plain Craft Launcher 2 · 界面交互与整合包安装流程参考';

  @override
  String get aboutCreditsHmcl =>
      'Hello Minecraft! Launcher · 加载器识别与 Java 管理思路参考';

  @override
  String get aboutCreditsXmcl => 'X Minecraft Launcher · 资源管理与视觉设计参考';

  @override
  String get aboutCreditsBmclapi => '提供 Minecraft 资源下载加速服务';

  @override
  String get javaEnterPath => '请先填写 Java 可执行文件的完整路径。';

  @override
  String javaPathMissing(String path) {
    return 'Java 可执行文件不存在：$path';
  }

  @override
  String get javaUnrecognized => '无法识别该 Java，请确认路径指向 java.exe。';

  @override
  String javaAdded(String path) {
    return '已添加到 Java 列表：$path';
  }

  @override
  String get javaBackToSettings => '返回设置';

  @override
  String get javaPageTitle => 'Java 管理';

  @override
  String get javaPageSubtitle =>
      '扫描本机 Java 或手动添加可执行文件。此页面只维护列表，默认使用哪个 Java 请在设置页的 Java 下拉框中选择。';

  @override
  String get javaAutoScan => '自动扫描';

  @override
  String get javaAddPath => '手动添加路径';

  @override
  String get javaNoRuntime => '未检测到可用 Java，请手动添加路径。';

  @override
  String get javaNotScanned => '尚未扫描 Java，点击“自动扫描”开始。';

  @override
  String get javaRemoveTooltip => '从列表移除（不会删除本地文件）';

  @override
  String get javaDialogTitle => '手动添加 Java 路径';

  @override
  String get javaDialogHint => '填写 java.exe 的完整路径；仅加入列表，不会自动设为默认。';

  @override
  String get javaPathExample =>
      '例如 C:\\Program Files\\Java\\jdk-17\\bin\\java.exe';

  @override
  String get javaDetecting => '检测中…';

  @override
  String get actionAdd => '添加';

  @override
  String get authModeLocalProfile => '本地档案';

  @override
  String get authModeMicrosoft => 'Microsoft 登录';

  @override
  String get authModeThirdParty => '第三方验证';

  @override
  String get authModeLocalProfileDesc => '使用本地档案名称进入单人世界，或进入明确允许本地档案的服务器。';

  @override
  String get authModeMicrosoftDesc => '一键登录：点击后显示设备码，无需任何额外配置。';

  @override
  String get authModeThirdPartyDesc =>
      '使用 LittleSkin 等 Yggdrasil 服务；启动器内置 authlib-injector。';

  @override
  String get loginMethodTitle => '登录方式';

  @override
  String loginMethodCurrent(String mode) {
    return '当前：$mode';
  }

  @override
  String get loginMethodHint => '选择后会立即保存。账号资料将在启动游戏时填写；本地档案名称和认证服务器等信息会保存在本机。';

  @override
  String get microsoftDeviceCodeTitle => '完成 Microsoft 登录';

  @override
  String microsoftDeviceCodeBody(String uri, String code) {
    return '请打开 $uri 并输入以下代码：\n\n$code\n\n登录完成后此窗口会自动关闭。';
  }

  @override
  String microsoftDeviceCodeExpiry(int minutes) {
    return '代码约 $minutes 分钟内有效。';
  }

  @override
  String get actionOpenBrowser => '打开浏览器';

  @override
  String get microsoftNoOwnership =>
      '该 Microsoft 账号未拥有 Minecraft: Java Edition 的有效副本，请购买游戏后再进行在线游玩。';

  @override
  String get localProfileTitle => '本地档案';

  @override
  String get localProfileNameLabel => '玩家名称';

  @override
  String get localProfileNameHint => '3 至 16 位字母、数字或下划线';

  @override
  String get homeQuickJoinNoAccount => '尚未配置可用账号，已取消快速加入。请先登录或设置本地档案名称。';

  @override
  String get actionContinue => '继续';

  @override
  String get homeNeedInstalledVersion => '请先选择一个本地已安装的 Minecraft 版本。';

  @override
  String get homeLaunchBusy => '已有启动任务正在进行，请稍后再试。';

  @override
  String homeMissingLaunchConfig(String version) {
    return '找不到 $version 的启动配置，请刷新版本列表后重试。';
  }

  @override
  String get homeJavaNotSelectedQuickJoin =>
      '当前客户端未选择 Java，请先在「设置 → Java 管理」中选择 Java 后再快速加入。';

  @override
  String homeJavaRuntimeMissing(String error) {
    return '未找到可用的 Java 运行时：$error。请先在「设置 → Java 管理」中选择 Java。';
  }

  @override
  String get homeJavaNotSelected => '当前客户端未选择 Java，请先在「设置 → Java 管理」中选择 Java。';

  @override
  String homeLaunching(String version) {
    return '正在启动 Minecraft $version。';
  }

  @override
  String homeLaunchingJoin(String version, String server, String address) {
    return '正在启动 $version 并加入 $server（$address）。';
  }

  @override
  String homeLaunchFilesUnavailable(String error) {
    return '启动文件不可用：$error';
  }

  @override
  String homeJavaStartFailed(String error) {
    return '无法启动 Java：$error。请在「设置 → Java 管理」中选择其他 Java。';
  }

  @override
  String homeAuthConnectFailed(String error) {
    return '连接认证服务失败：$error';
  }

  @override
  String homeAuthRequestFailed(String error) {
    return '认证请求失败：$error';
  }

  @override
  String homeAuthTlsFailed(String error) {
    return '认证服务 TLS 连接失败：$error';
  }

  @override
  String get homeAuthTimeout => '认证请求超时，请检查网络后重试。';

  @override
  String get homeAuthlibFailed => '内置 authlib-injector 释放失败，请检查启动器目录的写入权限。';

  @override
  String get homeLoginAndLaunch => '登录并启动';

  @override
  String get homeThirdPartyLoginTitle => '第三方服务器登录';

  @override
  String get homeYggdrasilAddress => 'Yggdrasil API 地址';

  @override
  String get homeEmailOrUsername => '邮箱或用户名';

  @override
  String get homePassword => '密码';

  @override
  String get homeClientFallback => '客户端';

  @override
  String homeClientJavaSaved(String name, String java) {
    return '已为 $name 保存独立 Java：$java';
  }

  @override
  String homeClientJavaFollowGlobal(String name) {
    return '已将 $name 的 Java 设置为跟随全局设置。';
  }

  @override
  String homeClientMemorySaved(String name, String memory) {
    return '已为 $name 保存独立内存：$memory GB';
  }

  @override
  String homeGlobalJavaMissing(String path) {
    return '全局设置的 Java 已不存在（$path），请在设置中重新选择。';
  }

  @override
  String homeSettingsReadFailed(String error) {
    return '读取启动器设置失败：$error';
  }

  @override
  String homeSettingsSaveFailed(String error) {
    return '保存启动器设置失败：$error';
  }

  @override
  String get homeJavaAutoRestored => '已恢复自动选择 Java。';

  @override
  String get homeJavaUnrecognized => '无法识别所选 Java，请确认它是可运行的 Java 可执行文件。';

  @override
  String homeJavaAdded(String name) {
    return '已添加 Java：$name';
  }

  @override
  String get homeDebugEnabled => '调试日志已开启，并已打开独立日志窗口。';

  @override
  String get homeDebugDisabled => '调试日志已关闭。';

  @override
  String get homePickJavaTitle => '选择 Java 可执行文件';

  @override
  String homePickJavaFailed(String error) {
    return '无法选择 Java 文件：$error';
  }

  @override
  String get homeNoClientsFound => '尚未发现客户端，请先选择游戏目录或下载 Minecraft。';

  @override
  String get homeInstallPickClientTitle => '选择安装客户端';

  @override
  String get homeInstallPickFabricClientTitle => '选择 Fabric 客户端';

  @override
  String get homeInstallTargetLabel => '将资源安装到';

  @override
  String get homeRememberAndContinue => '记住并继续';

  @override
  String homeSaveClientSelectionFailed(String error) {
    return '保存客户端选择失败：$error';
  }

  @override
  String homeNetworkFailed(String error) {
    return '网络连接失败：$error';
  }

  @override
  String homeCatalogReadFailed(String error) {
    return '读取 BMCLAPI 失败：$error';
  }

  @override
  String get homeCatalogTimeout => '请求 BMCLAPI 超时，请稍后重试。';

  @override
  String homeVersionDataInvalid(String error) {
    return '版本数据格式无效：$error';
  }

  @override
  String homeLoaderFetchStatus(String loader, String version) {
    return '获取 $loader 加载器版本（Minecraft $version）';
  }

  @override
  String homeLoaderDataInvalid(String error) {
    return '加载器版本数据格式无效：$error';
  }

  @override
  String get homeChooseMinecraftFolder =>
      '无法确定默认 Minecraft 目录，请先在版本管理中选择 .minecraft 文件夹。';

  @override
  String get homeDownloadBusy => '已有下载任务正在进行，请等待完成或先取消当前任务。';

  @override
  String get homeSelectMinecraftVersionFirst => '请先选择一个 Minecraft 版本。';

  @override
  String homeSelectLoaderVersionFirst(String loader) {
    return '请先选择有效的 $loader 版本。';
  }

  @override
  String get homeInvalidClientName =>
      '客户端名称无效：不能包含 \\ / : * ? \" < > |，也不能使用系统保留名称。';

  @override
  String homeClientNameExists(String name) {
    return '客户端名称「$name」已存在，请换一个名称。';
  }

  @override
  String homePreparingDownload(String version) {
    return '准备下载 Minecraft $version…';
  }

  @override
  String homeInstallerLabel(String loader, String version) {
    return '$loader $version 安装器';
  }

  @override
  String homeInstallFinished(String summary) {
    return '$summary 安装完成。';
  }

  @override
  String get homeFabricApiIncomplete => ' Fabric API 未完成，可在资源页重试。';

  @override
  String get homeOptifineClosedRescan => 'OptiFine 安装器已关闭，请重新扫描版本列表确认安装结果。';

  @override
  String homeInstalledTo(String summary, String path) {
    return '$summary 已安装到 $path。';
  }

  @override
  String get homeOptifineClosedConfirm => 'OptiFine 安装器已关闭，请确认安装结果后重新扫描版本。';

  @override
  String get homeClientInstallDoneCancelRest => '客户端已完成安装，剩余下载已取消。';

  @override
  String get homeDownloadCancelled => '下载已取消，临时文件已清理。';

  @override
  String homeDownloadServerError(String error) {
    return '下载服务器返回错误：$error';
  }

  @override
  String homeDownloadConnectFailed(String error) {
    return '下载连接失败：$error';
  }

  @override
  String get homeInstallTimeout => '安装超时，请检查网络代理后重试。';

  @override
  String homeMinecraftDataInvalid(String error) {
    return 'Minecraft 版本数据无效：$error';
  }

  @override
  String homeWriteFilesFailed(String error) {
    return '写入 Minecraft 文件失败：$error';
  }

  @override
  String homeMinecraftDownloadFailed(String error) {
    return 'Minecraft 下载失败：$error';
  }

  @override
  String get targetClientTitle => '选择目标客户端';

  @override
  String get targetClientSubtitle => '选择要把资源安装到哪个客户端。';

  @override
  String targetClientSubtitleNamed(String name) {
    return '为「$name」选择安装位置。';
  }

  @override
  String get targetClientEmpty => '还没有可用客户端，请先在版本管理中安装客户端。';

  @override
  String targetClientPickFolderFailed(String error) {
    return '无法选择文件夹：$error';
  }

  @override
  String get targetClientFolderDialogTitle => '选择客户端目录（version 文件夹）';

  @override
  String get targetClientChooseFolder => '让我自己决定放在哪';

  @override
  String get targetClientConfirm => '确认安装';

  @override
  String get targetClientBadgeCompatible => '兼容';

  @override
  String get targetClientBadgeVersionMismatch => '版本不匹配';

  @override
  String get targetClientBadgeLoaderMismatch => '加载器不匹配';

  @override
  String get targetClientBadgeBothMismatch => '版本与加载器不匹配';

  @override
  String get targetClientWarning => '警告：该模组可能无法在此客户端中正常加载，请确保你使用了信雅互联等跨加载器工具。';

  @override
  String targetClientSupportVersions(String versions) {
    return '支持版本：$versions';
  }

  @override
  String targetClientSupportLoaders(String loaders) {
    return '支持加载器：$loaders';
  }

  @override
  String get targetClientSupportNone => '该资源未声明版本或加载器限制，所有客户端均可安装。';

  @override
  String get commonUnknownVersion => '未知版本';

  @override
  String get pluginsTitle => '插件中心';

  @override
  String get pluginsSubtitle => '浏览已安装的插件并打开其 JSON 界面。';

  @override
  String get pluginsEmpty => '尚未安装插件。将插件放入 BGCL/plugins 后点击刷新。';

  @override
  String get pluginsRefresh => '刷新插件列表';

  @override
  String get pluginOpenFolder => '打开插件目录';

  @override
  String get pluginFolderUnavailable => '插件目录尚未初始化，请先完成启动器设置。';

  @override
  String pluginsLoadFailed(String error) {
    return '无法加载插件：$error';
  }

  @override
  String get pluginsNoUi => '该插件没有可用的 UI 文档。';

  @override
  String pluginsVersionAuthor(String version, String author) {
    return '$version · $author';
  }

  @override
  String pluginsPermissions(String permissions) {
    return '权限：$permissions';
  }

  @override
  String get pluginBack => '返回插件列表';

  @override
  String get pluginLoading => '正在加载插件…';

  @override
  String pluginPermissionDenied(String permission, String action) {
    return '权限不足：插件未获得 $permission 权限，无法执行 $action。';
  }

  @override
  String pluginActionFailed(String error) {
    return '插件操作失败：$error';
  }

  @override
  String pluginActionInvalid(String action) {
    return '未知或不支持的插件操作：$action';
  }

  @override
  String pluginFileSaved(String path) {
    return '已保存到插件目录：$path';
  }

  @override
  String pluginFileRead(String path) {
    return '已读取：$path';
  }

  @override
  String pluginFileDownloaded(String path) {
    return '下载完成：$path';
  }

  @override
  String get pluginWebviewPermissionDenied => '权限不足：webview 节点需要 webview 权限。';

  @override
  String pluginWebviewPlaceholder(String url) {
    return 'Webview: $url（后续版本接入）';
  }

  @override
  String get workbenchHubTitle => '功能中枢';

  @override
  String get workbenchHubSubtitle => '插件、系统监控与实用工具的统一入口。';

  @override
  String get workbenchPluginCenterDescription => '浏览、运行并管理已安装的插件界面。';

  @override
  String get workbenchSystemMonitor => '系统监控';

  @override
  String get workbenchSystemMonitorDescription => '查看 Windows 内存与 CPU 状态。';

  @override
  String get workbenchSystemMonitorPlaceholder => '未来将在此显示 Windows 内存/CPU 状态。';

  @override
  String get workbenchNbtViewer => 'NBT 查看器';

  @override
  String get workbenchNbtViewerDescription => '快速浏览与校验存档 NBT 数据。';

  @override
  String get workbenchNbtPlaceholder => '未来将在此浏览与编辑 NBT 数据。';

  @override
  String get workbenchSaveBackup => '存档备份中心';

  @override
  String get workbenchSaveBackupDescription => '一键备份与恢复本地世界存档';

  @override
  String get workbenchSaveBackupPlaceholder => '未来将在此支持一键打包备份存档，防止心血丢失。';

  @override
  String get workbenchComingSoon => '开发中';

  @override
  String get workbenchBack => '返回功能中枢';
}
