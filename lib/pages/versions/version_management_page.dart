
import 'package:flutter/material.dart';

import '../../services/installer/version_models.dart';
import '../../services/network/api_service.dart';
import '../../widgets/category_anchor_bar.dart';
import '../../widgets/launcher/launcher_common.dart';
import '../../widgets/version_icon.dart';
import '../launcher/controllers/java_environment_controller.dart';
import '../launcher/launcher_palette.dart';
import 'controllers/version_catalog_controller.dart';
import '../launcher/controllers/launcher_environment_controller.dart';

/// Version list, filters, client sources and maintenance actions.
class VersionManagementPage extends StatelessWidget {
  const VersionManagementPage({
    super.key,
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
    required this.onMemoryChanged,
    required this.onMessage,
    required this.onPickJava,
    required this.onSaveJava,
    required this.onCancelMaintenance,
    required this.onOpenResourceSearch,
    required this.javaPathController,
    this.minecraftInstallStatus,
    this.minecraftInstallError,
    this.maintenanceCancellable = false,
  });

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
  final ValueChanged<double> onMemoryChanged;
  final ValueChanged<String> onMessage;
  final VoidCallback onPickJava;
  final VoidCallback onSaveJava;
  final VoidCallback onCancelMaintenance;
  final VoidCallback onOpenResourceSearch;
  final TextEditingController javaPathController;
  final String? minecraftInstallStatus;
  final String? minecraftInstallError;
  final bool maintenanceCancellable;

  static const _green = Color(0xFF8BC34A);
  static final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{
    '客户端来源': GlobalKey(debugLabel: '客户端来源'),
    '版本列表': GlobalKey(debugLabel: '版本列表'),
  };
  VersionCatalogController get _catalog => catalog;
  String get _versionSearchQuery => versionSearchQuery;
  int get _versionFilter => versionFilter;
  List<LauncherVersion> get _versions => catalog.versions;
  List<MinecraftVersion> get _localVersions => catalog.localVersions;
  bool get _isLoadingVersions => catalog.isLoadingVersions;
  String? get _versionLoadError => catalog.versionLoadError;
  String get _minecraftPath => environment.minecraftPath;
  List<String> _effectiveMinecraftSources() => environment.effectiveSources;
  bool _samePath(String left, String right) =>
      LauncherEnvironmentController.samePath(left, right);
  Color get _muted => palette.muted;
  Color get _panelColor => palette.panelColor;
  Color get _panelBorderColor => palette.panelBorderColor;
  Color get _panelAccentColor => palette.panelAccentColor;
  Color get _selectedSurfaceColor => palette.selectedSurfaceColor;
  Color get _selectedForegroundColor => palette.selectedForegroundColor;
  Color get _buttonForeground => palette.buttonForeground;
  bool get _usesDarkPalette => isDark;
  String? get _minecraftInstallStatus => minecraftInstallStatus;
  String? get _minecraftInstallError => minecraftInstallError;

  Widget _translucentButton(Widget button, {double radius = 10}) {
    return TranslucentButtonSurface(radius: radius, child: button);
  }

