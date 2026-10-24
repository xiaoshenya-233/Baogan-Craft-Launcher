import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/plugin/plugin_file_sandbox.dart';
import '../../services/plugin/plugin_icon_mapper.dart';
import 'plugin_audio_bar.dart';
import 'plugin_music_playlist.dart';

/// Callback used by buttons and other interactive nodes.
///
/// [params] is the node's `params` object plus a `fields` map that snapshots the
/// current text-field values, so plugins can submit forms without extra wiring.
typedef PluginActionCallback = void Function(
  String action,
  Map<String, dynamic> params,
);

/// Notified whenever a text field changes.
typedef PluginFieldChanged = void Function(String fieldId, String value);

/// Recursive JSON -> Flutter widget renderer for plugin UI documents.
///
/// Supported nodes: container, row, column, padding, sizedBox, text,
/// iconButton, filledButton, image, textField, switch, listView, card,
/// responsive and webview (permission gated). Unknown nodes render an error tile.
class PluginUiRenderer extends StatefulWidget {
  const PluginUiRenderer({
    super.key,
    required this.document,
    required this.onAction,
    this.baseDirectory,
    this.dataDirectory,
    this.onFieldChanged,
    this.initialFieldValues = const <String, String>{},
    this.grantedPermissions = const <String>{},
  });

  /// Root node of the UI document (already decoded from JSON).
  final Map<String, dynamic> document;

  final PluginActionCallback onAction;

  /// Plugin folder; relative image paths are resolved inside it.
  final String? baseDirectory;

  /// `BGCL/plugins_data/<id>`; runtime assets may also live here.
  final String? dataDirectory;

  final PluginFieldChanged? onFieldChanged;
  final Map<String, String> initialFieldValues;

  /// Permissions granted by the plugin manifest; gates sensitive nodes.
  final Set<String> grantedPermissions;

  @override
  State<PluginUiRenderer> createState() => _PluginUiRendererState();
}

