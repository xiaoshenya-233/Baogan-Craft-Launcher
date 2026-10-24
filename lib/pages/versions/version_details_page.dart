import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/installer/client_settings.dart';
import '../../services/installer/version_models.dart';
import '../../services/java/java_service.dart';
import '../../services/launcher/server_service.dart';
import '../../services/network/api_service.dart';
import '../../widgets/category_anchor_bar.dart';
import '../../widgets/launcher/launcher_common.dart';
import '../launcher/controllers/java_environment_controller.dart';
import '../launcher/launcher_palette.dart';
import 'controllers/version_catalog_controller.dart';
import '../launcher/controllers/launcher_environment_controller.dart';
import 'widgets/game_resources_section.dart';
import 'widgets/server_list_section.dart';
import 'widgets/version_icon_editor.dart';

/// Detail view of one client: actions, Java, memory and mods.
class VersionDetailsPage extends StatelessWidget {
  const VersionDetailsPage({
    super.key,
    required this.version,
    required this.catalog,
    required this.environment,
    required this.java,
    required this.palette,
    required this.isDark,
    required this.isDownloadLocked,
    required this.versionFilter,
    required this.versionSearchQuery,
    required this.isLoadingManagedMods,
    required this.managedMods,
    required this.maintenanceStatus,
    required this.maintenanceRunning,
    required this.isDeletingVersion,
    required this.isInstallingMinecraft,
    required this.isDownloadingResources,
    required this.memoryGb,
    required this.maxMemoryGb,
    required this.memoryError,
    required this.setPageState,
    required this.onVersionFilterChanged,
    required this.onSearchChanged,
    required this.onImportModpack,
    required this.onAddFolder,
    required this.onShowSourcePicker,
    required this.onDownloadMinecraft,
    required this.onReload,
    required this.onOpenDetails,
    required this.onDeleteVersion,
    required this.onRepairVersion,
    required this.onReinstallVersion,
    required this.onShowLogs,
    required this.onOpenFolder,
    required this.onLoadManagedMods,
    required this.onToggleManagedMod,
    required this.onDeleteManagedMod,
    required this.onCloseDetails,
    required this.clientSettings,
    required this.onClientJavaChanged,
    required this.onClientMemoryChanged,
    required this.onMessage,
    required this.onFastJoinServer,
    required this.onCancelMaintenance,
    required this.onOpenResourceSearch,
    this.minecraftInstallStatus,
    this.minecraftInstallError,
    this.maintenanceCancellable = false,
  });

  final LauncherVersion version;

  final VersionCatalogController catalog;
  final LauncherEnvironmentController environment;
  final JavaEnvironmentController java;
  final LauncherPalette palette;
  final bool isDark;
  final bool isDownloadLocked;
  final int versionFilter;
  final String versionSearchQuery;
  final bool isLoadingManagedMods;
  final List<ManagedMod> managedMods;
  final String? maintenanceStatus;
  final bool maintenanceRunning;
  final bool isDeletingVersion;
  final bool isInstallingMinecraft;
  final bool isDownloadingResources;
  final double memoryGb;
  final double maxMemoryGb;
  final String? memoryError;
  final void Function(VoidCallback) setPageState;
  final ValueChanged<int> onVersionFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onImportModpack;
  final VoidCallback onAddFolder;
  final VoidCallback onShowSourcePicker;
  final VoidCallback onDownloadMinecraft;
  final VoidCallback onReload;
  final ValueChanged<LauncherVersion> onOpenDetails;
  final ValueChanged<LauncherVersion> onDeleteVersion;
  final ValueChanged<LauncherVersion> onRepairVersion;
  final ValueChanged<LauncherVersion> onReinstallVersion;
  final ValueChanged<LauncherVersion> onShowLogs;
  final ValueChanged<LauncherVersion> onOpenFolder;
  final ValueChanged<LauncherVersion> onLoadManagedMods;
  final ValueChanged<ManagedMod> onToggleManagedMod;
  final ValueChanged<ManagedMod> onDeleteManagedMod;
  final VoidCallback onCloseDetails;
  final ClientLaunchSettings clientSettings;
  final ValueChanged<String> onClientJavaChanged;
  final ValueChanged<double> onClientMemoryChanged;
  final ValueChanged<String> onMessage;
  final Future<void> Function(LauncherVersion version, ServerEntry server)
  onFastJoinServer;
  final VoidCallback onCancelMaintenance;
  final VoidCallback onOpenResourceSearch;
  final String? minecraftInstallStatus;
  final String? minecraftInstallError;
  final bool maintenanceCancellable;

