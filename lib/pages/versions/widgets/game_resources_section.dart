import 'dart:io';

import 'package:flutter/material.dart';

import '../../../services/launcher/resource_icon_service.dart';
import '../../../services/launcher/resource_scan_service.dart';
import '../../../widgets/resource_icon.dart';
import '../../launcher/launcher_palette.dart';

/// "游戏资源大纲": category switcher plus the resources of one client.
///
/// Thumbnails are resolved lazily by [ResourceIcon] (off the UI isolate), so
/// long mod lists never block the frame with archive decompression.
class GameResourcesSection extends StatefulWidget {
  const GameResourcesSection({
    super.key,
    required this.clientDirectory,
    required this.palette,
    required this.onMessage,
    required this.onRefresh,
  });

  final String clientDirectory;
  final LauncherPalette palette;
  final ValueChanged<String> onMessage;

  /// Lets the parent refresh its own caches after a rename/delete.
  final VoidCallback onRefresh;

  @override
  State<GameResourcesSection> createState() => _GameResourcesSectionState();
}

class _GameResourcesSectionState extends State<GameResourcesSection> {
  /// Upper bound of the virtualized list; the details page keeps its own
  /// scroll view around this section.
  static const double _listHeight = 460;

  ResourceType _category = ResourceType.mod;
  List<GameResource> _resources = const <GameResource>[];
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _isLoading = true;
  String? _error;