  Widget _translucentCircularButton(Widget button) {
    return TranslucentCircularButtonSurface(child: button);
  }
  Widget _buildVersionManagement() {
    final query = _versionSearchQuery.trim().toLowerCase();
    final versions = _versions
        .where((version) {
          if (_versionFilter == 1) return version.kind == VersionKind.modded;
          if (_versionFilter == 2) return version.kind == VersionKind.vanilla;
          return true;
        })
        .where((version) {
          if (query.isEmpty) return true;
          return [
            version.name,
            if (version.minecraftVersion != null)
              'Minecraft ${version.minecraftVersion}',
            version.versionType,
            version.loaderType,
            version.loaderVersion,
          ].whereType<String>().any(
            (value) => value.toLowerCase().contains(query),
          );
        })
        .toList();
    final hasVisibleVersions = versions.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final content = SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 36,
            30,
            compact ? 20 : 36,
            96,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '版本管理',
                    style: TextStyle(
                      fontSize: compact ? 26 : 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '可添加多个 .minecraft 文件夹来源；启动器始终只显示当前来源中的客户端，切换来源后会重新扫描该文件夹。',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  KeyedSubtree(
                    key: _sectionKeys['客户端来源'],
                    child: _buildVersionSourceCard(compact),
                  ),
                  const SizedBox(height: 20),
                  if (compact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildActionButton(
                          icon: Icons.archive_outlined,
                          label: '导入整合包',
                          onPressed: onImportModpack,
                          primary: true,
                        ),
                        const SizedBox(height: 10),
                        _buildActionButton(
                          icon: Icons.create_new_folder_outlined,
                          label: '添加已有文件夹',
                          onPressed: onAddFolder,
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildActionButton(
                          icon: Icons.archive_outlined,
                          label: '导入整合包',
                          onPressed: onImportModpack,
                          primary: true,
                        ),
                        _buildActionButton(
                          icon: Icons.create_new_folder_outlined,
                          label: '添加已有文件夹',
                          onPressed: onAddFolder,
                        ),
                      ],
                    ),
                  if (_minecraftInstallStatus != null ||
                      _minecraftInstallError != null) ...[
                    const SizedBox(height: 14),
                    _buildModpackInstallStatus(),
                  ],
                  const SizedBox(height: 24),
                  KeyedSubtree(
                    key: _sectionKeys['版本列表'],
                    child: TextField(
                      onChanged: (value) => onSearchChanged(value),
                    decoration: InputDecoration(
                      hintText: '检索客户端名称、Minecraft 版本或加载器',
                      prefixIcon: Icon(Icons.search_rounded, color: _muted),
                      suffixIcon: _versionSearchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清空检索',
                              onPressed: () => onSearchChanged(''),
                              icon: Icon(Icons.close_rounded, color: _muted),
                            ),
                      filled: true,
                      fillColor: _panelColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide.none,
                      ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '游戏版本',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _translucentCircularButton(
                        IconButton(
                          tooltip: '重新扫描版本目录',
                          onPressed: _isLoadingVersions
                              ? null
                              : _catalog.loadVersions,
                          icon: Icon(Icons.refresh_rounded, color: _muted),
                          style: IconButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.transparent,
                            overlayColor: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _filterChip('全部', 0, _versions.length),
                      _filterChip(
                        '模组版',
                        1,
                        _versions
                            .where((v) => v.kind == VersionKind.modded)
                            .length,
                      ),
                      _filterChip(
                        '原版',
                        2,
                        _versions
                            .where((v) => v.kind == VersionKind.vanilla)
                            .length,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_isLoadingVersions)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 44),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_versionLoadError != null)
                    _buildVersionEmptyState(
                      icon: Icons.folder_off_outlined,
                      title: '无法读取版本目录',
                      description: _versionLoadError!,
                      actionLabel: '重新扫描',
                      onAction: _catalog.loadVersions,
                    )
                  else if (!hasVisibleVersions)
                    _buildVersionEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: _minecraftPath.isEmpty
                          ? '尚未选择游戏目录'
                          : query.isNotEmpty
                          ? '没有匹配的客户端'
                          : _versionFilter == 2
                          ? '还没有原版客户端'
                          : '没有发现客户端',
                      description: _minecraftPath.isEmpty
                          ? '选择 .minecraft 文件夹，启动器会扫描其中的 versions 子目录。'
                          : query.isNotEmpty
                          ? '检查检索内容，或清空检索后查看所有客户端。'
                          : '确认所选 .minecraft 文件夹中包含 versions 子目录及版本配置文件。',
                      actionLabel: _minecraftPath.isEmpty
                          ? '选择 .minecraft 文件夹'
                          : null,
                      onAction: _minecraftPath.isEmpty ? onAddFolder : null,
                    ),
                  if (!_isLoadingVersions &&
                      _versionLoadError == null &&
                      _localVersions.isEmpty) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: FilledButton.icon(
                        onPressed: () {
                          if (isDownloadLocked) {
                            onDownloadMinecraft();
                            return;
                          }
                          onDownloadMinecraft();
                        },
                        icon: const Icon(Icons.download_rounded, size: 17),
                        label: const Text('前往下载 Minecraft'),
                      ),
                    ),
                  ],
                  if (!_isLoadingVersions && _versionLoadError == null)
                    ...versions.map(_buildVersionTile),
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

  Widget _buildVersionSourceCard(bool compact) {
    final sources = _effectiveMinecraftSources();
    final current = _minecraftPath.isNotEmpty
        ? _minecraftPath
        : (sources.firstOrNull ?? '');
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.folder_copy_outlined, color: _green, size: 18),
              const SizedBox(width: 9),
              const Text(
                '客户端来源',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                sources.isEmpty
                    ? '点击添加文件夹'
                    : sources.length > 1
                    ? '点击切换（${sources.length} 个来源）'
                    : '点击更换文件夹',
                style: TextStyle(fontSize: 10, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (current.isEmpty)
            Material(
              color: _panelAccentColor,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onAddFolder,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _panelBorderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_open_outlined, size: 18, color: _muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '尚未选择 .minecraft 文件夹',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                      ),
                      Icon(Icons.add_rounded, size: 18, color: _muted),
                    ],
                  ),
                ),
              ),
            )
          else
            _buildMinecraftSourceTile(current, compact),
        ],
      ),
    );
  }

  Widget _buildMinecraftSourceTile(String source, bool compact) {
    final count = _localVersions
        .where((version) => _samePath(version.minecraftPath, source))
        .length;
    final sourceCount = _effectiveMinecraftSources().length;
    return Material(
      color: _selectedSurfaceColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onShowSourcePicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _green),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_open_outlined, color: _green, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sourceCount > 1
                          ? '$count 个客户端 · 点击切换来源'
                          : '$count 个客户端 · 点击更换文件夹',
                      style: TextStyle(fontSize: 10, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                sourceCount > 1
                    ? Icons.unfold_more_rounded
                    : Icons.edit_outlined,
                size: 16,
                color: _muted,
              ),
            ],
          ),
        ),
      ),
    );
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



  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    return SizedBox(
      height: 44,
      child: primary
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: const Color(0xFF172013),
              ),
            )
          : _translucentButton(
              OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 18),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _buttonForeground,
                ),
              ),
            ),
    );
  }

  Widget _filterChip(String label, int value, int count) {
    final selected = _versionFilter == value;
    return _translucentButton(
      ChoiceChip(
        label: Text('$label  $count'),
        selected: selected,
        onSelected: (_) => onVersionFilterChanged(value),
        selectedColor: _selectedSurfaceColor,
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? _selectedForegroundColor : _muted,
        ),
        showCheckmark: false,
      ),
      radius: 22,
    );
  }

  Widget _buildVersionEmptyState({
    required IconData icon,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _panelBorderColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: const Color(0xFF778171)),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            _translucentButton(
              TextButton(onPressed: onAction, child: Text(actionLabel)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVersionTile(LauncherVersion version) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _panelColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onOpenDetails(version),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _panelBorderColor),
            ),
            child: Row(
              children: [
                VersionIcon(version: version),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        version.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          _buildVersionTag(
                            'Minecraft ${version.minecraftVersion ?? '未知'}',
                          ),
                          _buildVersionTag(_loaderDisplay(version)),
                          if (version.versionType != null)
                            _buildVersionTag(version.versionType!),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        version.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: _muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _loaderDisplay(LauncherVersion version) {
    final loader = version.loaderType;
    if (loader == null) return '原版';
    return '$loader ${version.loaderVersion ?? '版本未知'}';
  }

  Widget _buildModpackInstallStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panelAccentColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        minecraftInstallError ?? minecraftInstallStatus ?? '',
        style: TextStyle(fontSize: 11, color: _muted),
      ),
    );
  }


  @override
  Widget build(BuildContext context) => _buildVersionManagement();
}
