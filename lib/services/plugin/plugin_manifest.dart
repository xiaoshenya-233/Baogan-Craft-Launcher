import 'dart:convert';

import 'package:path/path.dart' as p;

import 'plugin_icon_mapper.dart';

/// Permissions a plugin can request in its `plugin.json`.
///
/// The launcher does not grant anything implicitly: permissions are descriptive
/// for now and will gate the host APIs exposed in later phases.
class PluginPermissions {
  const PluginPermissions._();

  static const String download = 'download';
  static const String fileSystem = 'file_system';
  static const String network = 'network';
  static const String webview = 'webview';
  static const String execute = 'execute';
  static const String minecraftRead = 'minecraft_read';
  static const String hostFs = 'host_fs';

  static const Set<String> all = <String>{
    download,
    fileSystem,
    network,
    webview,
    execute,
    minecraftRead,
    hostFs,
  };
}

/// Corner used to anchor a plugin's floating UI.
enum PluginFloatingPosition {
  topLeft('topLeft'),
  topRight('topRight'),
  bottomLeft('bottomLeft'),
  bottomRight('bottomRight');

  const PluginFloatingPosition(this.jsonValue);

  final String jsonValue;

  static PluginFloatingPosition parse(Object? raw) {
    final value = raw is String ? raw.trim() : '';
    for (final position in values) {
      if (position.jsonValue == value) return position;
    }
    throw const FormatException(
      'floatingUi.position 必须是 topLeft、topRight、bottomLeft 或 bottomRight。',
    );
  }
}

/// How a floating UI decides which launcher pages it appears on.
enum PluginFloatingVisibilityMode {
  all('all'),
  whitelist('whitelist'),
  blacklist('blacklist');

  const PluginFloatingVisibilityMode(this.jsonValue);

  final String jsonValue;

  static PluginFloatingVisibilityMode parse(Object? raw) {
    if (raw == null) return PluginFloatingVisibilityMode.all;
    final value = raw is String ? raw.trim() : '';
    for (final mode in values) {
      if (mode.jsonValue == value) return mode;
    }
    throw const FormatException(
      'floatingUi.visibility.mode 必须是 all、whitelist 或 blacklist。',
    );
  }
}

/// Minimal `floatingUi` block of `plugin.json`.
///
/// ```json
/// "floatingUi": {
///   "entry": "floating.json",
///   "position": "bottomRight",
///   "visibility": { "mode": "whitelist", "pages": ["home", "downloads"] }
/// }
/// ```
class PluginFloatingUiConfig {
  const PluginFloatingUiConfig({
    required this.entry,
    required this.position,
    required this.mode,
    required this.pages,
  });

  /// Pages a plugin may reference in `visibility.pages`.
  static const Set<String> validPages = <String>{
    'home',
    'versions',
    'downloads',
    'download_tasks',
    'settings',
    'workbench',
  };

  static const int maxPages = 16;

  final String entry;
  final PluginFloatingPosition position;
  final PluginFloatingVisibilityMode mode;
  final List<String> pages;

  /// Black/white-list decision for one launcher page id.
  bool isVisibleOn(String pageId) => switch (mode) {
    PluginFloatingVisibilityMode.all => true,
    PluginFloatingVisibilityMode.whitelist => pages.contains(pageId),
    PluginFloatingVisibilityMode.blacklist => !pages.contains(pageId),
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'entry': entry,
    'position': position.jsonValue,
    'visibility': <String, dynamic>{'mode': mode.jsonValue, 'pages': pages},
  };

  factory PluginFloatingUiConfig.fromJson(Map<String, dynamic> json) {
    final rawEntry = json['entry'];
    final entry = rawEntry is String ? rawEntry.trim() : '';
    if (entry.isEmpty) {
      throw const FormatException('floatingUi.entry 不能为空。');
    }
    if (entry.length > PluginManifest.maxEntryUiLength) {
      throw const FormatException('floatingUi.entry 路径过长。');
    }
    PluginManifest._validateRelativeJsonPath(entry);

    final rawPosition = json['position'];
    final position = rawPosition == null
        ? PluginFloatingPosition.bottomRight
        : PluginFloatingPosition.parse(rawPosition);

    final rawVisibility = json['visibility'];
    if (rawVisibility == null) {
      return PluginFloatingUiConfig(
        entry: entry,
        position: position,
        mode: PluginFloatingVisibilityMode.all,
        pages: const <String>[],
      );
    }
    if (rawVisibility is! Map) {
      throw const FormatException('floatingUi.visibility 必须是对象。');
    }
    final visibility = Map<String, dynamic>.from(rawVisibility);
    final mode = PluginFloatingVisibilityMode.parse(visibility['mode']);
    return PluginFloatingUiConfig(
      entry: entry,
      position: position,
      mode: mode,
      pages: _parsePages(visibility['pages']),
    );
  }