  Color get _muted => widget.palette.muted;
  static const Color _accent = Color(0xFF8BC34A);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final resources = await ResourceScanService.scanAll(
        widget.clientDirectory,
      );
      if (!mounted) return;
      setState(() {
        _resources = resources;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '读取资源列表失败：$error';
      });
    }
  }

  List<GameResource> get _visibleResources {
    final query = _query.trim().toLowerCase();
    return _resources
        .where((resource) {
          if (resource.category != _category) return false;
          if (query.isEmpty) return true;
          return resource.name.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  int _countOf(ResourceType category) =>
      _resources.where((resource) => resource.category == category).length;

  Future<void> _toggle(GameResource resource) async {
    // Disabling writes the `.disable` marker (normalising an old `.disabled`
    // path); enabling strips whichever marker the file currently uses.
    final target = resource.enabled
        ? ResourceScanService.disabledPathOf(resource.path)
        : ResourceScanService.enabledPathOf(resource.path);
    try {
      final FileSystemEntity entity = resource.isDirectory
          ? Directory(resource.path)
          : File(resource.path);
      await entity.rename(target);
      widget.onMessage('${resource.enabled ? '已停用' : '已启用'}：${resource.name}');
      widget.onRefresh();
      await _load();
    } on FileSystemException catch (error) {
      widget.onMessage('操作失败：${error.message}');
    }
  }

  Future<void> _delete(GameResource resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除资源'),
        content: Text('确定要删除「${resource.name}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final FileSystemEntity entity = resource.isDirectory
          ? Directory(resource.path)
          : File(resource.path);
      if (await entity.exists()) {
        await entity.delete(recursive: resource.isDirectory);
      }
      widget.onMessage('已删除：${resource.name}');
      widget.onRefresh();
      await _load();
    } on FileSystemException catch (error) {
      widget.onMessage('删除失败：${error.message}');
    }
  }

  String _categoryLabel(ResourceType category) {
    return switch (category) {
      ResourceType.mod => '模组',
      ResourceType.resourcePack => '资源包',
      ResourceType.shaderPack => '光影',
      ResourceType.blueprint => '蓝图',
      ResourceType.saves => '存档',
      ResourceType.world => '存档',
    };
  }

  IconData _fallbackIcon(ResourceType category) {
    return switch (category) {
      ResourceType.mod => Icons.extension_rounded,
      ResourceType.resourcePack => Icons.image_rounded,
      ResourceType.shaderPack => Icons.auto_awesome_rounded,
      ResourceType.blueprint => Icons.architecture_rounded,
      ResourceType.saves => Icons.public_rounded,
      ResourceType.world => Icons.public_rounded,
    };
  }

  Widget _buildEmptyState() {
    final query = _query.trim();
    final (icon, message) = query.isNotEmpty
        ? (Icons.search_off_rounded, '没有匹配「$query」的资源。')
        : switch (_category) {
      ResourceType.mod => (Icons.extension_outlined, '此客户端尚未安装模组。'),
      ResourceType.resourcePack => (Icons.image_outlined, '此客户端尚未安装资源包。'),
      ResourceType.shaderPack => (Icons.auto_awesome_outlined, '此客户端尚未安装光影包。'),
      ResourceType.blueprint => (
        Icons.architecture_outlined,
        '未找到投影蓝图；安装投影模组并保存蓝图后会显示在这里。',
      ),
      ResourceType.saves => (
        Icons.public_outlined,
        '此客户端还没有存档；进入游戏创建世界后会显示在这里。',
      ),
      ResourceType.world => (Icons.public_outlined, '暂无内容。'),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: widget.palette.panelColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.palette.panelBorderColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 26, color: _muted),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(ResourceType category) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _category == category;
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _category = category),
      avatar: Icon(
        _fallbackIcon(category),
        size: 16,
        color: selected ? scheme.onPrimary : _muted,
      ),
      label: Text('${_categoryLabel(category)} ${_countOf(category)}'),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: selected ? scheme.onPrimary : null,
      ),
      selectedColor: scheme.primary,
      backgroundColor: widget.palette.panelColor,
      side: BorderSide(
        color: selected ? scheme.primary : widget.palette.panelBorderColor,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildSearchField() {
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: widget.palette.panelBorderColor),
    );
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      style: const TextStyle(fontSize: 12),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: '搜索当前分类的资源…',
        hintStyle: TextStyle(fontSize: 12, color: _muted),
        prefixIcon: Icon(Icons.search_rounded, size: 18, color: _muted),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: '清除搜索',
                icon: Icon(Icons.close_rounded, size: 16, color: _muted),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: widget.palette.panelColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildTile(GameResource resource) {
    // A plain Row keeps the thumbnail square: ListTile shrinks the leading
    // height to the text height, which used to squash the 64px icon.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ResourceIcon(
            filePath: resource.path,
            type: resource.category,
            fallbackIcon: _fallbackIcon(resource.category),
            size: 52,
            radius: 10,
            color: resource.enabled ? _accent : _muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  resource.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: resource.enabled ? null : _muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  resource.enabled ? '已启用' : '已停用',
                  style: TextStyle(fontSize: 10, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _toggle(resource),
            child: Text(resource.enabled ? '停用' : '启用'),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: () => _delete(resource),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleResources;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in ResourceScanService.categories)
                    _buildCategoryChip(category),
                ],
              ),
            ),
            IconButton(
              tooltip: '刷新资源',
              onPressed: _isLoading ? null : _load,
              icon: Icon(Icons.refresh_rounded, color: _muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildSearchField(),
        const SizedBox(height: 6),
        Text(
          '找到 ${items.length} 个资源',
          style: TextStyle(fontSize: 10.5, color: _muted),
        ),
        if (_isLoading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Text(
            _error!,
            style: const TextStyle(fontSize: 11, color: Color(0xFFE05B5B)),
          ),
        if (!_isLoading && items.isEmpty) _buildEmptyState(),
        if (items.isNotEmpty)
          // A bounded height keeps ListView.builder virtualized; `shrinkWrap`
          // would force all 500 entries to lay out and defeat the optimization.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _listHeight),
            child: ListView.builder(
              primary: false,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final resource = items[index];
                return RepaintBoundary(
                  key: ValueKey(resource.path),
                  child: _buildTile(resource),
                );
              },
            ),
          ),
      ],
    );
  }
}