  static const _green = Color(0xFF8BC34A);

  static const List<String> _sectionTitles = <String>[
    '客户端信息',
    '管理',
    'Java 与内存分配',
    '游戏资源',
    '网络服务器',
  ];

  static final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{
    for (final title in _sectionTitles) title: GlobalKey(debugLabel: title),
  };
  Color get _muted => palette.muted;
  Color get _panelColor => palette.panelColor;
  Color get _panelBorderColor => palette.panelBorderColor;
  Color get _panelAccentColor => palette.panelAccentColor;
  Color get _selectedForegroundColor => palette.selectedForegroundColor;
  Color get _buttonForeground => palette.buttonForeground;
  bool get _usesDarkPalette => isDark;
  bool get _isDeletingVersion => isDeletingVersion;
  bool get _canRunVersionMaintenance =>
      !maintenanceRunning &&
      !isInstallingMinecraft &&
      !isDownloadingResources &&
      !isDeletingVersion;
  List<JavaRuntime> get _javaRuntimes => java.runtimes;

  /// Memory shown on the slider: the client override, else the global default.
  double get _effectiveMemoryGb => (clientSettings.ownMemoryGb ?? memoryGb)
      .clamp(1, math.max(2, maxMemoryGb));

  Widget _translucentButton(Widget button, {double radius = 10}) {
    return TranslucentButtonSurface(radius: radius, child: button);
  }

