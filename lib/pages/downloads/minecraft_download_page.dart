import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/installer/game_installer.dart';
import '../../services/network/api_service.dart';
import '../../widgets/launcher/launcher_common.dart';
import '../launcher/controllers/download_activity_controller.dart';
import '../launcher/launcher_palette.dart';
import 'controllers/minecraft_download_controller.dart';
import 'controllers/minecraft_download_types.dart';

class MinecraftDownloadPage extends StatefulWidget {
  const MinecraftDownloadPage({
    super.key,
    required this.minecraft,
    required this.activity,
    required this.palette,
    required this.isDark,
    required this.isDownloadLocked,
    required this.minecraftPath,
    required this.minecraftClientNameController,
    required this.onLoadCatalog,
    required this.onLoadLoaderVersions,
    required this.onSelectVersion,
    required this.onInstall,
    required this.onOpenResourceDownloads,
    required this.onShowDownloadLockedDialog,
    this.onCancelInstall,
  });

  final MinecraftDownloadController minecraft;
  final DownloadActivityController activity;
  final LauncherPalette palette;
  final bool isDark;
  final bool isDownloadLocked;
  final String minecraftPath;
  final TextEditingController minecraftClientNameController;
  final Future<void> Function() onLoadCatalog;
  final Future<void> Function(MinecraftLoader) onLoadLoaderVersions;
  final void Function(String) onSelectVersion;
  final Future<void> Function() onInstall;
  final VoidCallback onOpenResourceDownloads;
  final Future<void> Function(BuildContext) onShowDownloadLockedDialog;
  final VoidCallback? onCancelInstall;

  @override
  State<MinecraftDownloadPage> createState() => _MinecraftDownloadPageState();
}

class _MinecraftDownloadPageState extends State<MinecraftDownloadPage> {
  MinecraftDownloadController get minecraft => widget.minecraft;
  LauncherPalette get palette => widget.palette;

  static const _green = Color(0xFF8BC34A);
  bool get _usesDarkPalette => widget.isDark;
  bool get isDownloadLocked => widget.isDownloadLocked;
  String get _minecraftPath => widget.minecraftPath;
  TextEditingController get _minecraftClientNameController =>
      widget.minecraftClientNameController;
  Color get _muted => palette.muted;
  Color get _panelColor => palette.panelColor;
  Color get _panelBorderColor => palette.panelBorderColor;
  Color get _selectedSurfaceColor => palette.selectedSurfaceColor;
  Color get _selectedForegroundColor => palette.selectedForegroundColor;
  Color get _buttonForeground => palette.buttonForeground;
  MinecraftReleaseCategory get _minecraftReleaseCategory =>
      minecraft.releaseCategory;
  set _minecraftReleaseCategory(MinecraftReleaseCategory value) =>
      minecraft.releaseCategory = value;
  MinecraftLoader? get _selectedMinecraftLoader => minecraft.selectedLoader;
  set _selectedMinecraftLoader(MinecraftLoader? value) =>
      minecraft.selectedLoader = value;
  String? get _selectedMinecraftVersion => minecraft.selectedVersion;
  set _selectedMinecraftVersion(String? value) =>
      minecraft.selectedVersion = value;
  List<MinecraftCatalogVersion> get _minecraftCatalog => minecraft.catalog;
  set _minecraftCatalog(List<MinecraftCatalogVersion> value) =>
      minecraft.catalog = value;
  bool get _isLoadingMinecraftCatalog => minecraft.isLoadingCatalog;
  String? get _minecraftCatalogError => minecraft.catalogError;
  set _minecraftCatalogError(String? value) => minecraft.catalogError = value;
  Map<MinecraftLoader, List<String>> get _loaderVersions =>
      minecraft.loaderVersions;
  Set<MinecraftLoader> get _loadingLoaderVersions =>
      minecraft.loadingLoaderVersions;
  Map<MinecraftLoader, String> get _loaderVersionErrors =>
      minecraft.loaderVersionErrors;
  Map<MinecraftLoader, int> get _loaderRequestIds => minecraft.loaderRequestIds;
  MinecraftDownloadSource get _minecraftDownloadSource =>
      minecraft.downloadSource;
  bool get _isInstallingMinecraft => minecraft.isInstalling;
  String? get _minecraftInstallStatus => minecraft.installStatus;
  String? get _minecraftInstallError => minecraft.installError;
  String? get _selectedLoaderVersion => minecraft.selectedLoaderVersion;
  set _selectedLoaderVersion(String? value) =>
      minecraft.selectedLoaderVersion = value;