class _PluginUiRendererState extends State<PluginUiRenderer> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, String> _values = <String, String>{};
  final Map<String, Object?> _config = <String, Object?>{};

  @override
  void initState() {
    super.initState();
    _values.addAll(widget.initialFieldValues);
    _reloadConfig();
  }

  @override
  void didUpdateWidget(covariant PluginUiRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataDirectory != widget.dataDirectory) {
      _reloadConfig();
    }
  }

  void _reloadConfig() {
    _config.clear();
    try {
      _config.addAll(PluginFileSandbox.readConfigAtSync(widget.dataDirectory));
    } on Object catch (error) {
      debugPrint('Plugin config load failed: $error');
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _node(widget.document);

  Widget _node(Map<String, dynamic> node) {
    final type = _str(node['type'])?.toLowerCase();
    switch (type) {
      case 'container':
        return _container(node);
      case 'row':
        return _row(node);
      case 'column':
        return _column(node);
      case 'padding':
        return Padding(
          padding: _padding(node['padding']),
          child: _child(node['child']),
        );
      case 'sizedbox':
        return SizedBox(
          width: _numOrNull(node['width']),
          height: _numOrNull(node['height']),
          child: _child(node['child']),
        );
      case 'text':
        return _text(node);
      case 'iconbutton':
        return _button(node, filled: false);
      case 'filledbutton':
        return _button(node, filled: true);
      case 'image':
        return _image(node);
      case 'textfield':
        return _textField(node);
      case 'switch':
        return _switch(node);
      case 'listview':
        return _listView(node);
      case 'card':
        return _card(node);
      case 'responsive':
        return _responsive(node);
      case 'webview':
        return _webview(node);
      case 'audioplayer' || 'musicbar':
        return PluginAudioBar(label: _str(node['label']));
      case 'musicplaylist':
        return _musicPlaylist(node);
      default:
        return _imageError('Unsupported plugin node: ${type ?? 'null'}');
    }
  }

  Widget _child(Object? raw) => raw is Map
      ? _node(Map<String, dynamic>.from(raw))
      : const SizedBox.shrink();

  List<Widget> _childrenOf(
    Map<String, dynamic> node, {
    required bool vertical,
  }) {
    final raw = node['children'];
    if (raw is! List) return const <Widget>[];
    final spacing = _num(node['spacing'], 0);
    final children = <Widget>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final item = Map<String, dynamic>.from(entry);
      if (children.isNotEmpty && spacing > 0) {
        children.add(
          vertical ? SizedBox(height: spacing) : SizedBox(width: spacing),
        );
      }
      final child = _node(item);
      final flex = _int(item['flex'], 0);
      children.add(flex > 0 ? Expanded(flex: flex, child: child) : child);
    }
    return children;
  }

  Widget _container(Map<String, dynamic> node) {
    Widget content = _child(node['child']);
    final width = _numOrNull(node['width']);
    final height = _numOrNull(node['height']);
    if (width != null || height != null) {
      content = SizedBox(width: width, height: height, child: content);
    }
    content = Padding(padding: _padding(node['padding']), child: content);
    content = DecoratedBox(
      decoration: BoxDecoration(
        color: _color(node['color']),
        borderRadius: _radius(node['borderRadius']),
        border: _border(node),
      ),
      child: content,
    );
    final margin = _padding(node['margin']);
    return margin == EdgeInsets.zero
        ? content
        : Padding(padding: margin, child: content);
  }

  Widget _row(Map<String, dynamic> node) => Row(
    mainAxisAlignment: _mainAxis(node['mainAxisAlignment']),
    crossAxisAlignment: _crossAxis(node['crossAxisAlignment']),
    children: _childrenOf(node, vertical: false),
  );

  Widget _column(Map<String, dynamic> node) => Column(
    mainAxisSize: node['mainAxisSize'] == 'min'
        ? MainAxisSize.min
        : MainAxisSize.max,
    mainAxisAlignment: _mainAxis(node['mainAxisAlignment']),
    crossAxisAlignment: _crossAxis(node['crossAxisAlignment']),
    children: _childrenOf(node, vertical: true),
  );

  Widget _text(Map<String, dynamic> node) {
    final text = _str(node['text']) ?? _str(node['value']) ?? '';
    return Text(
      text,
      textAlign: _textAlign(node['textAlign']),
      maxLines: _intOrNull(node['maxLines']),
      overflow: _overflow(node['overflow']),
      style: TextStyle(
        fontSize: _numOrNull(node['fontSize']),
        color: _color(node['color']),
        fontWeight: node['fontWeight'] == 'bold' ? FontWeight.bold : null,
      ),
    );
  }

  Widget _card(Map<String, dynamic> node) => Card(
    elevation: _num(node['elevation'], 1),
    margin: _padding(node['margin']),
    color: _color(node['color']),
    shape: RoundedRectangleBorder(
      borderRadius: _radius(node['borderRadius']) ?? BorderRadius.circular(12),
    ),
    child: Padding(
      padding: _padding(node['padding'] ?? 16),
      child: _child(node['child']),
    ),
  );

  Widget _button(Map<String, dynamic> node, {required bool filled}) {
    final action = _str(node['action']) ?? '';
    final label = _str(node['label']) ?? _str(node['text']) ?? '';
    final params = node['params'] is Map
        ? Map<String, dynamic>.from(node['params'] as Map)
        : <String, dynamic>{};
    final enabled = node['enabled'] != false && action.isNotEmpty;
    final icon = _icon(_str(node['icon']));
    void onPressed() => _emit(action, params);

    if (!filled) {
      return IconButton(
        tooltip: label.isEmpty ? null : label,
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon ?? Icons.touch_app_rounded),
      );
    }
    if (icon == null) {
      return FilledButton(
        onPressed: enabled ? onPressed : null,
        child: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  void _emit(String action, Map<String, dynamic> params) {
    widget.onAction(action, <String, dynamic>{
      ...params,
      'fields': Map<String, String>.unmodifiable(_values),
    });
  }

  Widget _textField(Map<String, dynamic> node) {
    final id = _str(node['id']) ?? 'field_${identityHashCode(node)}';
    final controller = _controllers.putIfAbsent(
      id,
      () => TextEditingController(text: _values[id] ?? ''),
    );
    return TextField(
      controller: controller,
      obscureText: node['obscure'] == true,
      maxLines: _int(node['maxLines'], 1),
      keyboardType: node['keyboard'] == 'number' ? TextInputType.number : null,
      decoration: InputDecoration(
        labelText: _str(node['label']),
        hintText: _str(node['hint']),
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        _values[id] = value;
        widget.onFieldChanged?.call(id, value);
      },
    );
  }

  Widget _switch(Map<String, dynamic> node) {
    final id = _str(node['id'])?.trim() ?? '';
    if (id.isEmpty) return _imageError('switch 节点需要非空的 id。');
    final label = _str(node['label']) ?? id;
    final description = _str(node['description']) ?? _str(node['subtitle']);
    final fallback = node['default'] is bool ? node['default'] as bool : true;
    final stored = _config[id];
    final value = stored is bool ? stored : fallback;
    final enabled = node['enabled'] != false;
    return SwitchListTile(
      key: ValueKey<String>('plugin-switch:$id'),
      dense: node['dense'] == true,
      title: Text(label),
      subtitle: description == null ? null : Text(description),
      value: value,
      onChanged: enabled ? (next) => _updateSwitchValue(id, next) : null,
    );
  }

  void _updateSwitchValue(String id, bool value) {
    setState(() => _config[id] = value);
    _emit('config_update', <String, dynamic>{'key': id, 'value': value});
  }

  Widget _musicPlaylist(Map<String, dynamic> node) {
    final folder = _str(node['folder']) ?? '';
    final params = node['params'];
    final capsuleActions =
        node['capsule_actions'] ??
        (params is Map ? params['capsule_actions'] : null);
    return PluginMusicPlaylist(
      key: ValueKey<String>('musicPlaylist:$folder'),
      directory: widget.baseDirectory,
      folder: folder,
      granted: widget.grantedPermissions.contains('file_system'),
      onPlay: (relativePath, title, artist) =>
          _emit('audio_play', <String, dynamic>{
            'path': relativePath,
            'title': title,
            if (artist.isNotEmpty) 'artist': artist,
            if (capsuleActions is List) 'capsule_actions': capsuleActions,
          }),
    );
  }

  Widget _image(Map<String, dynamic> node) {
    final source = _str(node['src'])?.trim() ?? '';
    if (source.isEmpty) return _imageError('缺少图片地址');
    final width = _numOrNull(node['width']);
    final height = _numOrNull(node['height']);
    final fit = node['fit'] == 'contain' ? BoxFit.contain : BoxFit.cover;
    final uri = Uri.tryParse(source);
    Widget image;
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      image = Image.network(
        source,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _imageError('网络图片加载失败'),
      );
    } else {
      final target = PluginFileSandbox.resolveInRoots(source, <String?>[
        widget.baseDirectory,
        widget.dataDirectory,
      ]);
      if (target == null) return _imageError('图片路径越出了插件目录');
      image = Image.file(
        File(target),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _imageError('本地图片加载失败'),
      );
    }
    final radius = _radius(node['borderRadius']);
    return radius == null
        ? image
        : ClipRRect(borderRadius: radius, child: image);
  }

  Widget _imageError(String message) => Text(
    message,
    style: const TextStyle(fontSize: 11, color: Color(0xFFB3261E)),
  );

  Widget _listView(Map<String, dynamic> node) {
    final raw = node['children'];
    final items = raw is List ? raw.whereType<Map>().toList() : const <Map>[];
    final spacing = _num(node['spacing'], 8);
    final height = _num(node['height'], 320);
    return SizedBox(
      height: height,
      child: ListView.builder(
        padding: _padding(node['padding']),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final child = _node(Map<String, dynamic>.from(items[index]));
          if (index == items.length - 1) return child;
          return Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: child,
          );
        },
      ),
    );
  }

  /// Picks a child by window width: `breakpoints: [{minWidth, child}]`.
  Widget _responsive(Map<String, dynamic> node) {
    final raw = node['breakpoints'];
    final breakpoints = raw is List
        ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const <Map<String, dynamic>>[];
    return LayoutBuilder(
      builder: (context, constraints) {
        Map<String, dynamic>? chosen;
        for (final entry in breakpoints) {
          final minWidth = _num(entry['minWidth'], 0);
          if (constraints.maxWidth < minWidth) continue;
          if (chosen == null ||
              _num(entry['minWidth'], 0) > _num(chosen['minWidth'], 0)) {
            chosen = entry;
          }
        }
        if (chosen == null) return const SizedBox.shrink();
        return _child(chosen['child']);
      },
    );
  }

  Widget _webview(Map<String, dynamic> node) {
    final l10n = AppLocalizations.of(context);
    if (!widget.grantedPermissions.contains('webview')) {
      return _imageError(
        l10n?.pluginWebviewPermissionDenied ?? 'Permission denied: webview',
      );
    }
    final url = _str(node['url']) ?? _str(node['src']) ?? '';
    return Container(
      height: _num(node['height'], 240),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        border: Border.all(color: const Color(0x33000000)),
      ),
      child: Text(
        l10n?.pluginWebviewPlaceholder(url) ?? 'Webview: $url',
        textAlign: TextAlign.center,
      ),
    );
  }

  static String? _str(Object? value) => value is String ? value : null;

  static double? _numOrNull(Object? value) => value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value)
      : null;

  static double _num(Object? value, double fallback) =>
      _numOrNull(value) ?? fallback;
  static int _int(Object? value, int fallback) => value is num
      ? value.toInt()
      : value is String
      ? int.tryParse(value) ?? fallback
      : fallback;

  static int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

  EdgeInsets _padding(Object? raw) {
    if (raw is num) return EdgeInsets.all(raw.toDouble());
    if (raw is List) {
      final v = raw.map((e) => e is num ? e.toDouble() : 0.0).toList();
      if (v.length == 2) {
        return EdgeInsets.symmetric(horizontal: v[0], vertical: v[1]);
      }
      if (v.length == 4) {
        return EdgeInsets.fromLTRB(v[0], v[1], v[2], v[3]);
      }
      return EdgeInsets.all(v.isEmpty ? 0 : v.first);
    }
    if (raw is Map) {
      double read(String key) =>
          raw[key] is num ? (raw[key] as num).toDouble() : 0;
      final all = read('all'), h = read('horizontal'), v = read('vertical');
      return EdgeInsets.fromLTRB(
        read('left') + h + all,
        read('top') + v + all,
        read('right') + h + all,
        read('bottom') + v + all,
      );
    }
    return EdgeInsets.zero;
  }

  BorderRadius? _radius(Object? raw) {
    final value = raw is num
        ? raw
        : raw is List && raw.isNotEmpty && raw.first is num
        ? raw.first
        : raw is Map
        ? raw['all']
        : null;
    return value is num ? BorderRadius.circular(value.toDouble()) : null;
  }

  Border? _border(Map<String, dynamic> node) {
    final color = _color(node['borderColor']);
    final width = _num(node['borderWidth'], 0);
    if (color == null || width <= 0) return null;
    return Border.all(color: color, width: width);
  }

  Color? _color(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim().toLowerCase();
    const named = <String, Color>{
      'transparent': Colors.transparent,
      'white': Colors.white,
      'black': Colors.black,
      'red': Colors.red,
      'grey': Colors.grey,
    };
    final namedColor = named[value];
    if (namedColor != null) return namedColor;
    final hexValue = value.startsWith('#') ? value.substring(1) : value;
    final hex = hexValue.length == 6 ? 'ff$hexValue' : hexValue;
    final parsed = hex.length == 8 ? int.tryParse(hex, radix: 16) : null;
    return parsed == null ? null : Color(parsed);
  }

  MainAxisAlignment _mainAxis(Object? raw) => switch (raw) {
    'end' => MainAxisAlignment.end,
    'center' => MainAxisAlignment.center,
    'spaceBetween' => MainAxisAlignment.spaceBetween,
    _ => MainAxisAlignment.start,
  };

  CrossAxisAlignment _crossAxis(Object? raw) => switch (raw) {
    'end' => CrossAxisAlignment.end,
    'center' => CrossAxisAlignment.center,
    'stretch' => CrossAxisAlignment.stretch,
    _ => CrossAxisAlignment.start,
  };

  TextAlign _textAlign(Object? raw) => switch (raw) {
    'center' => TextAlign.center,
    _ => TextAlign.start,
  };

  TextOverflow? _overflow(Object? raw) => switch (raw) {
    'ellipsis' => TextOverflow.ellipsis,
    _ => null,
  };

  IconData? _icon(String? name) {
    final value = name?.trim();
    if (value == null || value.isEmpty) return null;
    return PluginIconMapper.getIcon(value);
  }
}