  static List<String> _parsePages(Object? raw) {
    if (raw == null) return const <String>[];
    if (raw is! List) {
      throw const FormatException('floatingUi.visibility.pages 必须是数组。');
    }
    if (raw.length > maxPages) {
      throw const FormatException(
        'floatingUi.visibility.pages 最多 $maxPages 项。',
      );
    }
    final pages = <String>[];
    for (final item in raw) {
      if (item is! String) {
        throw const FormatException('floatingUi.visibility.pages 必须是字符串数组。');
      }
      final page = item.trim().toLowerCase().replaceAll('-', '_');
      if (!validPages.contains(page)) {
        throw FormatException('未知页面：$item（可用：${validPages.join(', ')}）');
      }
      if (!pages.contains(page)) pages.add(page);
    }
    return List<String>.unmodifiable(pages);
  }
}

///
/// The model is deliberately strict: identifiers become directory names, so
/// anything that could escape `BGCL/plugins_data/<id>/` is rejected.
/// One action executed automatically when the launcher starts.
///
/// The startup runner only executes a small safe whitelist through
/// `PluginActionDispatcher`, which still enforces declared permissions.
class PluginStartupAction {
  const PluginStartupAction({required this.action, this.params = const {}});

  final String action;
  final Map<String, dynamic> params;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'action': action,
    'params': params,
  };
}