  @override
  void initState() {
    super.initState();
    minecraft.addListener(_onMinecraftChanged);
  }

  @override
  void dispose() {
    minecraft.removeListener(_onMinecraftChanged);
    super.dispose();
  }

  void _onMinecraftChanged() {
    if (mounted) setState(() {});
  }

  void _setPageState(VoidCallback callback) => setState(callback);
  Future<void> _loadMinecraftCatalog() => widget.onLoadCatalog();
  Future<void> _loadLoaderVersions(MinecraftLoader loader) =>
      widget.onLoadLoaderVersions(loader);
  void _selectMinecraftVersion(String? version) {
    if (version != null) widget.onSelectVersion(version);
  }

  Future<void> _installSelectedMinecraft() => widget.onInstall();
  void _openMinecraftDownload() => widget.onOpenResourceDownloads();
  Future<void> _showDownloadLockedDialog(BuildContext context) =>
      widget.onShowDownloadLockedDialog(context);

  Widget _translucentButton(Widget button, {double radius = 10}) {
    return TranslucentButtonSurface(radius: radius, child: button);
  }

  Widget _buildBgucSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
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
              Icon(icon, size: 18, color: palette.uiColors.accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildMinecraftDownload();

  Widget _buildMinecraftDownload() {
    final availableVersions = _minecraftCatalog
        .where(
          (version) =>
              MinecraftReleaseCategory.forVersion(version) ==
              _minecraftReleaseCategory,
        )
        .toList();
    final availableVersionIds = availableVersions
        .map((version) => version.id)
        .toList();
    final selectedVersion =
        availableVersionIds.contains(_selectedMinecraftVersion)
        ? _selectedMinecraftVersion
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 36,
            24,
            compact ? 20 : 36,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _translucentButton(
                    OutlinedButton.icon(
                      onPressed: _openMinecraftDownload,
                      icon: Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text('返回资源下载'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _buttonForeground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    '下载 Minecraft',
                    style: TextStyle(
                      fontSize: compact ? 26 : 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '选择 Minecraft 版本与兼容的模组加载器。',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '版本数据与加速 API 由 BMCLAPI 提供。',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                  const SizedBox(height: 22),
                  _buildBgucSection(
                    title: 'Minecraft 版本',
                    icon: Icons.inventory_2_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: MinecraftReleaseCategory.values.map((
                            category,
                          ) {
                            final selected =
                                _minecraftReleaseCategory == category;
                            return _translucentButton(
                              ChoiceChip(
                                label: Text(category.label),
                                selected: selected,
                                onSelected: (_) {
                                  _setPageState(() {
                                    _minecraftReleaseCategory = category;
                                    final versions = _minecraftCatalog
                                        .where(
                                          (version) =>
                                              MinecraftReleaseCategory.forVersion(
                                                version,
                                              ) ==
                                              category,
                                        )
                                        .toList();
                                    _selectedMinecraftVersion =
                                        versions.firstOrNull?.id;
                                    _selectedLoaderVersion = null;
                                    _loaderVersions.clear();
                                    _loaderVersionErrors.clear();
                                    _loadingLoaderVersions.clear();
                                    for (final loader
                                        in MinecraftLoader.values) {
                                      _loaderRequestIds[loader] =
                                          (_loaderRequestIds[loader] ?? 0) + 1;
                                    }
                                  });
                                  final selectedLoader =
                                      _selectedMinecraftLoader;
                                  if (selectedLoader != null) {
                                    unawaited(
                                      _loadLoaderVersions(selectedLoader),
                                    );
                                  }
                                },
                                selectedColor: _selectedSurfaceColor,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: selected
                                      ? _selectedForegroundColor
                                      : _muted,
                                ),
                                showCheckmark: false,
                              ),
                              radius: 22,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingMinecraftCatalog)
                          const LinearProgressIndicator(minHeight: 2)
                        else if (_minecraftCatalogError != null)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _minecraftCatalogError!,
                                  style: const TextStyle(
                                    color: Color(0xFFE58A7A),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '重新加载版本列表',
                                onPressed: () {
                                  _setPageState(() {
                                    _minecraftCatalog = [];
                                    _minecraftCatalogError = null;
                                  });
                                  unawaited(_loadMinecraftCatalog());
                                },
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          )
                        else if (availableVersions.isEmpty)
                          Text(
                            _minecraftCatalog.isEmpty
                                ? '正在等待 BMCLAPI 版本列表。'
                                : '该分类暂无可用版本。',
                            style: TextStyle(fontSize: 11, color: _muted),
                          )
                        else
                          DropdownButtonFormField<String>(
                            key: ValueKey(_minecraftReleaseCategory),
                            initialValue: selectedVersion,
                            decoration: _downloadDropdownDecoration(),
                            items: availableVersions
                                .map(
                                  (version) => DropdownMenuItem(
                                    value: version.id,
                                    child: Text(version.id),
                                  ),
                                )
                                .toList(),
                            onChanged: _selectMinecraftVersion,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildBgucSection(
                    title: '模组加载器',
                    icon: Icons.extension_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择 Forge、NeoForge、Fabric 或独立安装 OptiFine；安装器会一并配置所选 Minecraft 版本。'
                          'Fabric 客户端安装完成后会自动将兼容的 Fabric API 放入该客户端的 mods 文件夹。',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: MinecraftLoader.values.map((loader) {
                            final selected = _selectedMinecraftLoader == loader;
                            return _translucentButton(
                              ChoiceChip(
                                label: Text(loader.label),
                                selected: selected,
                                onSelected: (_) {
                                  _setPageState(() {
                                    _selectedMinecraftLoader = selected
                                        ? null
                                        : loader;
                                    _selectedLoaderVersion = null;
                                    if (!selected) {
                                      _loaderVersions.remove(loader);
                                      _loaderVersionErrors.remove(loader);
                                    }
                                  });
                                  if (!selected) {
                                    unawaited(_loadLoaderVersions(loader));
                                  }
                                },
                                selectedColor: _selectedSurfaceColor,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: selected
                                      ? _selectedForegroundColor
                                      : _muted,
                                ),
                                showCheckmark: false,
                              ),
                              radius: 22,
                            );
                          }).toList(),
                        ),
                        if (_selectedMinecraftLoader case final loader?) ...[
                          const SizedBox(height: 16),
                          Text(
                            '${loader.label} 版本',
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                          const SizedBox(height: 8),
                          if (_loadingLoaderVersions.contains(loader))
                            const LinearProgressIndicator(minHeight: 2)
                          else if (_loaderVersionErrors[loader]
                              case final error?)
                            Text(
                              error,
                              style: const TextStyle(
                                color: Color(0xFFE58A7A),
                                fontSize: 11,
                              ),
                            )
                          else if (_loaderVersions[loader] case final versions?)
                            if (versions.isEmpty)
                              Text(
                                '该 Minecraft 版本没有可用的 ${loader.label} 版本。',
                                style: TextStyle(fontSize: 11, color: _muted),
                              )
                            else
                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                  '$loader-${_selectedMinecraftVersion ?? ''}',
                                ),
                                initialValue:
                                    versions.contains(_selectedLoaderVersion)
                                    ? _selectedLoaderVersion
                                    : versions.first,
                                decoration: _downloadDropdownDecoration(),
                                items: versions
                                    .map(
                                      (version) => DropdownMenuItem(
                                        value: version,
                                        child: Text(version),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (version) => _setPageState(
                                  () => _selectedLoaderVersion = version,
                                ),
                              )
                          else
                            Text(
                              '先选择 Minecraft 版本以查询兼容加载器。',
                              style: TextStyle(fontSize: 11, color: _muted),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildBgucSection(
                    title: '下载配置',
                    icon: Icons.download_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Minecraft ${selectedVersion ?? '未加载'}'
                          '${_selectedMinecraftLoader == null ? '' : ' · ${_selectedMinecraftLoader!.label} ${_selectedLoaderVersion ?? '未加载'}'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '游戏下载源：${_minecraftDownloadSource.label}。该来源将用于客户端、依赖库与资源文件。',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '安装位置：${_minecraftPath.isEmpty ? '默认 .minecraft 目录' : _minecraftPath}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: _muted),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _minecraftClientNameController,
                          enabled: !_isInstallingMinecraft,
                          maxLength: 64,
                          textInputAction: TextInputAction.done,
                          decoration: _downloadDropdownDecoration().copyWith(
                            labelText: '客户端名称（可选）',
                            hintText: '例如：生存客户端',
                            helperText:
                                '留空则使用版本/加载器名称；自定义名称会创建独立的 versions 文件夹。',
                            helperMaxLines: 2,
                            counterText: '',
                          ),
                        ),
                        if (_minecraftInstallStatus != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _minecraftInstallStatus!,
                            style: TextStyle(fontSize: 11, color: _muted),
                          ),
                          if (_isInstallingMinecraft) ...[
                            const SizedBox(height: 6),
                            const LinearProgressIndicator(minHeight: 2),
                            if (widget.onCancelInstall != null) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: widget.onCancelInstall,
                                  child: const Text('取消安装'),
                                ),
                              ),
                            ],
                          ],
                        ],
                        if (_minecraftInstallError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _minecraftInstallError!,
                            style: const TextStyle(
                              color: Color(0xFFE58A7A),
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _isInstallingMinecraft
                              ? null
                              : () {
                                  if (isDownloadLocked) {
                                    unawaited(
                                      _showDownloadLockedDialog(context),
                                    );
                                    return;
                                  }
                                  unawaited(_installSelectedMinecraft());
                                },
                          icon: _isInstallingMinecraft
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download_rounded, size: 18),
                          label: Text(
                            _isInstallingMinecraft
                                ? '正在安装…'
                                : _selectedMinecraftLoader == null
                                ? '下载原版 Minecraft'
                                : '下载并安装 ${_selectedMinecraftLoader!.label}',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: const Color(0xFF172013),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _downloadDropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: _usesDarkPalette
          ? const Color(0xFF151B15)
          : const Color(0xFFF1F4ED),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: _panelBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: _panelBorderColor),
      ),
    );
  }
}

class MinecraftDownloadEntryCard extends StatelessWidget {
  const MinecraftDownloadEntryCard({
    super.key,
    required this.minecraft,
    required this.palette,
    required this.isDownloadLocked,
    required this.onOpen,
    required this.onLoadCatalog,
    required this.onShowDownloadLockedDialog,
  });

  final MinecraftDownloadController minecraft;
  final LauncherPalette palette;
  final bool isDownloadLocked;
  final VoidCallback onOpen;
  final Future<void> Function() onLoadCatalog;
  final Future<void> Function(BuildContext) onShowDownloadLockedDialog;

  static const _green = Color(0xFF8BC34A);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.panelColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.panelBorderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final description = Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.panelAccentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.grass, color: _green),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Minecraft 游戏本体',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '选择游戏版本和模组加载器',
                      style: TextStyle(color: palette.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: () {
              if (isDownloadLocked) {
                unawaited(onShowDownloadLockedDialog(context));
                return;
              }
              minecraft.selectLoader(null);
              minecraft.selectLoaderVersion(null);
              onOpen();
              unawaited(onLoadCatalog());
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('下载 Minecraft'),
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: const Color(0xFF172013),
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [description, const SizedBox(height: 14), button],
            );
          }
          return Row(
            children: [
              Expanded(child: description),
              const SizedBox(width: 14),
              button,
            ],
          );
        },
      ),
    );
  }
}