  Widget _buildVersionTag(String label) {
    final appearance = resourceTagAppearance(label, dark: _usesDarkPalette);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: appearance.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: appearance.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: appearance.foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  ButtonStyle _compactManagementButtonStyle({Color? foregroundColor}) {
    return OutlinedButton.styleFrom(
      foregroundColor: foregroundColor,
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildDetailRow(String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 13),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 12, color: _muted)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionDetails(LauncherVersion version) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final content = SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 36,
            24,
            compact ? 20 : 36,
            96,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _translucentButton(
                    OutlinedButton.icon(
                      onPressed: onCloseDetails,
                      icon: Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text('返回版本管理'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _buttonForeground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      VersionIconEditor(version: version, onMessage: onMessage),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              version.name,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 7,
                              runSpacing: 6,
                              children: [
                                _buildVersionTag(
                                  'Minecraft ${version.minecraftVersion ?? '未知'}',
                                ),
                                _buildVersionTag(_loaderDisplay(version)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildBgucSection(
                    title: '客户端信息',
                    anchor: '客户端信息',
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      children: [
                        _buildDetailRow('客户端名称', version.name),
                        _buildDetailRow(
                          'Minecraft 版本',
                          version.minecraftVersion ?? '未知',
                        ),
                        _buildDetailRow('客户端来源', version.minecraftPath),
                        _buildDetailRow(
                          '模组加载器',
                          _loaderDisplay(version),
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildBgucSection(
                    title: '管理',
                    anchor: '管理',
                    icon: Icons.manage_accounts_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _translucentButton(
                              OutlinedButton.icon(
                                onPressed: _canRunVersionMaintenance
                                    ? () => onRepairVersion(version)
                                    : null,
                                icon: Icon(
                                  Icons.download_for_offline_outlined,
                                  size: 17,
                                ),
                                label: Text('修复/补全核心文件'),
                                style: _compactManagementButtonStyle(),
                              ),
                            ),
                            _translucentButton(
                              OutlinedButton.icon(
                                onPressed: () => onShowLogs(version),
                                icon: Icon(Icons.article_outlined, size: 17),
                                label: Text('游戏日志'),
                                style: _compactManagementButtonStyle(),
                              ),
                            ),
                            _translucentButton(
                              OutlinedButton.icon(
                                onPressed: _canRunVersionMaintenance
                                    ? () => onReinstallVersion(version)
                                    : null,
                                icon: Icon(Icons.build_outlined, size: 17),
                                label: Text('重构/重装客户端'),
                                style: _compactManagementButtonStyle(),
                              ),
                            ),
                            _translucentButton(
                              OutlinedButton.icon(
                                onPressed:
                                    _isDeletingVersion || maintenanceRunning
                                    ? null
                                    : () => onDeleteVersion(version),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 17,
                                ),
                                label: Text(
                                  _isDeletingVersion ? '正在删除…' : '删除客户端',
                                ),
                                style: _compactManagementButtonStyle(
                                  foregroundColor: const Color(0xFFE58A7A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (maintenanceStatus != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _panelAccentColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                if (maintenanceRunning) ...[
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    maintenanceStatus!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                                if (maintenanceRunning)
                                  TextButton(
                                    onPressed: maintenanceCancellable
                                        ? onCancelMaintenance
                                        : null,
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 28),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('取消'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildBgucSection(
                    title: 'Java 与内存分配',
                    anchor: 'Java 与内存分配',
                    icon: Icons.memory_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clientSettings.isIndependent
                              ? '此客户端使用独立配置，不受全局设置影响。'
                              : '此客户端跟随全局设置；调整下方选项后会保存为独立配置。',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'client-java-${clientSettings.java}-${_javaRuntimes.length}',
                          ),
                          initialValue: clientSettings.usesOwnJava
                              ? clientSettings.java
                              : ClientLaunchSettings.followGlobal,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Java 运行时',
                            isDense: true,
                            filled: true,
                            fillColor: _usesDarkPalette
                                ? const Color(0xFF151B15)
                                : const Color(0xFFF1F4ED),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: BorderSide(color: _panelBorderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: BorderSide(color: _panelBorderColor),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: ClientLaunchSettings.followGlobal,
                              child: Text('跟随全局设置'),
                            ),
                            if (clientSettings.usesOwnJava &&
                                !_javaRuntimes.any(
                                  (runtime) =>
                                      runtime.executable == clientSettings.java,
                                ))
                              DropdownMenuItem(
                                value: clientSettings.java,
                                child: Text(
                                  clientSettings.java,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ..._javaRuntimes.map(
                              (runtime) => DropdownMenuItem(
                                value: runtime.executable,
                                child: Text(
                                  '${runtime.displayName} · ${_fileName(runtime.executable)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) onClientJavaChanged(value);
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '如需添加或扫描新的 Java，请前往 设置 -> Java 管理。',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '最大内存分配',
                                style: TextStyle(fontSize: 12, color: _muted),
                              ),
                            ),
                            Text(
                              '${_effectiveMemoryGb.round()} GB',
                              style: TextStyle(
                                color: _selectedForegroundColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _effectiveMemoryGb,
                          min: 2,
                          max: math.max(3, maxMemoryGb),
                          divisions: math.max(
                            1,
                            (math.max(3, maxMemoryGb) - 2).round(),
                          ),
                          label: '${_effectiveMemoryGb.round()} GB',
                          onChanged: onClientMemoryChanged,
                        ),
                        Text(
                          memoryError ??
                              '内存只会保存到当前客户端；未调整时沿用全局默认，'
                                  '该值会作为 -Xmx 参数用于实际启动。',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildBgucSection(
                    title: '游戏资源',
                    anchor: '游戏资源',
                    icon: Icons.inventory_2_outlined,
                    action: _translucentButton(
                      OutlinedButton.icon(
                        onPressed: onOpenResourceSearch,
                        icon: const Icon(Icons.add_rounded, size: 17),
                        label: const Text('搜索资源'),
                      ),
                    ),
                    child: GameResourcesSection(
                      key: ValueKey('resources-${version.path}'),
                      clientDirectory: version.gameDirectory ?? version.path,
                      palette: palette,
                      onMessage: onMessage,
                      onRefresh: () => onLoadManagedMods(version),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildBgucSection(
                    title: '网络服务器',
                    anchor: '网络服务器',
                    icon: Icons.dns_outlined,
                    child: ServerListSection(
                      key: ValueKey(version.path),
                      clientDirectory: version.gameDirectory ?? version.path,
                      palette: palette,
                      onMessage: onMessage,
                      onFastJoin: (server) => onFastJoinServer(version, server),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(child: CategoryAnchorBar(anchors: _sectionKeys)),
            ),
          ],
        );
      },
    );
  }

  String _loaderDisplay(LauncherVersion version) {
    final loader = version.loaderType;
    if (loader == null) return '原版';
    return '$loader ${version.loaderVersion ?? '版本未知'}';
  }

  Widget _buildBgucSection({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
    String? anchor,
  }) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
    final key = anchor == null ? null : _sectionKeys[anchor];
    return key == null ? content : KeyedSubtree(key: key, child: content);
  }

  String _fileName(String path) => path.split(Platform.pathSeparator).last;

  @override
  Widget build(BuildContext context) => _buildVersionDetails(version);
}