class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.entryUi,
    required this.permissions,
    required this.directoryPath,
    this.floatingUi,
    this.startupActions = const <PluginStartupAction>[],
    this.icon,
    this.enableStartup = false,
  });

  static const int maxIdLength = 64;
  static const int maxNameLength = 80;
  static const int maxVersionLength = 32;
  static const int maxAuthorLength = 64;
  static const int maxDescriptionLength = 500;
  static const int maxEntryUiLength = 200;

  /// Lower-case, dot/dash/underscore separated identifier.
  static final RegExp idPattern = RegExp(r'^[a-z0-9][a-z0-9._-]*$');

  final String id;
  final String name;
  final String version;
  final String author;
  final String description;

  /// Relative path of the JSON UI document, e.g. `ui/main.json`.
  final String entryUi;

  /// Requested permissions, filtered against [PluginPermissions.all].
  final List<String> permissions;

  /// Optional floating UI shown above the launcher shell.
  final PluginFloatingUiConfig? floatingUi;

  /// Actions dispatched once after plugin scanning finishes.
  final List<PluginStartupAction> startupActions;

  /// Optional canonical Material icon name for the plugin card.
  final String? icon;

  /// Whether [startupActions] are allowed to run after scanning.
  final bool enableStartup;

  /// Absolute folder that contains `plugin.json`; not part of the JSON file.
  final String directoryPath;

  bool hasPermission(String permission) => permissions.contains(permission);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'version': version,
    'author': author,
    'description': description,
    'entryUi': entryUi,
    'permissions': permissions,
    if (floatingUi != null) 'floatingUi': floatingUi!.toJson(),
    if (icon != null) 'icon': icon,
    if (enableStartup) 'enableStartup': true,
    if (startupActions.isNotEmpty)
      'startupActions': startupActions
          .map((action) => action.toJson())
          .toList(growable: false),
  };

  /// Parses and validates one manifest.
  ///
  /// Throws [FormatException] with a user-readable message when a required
  /// field is missing, too long or unsafe.
  factory PluginManifest.fromJson(
    Map<String, dynamic> json, {
    required String directoryPath,
  }) {
    final id = _text(json, 'id', maxLength: maxIdLength);
    if (!idPattern.hasMatch(id)) {
      throw const FormatException('id 只能包含小写字母、数字、点、下划线和短横线。');
    }
    final entryUi = _text(
      json,
      'entryUi',
      maxLength: maxEntryUiLength,
      required: true,
    );
    _validateRelativeJsonPath(entryUi);

    return PluginManifest(
      id: id,
      name: _text(json, 'name', maxLength: maxNameLength),
      version: _text(json, 'version', maxLength: maxVersionLength),
      author: _text(
        json,
        'author',
        maxLength: maxAuthorLength,
        required: false,
      ),
      description: _text(
        json,
        'description',
        maxLength: maxDescriptionLength,
        required: false,
      ),
      entryUi: entryUi,
      permissions: _parsePermissions(json['permissions']),
      directoryPath: directoryPath,
      floatingUi: _parseFloatingUi(json['floatingUi']),
      startupActions: _parseStartupActions(json['startupActions']),
      icon: _parseIcon(json['icon']),
      enableStartup: _parseEnableStartup(json['enableStartup']),
    );
  }

  static bool _parseEnableStartup(Object? raw) {
    if (raw == null) return false;
    if (raw is! bool) {
      throw const FormatException('enableStartup 必须是布尔值。');
    }
    return raw;
  }

  /// Validates and canonicalises `icon`, warning instead of rejecting the
  /// manifest so a bad icon never takes the whole plugin offline.
  static String? _parseIcon(Object? raw) {
    if (raw == null) return null;
    if (raw is! String) {
      throw const FormatException('icon 必须是字符串。');
    }
    final canonical = PluginIconMapper.canonicalName(raw);
    if (canonical == null) {
      PluginIconMapper.warnInvalid(raw);
    }
    return canonical;
  }

  static List<PluginStartupAction> _parseStartupActions(Object? raw) {
    if (raw == null) return const <PluginStartupAction>[];
    if (raw is! List) {
      throw const FormatException('startupActions 必须是数组。');
    }
    if (raw.length > 32) {
      throw const FormatException('startupActions 最多 32 项。');
    }
    final actions = <PluginStartupAction>[];
    for (final item in raw) {
      if (item is! Map) {
        throw const FormatException('startupActions 的元素必须是对象。');
      }
      final action = item['action'];
      final name = action is String ? action.trim() : '';
      if (name.isEmpty || name.length > 80) {
        throw const FormatException('startupActions.action 无效。');
      }
      final rawParams = item['params'];
      if (rawParams != null && rawParams is! Map) {
        throw const FormatException('startupActions.params 必须是对象。');
      }
      actions.add(
        PluginStartupAction(
          action: name,
          params: rawParams == null
              ? const <String, dynamic>{}
              : Map<String, dynamic>.unmodifiable(
                  Map<String, dynamic>.from(rawParams),
                ),
        ),
      );
    }
    return List<PluginStartupAction>.unmodifiable(actions);
  }

  static PluginFloatingUiConfig? _parseFloatingUi(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) {
      throw const FormatException('floatingUi 必须是对象。');
    }
    return PluginFloatingUiConfig.fromJson(Map<String, dynamic>.from(raw));
  }

  static String _text(
    Map<String, dynamic> json,
    String key, {
    required int maxLength,
    bool required = true,
  }) {
    final value = json[key];
    final text = value is String ? value.trim() : '';
    if (text.isEmpty) {
      if (required) throw FormatException('缺少必填字段：$key');
      return '';
    }
    if (text.length > maxLength) {
      throw FormatException('$key 超过 $maxLength 个字符。');
    }
    return text;
  }

  static void _validateRelativeJsonPath(String value) {
    if (p.isAbsolute(value) ||
        value.startsWith('/') ||
        value.startsWith('\\')) {
      throw const FormatException('entryUi 必须是插件目录内的相对路径。');
    }
    if (!value.toLowerCase().endsWith('.json')) {
      throw const FormatException('entryUi 必须指向 .json 文件。');
    }
    for (final segment in value.replaceAll('\\', '/').split('/')) {
      if (segment == '..' || segment == '.' || segment.isEmpty) {
        throw const FormatException('entryUi 不能包含 . 或 .. 路径片段。');
      }
    }
  }

  static List<String> _parsePermissions(Object? value) {
    if (value == null) return const <String>[];
    if (value is! List) {
      throw const FormatException('permissions 必须是字符串数组。');
    }
    final result = <String>[];
    for (final item in value) {
      if (item is! String) {
        throw const FormatException('permissions 必须是字符串数组。');
      }
      final permission = item.trim();
      if (permission.isEmpty) continue;
      if (!PluginPermissions.all.contains(permission)) {
        throw FormatException(
          '未知权限：$permission（可用：${PluginPermissions.all.join(', ')}）',
        );
      }
      if (!result.contains(permission)) result.add(permission);
    }
    return List<String>.unmodifiable(result);
  }

  /// Reads a plugin.json body and parses it into a manifest.
  static PluginManifest fromJsonString(
    String source, {
    required String directoryPath,
  }) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('plugin.json 必须是 JSON 对象。');
    }
    return PluginManifest.fromJson(decoded, directoryPath: directoryPath);
  }
}
