import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../core/launcher_log.dart';
import '../../core/path_manager.dart';
import '../../core/path_utils.dart';
import '../../core/platform_launcher.dart';
import '../task/launcher_task.dart';
import '../task/task_activity_controller.dart';
import 'plugin_audio_service.dart';
import 'plugin_audio_task_bridge.dart';
import 'plugin_file_sandbox.dart';
import 'plugin_icon_mapper.dart';
import 'plugin_manifest.dart';
import 'plugin_manager.dart';
import 'plugin_music_playlist_service.dart';
import 'plugin_permission_service.dart';
import 'plugin_tool_service.dart';

/// Result of one plugin action round-trip.
enum PluginActionStatus { success, denied, invalid, failed }

class PluginActionResult {
  const PluginActionResult(
    this.status, {
    this.permission,
    this.message,
    this.data,
  });

  final PluginActionStatus status;

  /// Permission that the plugin was missing; only set for [denied].
  final String? permission;

  /// Human readable detail (plugin payload, file path or failure reason).
  final String? message;

  /// Action payload: file content for `read_file`, byte count for
  /// `write_file` / `download_file`.
  final Object? data;

  bool get isSuccess => status == PluginActionStatus.success;
}

/// Host callbacks used to land plugin actions inside the launcher shell.
typedef PluginNavigateAction = void Function(String page);
typedef PluginLaunchAction = Future<void> Function();

/// Runs one executable directly (never via a shell).
typedef PluginToolRunner = Future<PluginToolResult> Function(
  String executable,
  List<String> arguments,
  String workingDirectory,
);

/// Opens a validated plugin folder with the system file manager.
typedef PluginFolderRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Executes actions emitted by the plugin UI renderer after checking the
/// plugin's declared permissions.
///
/// Permission policy:
/// * `navigate_to` / `show_snackbar` – always allowed (pure UI navigation).
/// * `open_url` – requires `network`; only `http`/`https` URLs are accepted.
/// * `launch_game` – requires `file_system` (reads the selected version) and a
///   host launch callback that starts the currently selected client.
/// * `read_file` / `write_file` – require `file_system`; paths are sandboxed to
///   `BGCL/plugins_data/<plugin_id>/` by [PluginFileSandbox].
/// * `config_update` – writes one key to `plugins_data/<plugin_id>/config.json`;
///   it is restricted to the plugin's own sandbox and needs no extra permission.
/// * `open_folder` – requires `file_system`; creates and opens a folder inside
///   `plugins/<plugin_id>/` with the system file manager.
/// * `download_file` – requires `download`; saves into the same sandbox.
/// * `audio_play` – network URLs need `network`, sandboxed local files need
///   `file_system`; `audio_pause/resume/stop/toggle/volume/seek` control that
///   player.
/// * `execute_tool` – requires `execute`; the binary must live inside the
///   plugin folder or its data folder and is started without a shell.
/// * `task_register/update/remove` – plugin tasks in the activity capsule;
///   ids are namespaced as `plugin_<pluginId>_<taskId>`.
class PluginActionDispatcher {
  PluginActionDispatcher({
    required this.onNavigate,
    required this.onLaunchGame,
    this.onMessage,
    Future<void> Function(String url)? openUrl,
    Future<int> Function(String url, String targetPath)? downloadFile,
    PluginToolRunner? runTool,
    PluginFolderRunner? openFolder,
    PluginPermissionService? permissionService,
    this.uacPrompt,
  }) : _openUrl = openUrl ?? PlatformLauncher.openUrl,
       _downloadFile = downloadFile ?? _downloadWithDio,
       _runTool = runTool ?? PluginToolService.run,
       _openFolder = openFolder ?? Process.run,
       _permissions = permissionService ?? PluginPermissionService.instance;

  /// Maps each supported action to the permission it requires (`null` = none).
  static const Map<String, String?> actionPermissions = <String, String?>{
    'navigate_to': null,
    'show_snackbar': null,
    'open_url': PluginPermissions.network,
    'launch_game': PluginPermissions.fileSystem,
    'read_file': null,
    'write_file': PluginPermissions.fileSystem,
    'config_update': null,
    'open_folder': PluginPermissions.fileSystem,
    'list_plugin_files': null,
    'play_music_folder': PluginPermissions.fileSystem,
    'download_file': PluginPermissions.download,
    'audio_play': null,
    'audio_pause': null,
    'audio_resume': null,
    'audio_stop': null,
    'audio_next': null,
    'audio_prev': null,
    'audio_toggle': null,
    'audio_volume': null,
    'audio_seek': null,
    'execute_tool': PluginPermissions.execute,
    'task_register': null,
    'task_update': null,
    'task_remove': null,
  };

  /// Pages a plugin may navigate to, using launcher tab names.
  static const Set<String> navigationTargets = <String>{
    'home',
    'versions',
    'downloads',
    'download_tasks',
    'settings',
    'workbench',
    'plugins',
  };

  final PluginNavigateAction onNavigate;
  final PluginLaunchAction onLaunchGame;
  final void Function(String message)? onMessage;
  final Future<void> Function(String url) _openUrl;
  final Future<int> Function(String url, String targetPath) _downloadFile;
  final PluginToolRunner _runTool;
  final PluginFolderRunner _openFolder;
  final PluginPermissionService _permissions;

  /// UI callback; null outside a widget context (e.g. startup), where `ask`
  /// requests are denied instead of blocking forever.
  final PluginPermissionPrompt? uacPrompt;

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 2),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  static Future<int> _downloadWithDio(String url, String targetPath) async {
    await _dio.download(url, targetPath);
    return File(targetPath).length();
  }

  Future<PluginActionResult> dispatch(
    PluginManifest manifest,
    String action,
    Map<String, dynamic> params,
  ) async {
    final name = action.trim();
    if (!actionPermissions.containsKey(name)) {
      LauncherLog.warning('Plugins', '插件 ${manifest.id} 请求了未知操作：$name');
      return PluginActionResult(PluginActionStatus.invalid, message: name);
    }

    final permission = actionPermissions[name];
    final specialReadAllowed =
        name == 'read_file' && _hasReadPermission(manifest);
    if (permission != null &&
        !manifest.hasPermission(permission) &&
        !specialReadAllowed) {
      LauncherLog.warning(
        'Plugins',
        '权限不足：插件 ${manifest.id} 缺少 $permission 权限，无法执行 $name。',
      );
      return PluginActionResult(
        PluginActionStatus.denied,
        permission: permission,
        message: name,
      );
    }

    try {
      switch (name) {
        case 'navigate_to':
          return _navigate(manifest, params);
        case 'show_snackbar':
          final message = _text(params['message'] ?? params['text']);
          if (message == null) {
            return const PluginActionResult(
              PluginActionStatus.invalid,
              message: 'show_snackbar 缺少 message 参数。',
            );
          }
          onMessage?.call(message);
          LauncherLog.info('Plugins', '插件 ${manifest.id} 提示：$message');
          return const PluginActionResult(PluginActionStatus.success);
        case 'open_url':
          return await _openUri(manifest, params);
        case 'launch_game':
          await onLaunchGame();
          LauncherLog.info('Plugins', '插件 ${manifest.id} 请求启动游戏。');
          return const PluginActionResult(PluginActionStatus.success);
        case 'read_file':
          return await _readFile(manifest, params);
        case 'write_file':
          return await _writeFile(manifest, params);
        case 'config_update':
          return await _updateConfig(manifest, params);
        case 'open_folder':
          return await _openPluginFolder(manifest, params);
        case 'list_plugin_files':
          return await _listPluginFiles(manifest, params);
        case 'play_music_folder':
          return await _playMusicFolder(manifest, params);
        case 'download_file':
          return await _download(manifest, params);
        case 'audio_play':
          return await _audioPlay(manifest, params);
        case 'audio_pause':
          await PluginAudioService.instance.pause();
          return const PluginActionResult(PluginActionStatus.success);
        case 'audio_resume':
          await PluginAudioService.instance.resume();
          return const PluginActionResult(PluginActionStatus.success);
        case 'audio_toggle':
          return await _audioToggle();
        case 'audio_stop':
          await PluginMusicPlaylistService.instance.stop();
          return const PluginActionResult(PluginActionStatus.success);
        case 'audio_next':
          return await _audioSkip(next: true);
        case 'audio_prev':
          return await _audioSkip(next: false);
        case 'audio_volume':
          return await _audioVolume(params);
        case 'audio_seek':
          return await _audioSeek(params);
        case 'execute_tool':
          return await _executeTool(manifest, params);
        case 'task_register':
          return _taskRegister(manifest, params);
        case 'task_update':
          return _taskUpdate(manifest, params);
        case 'task_remove':
          return _taskRemove(manifest, params);
      }
    } on Object catch (error) {
      LauncherLog.warning('Plugins', '插件 ${manifest.id} 执行 $name 失败：$error');
      return PluginActionResult(
        PluginActionStatus.failed,
        message: error.toString(),
      );
    }
    return PluginActionResult(PluginActionStatus.invalid, message: name);
  }

  PluginActionResult _navigate(
    PluginManifest manifest,
    Map<String, dynamic> params,
  ) {
    final page = _text(params['page'] ?? params['target'] ?? params['tab']);
    final target = page?.toLowerCase().replaceAll('-', '_');
    if (target == null || !navigationTargets.contains(target)) {
      return PluginActionResult(
        PluginActionStatus.invalid,
        message: page ?? 'navigate_to',
      );
    }
    onNavigate(target);
    LauncherLog.info('Plugins', '插件 ${manifest.id} 跳转到页面：$target');
    return const PluginActionResult(PluginActionStatus.success);
  }

  Future<PluginActionResult> _openUri(
    PluginManifest manifest,
    Map<String, dynamic> params,
  ) async {
    final raw = _text(params['url'] ?? params['href']);
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return PluginActionResult(
        PluginActionStatus.invalid,
        message: raw ?? 'open_url',
      );
    }
    await _openUrl(uri.toString());
    LauncherLog.info('Plugins', '插件 ${manifest.id} 打开链接：$uri');
    return const PluginActionResult(PluginActionStatus.success);
  }

  Future<PluginActionResult> _readFile(
    PluginManifest manifest,
    Map<String, dynamic> params,
  ) async {
    final requested = _filePath(params);
    if (requested == null) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'read_file 缺少 path 参数。',
      );
    }
    LauncherLog.info(
      'Plugins',
      'read_file 请求：插件 ${manifest.id}，路径=$requested，'
          '权限=${manifest.permissions}',
    );

    if (p.isAbsolute(requested)) {
      final target = p.normalize(p.absolute(requested));
      if (_isInsidePluginSandbox(manifest, target)) {
        if (!manifest.hasPermission(PluginPermissions.fileSystem)) {
          return _deny(manifest, 'read_file', PluginPermissions.fileSystem);
        }
        return _readAbsoluteFile(target, requested);
      }
      final permission = _hostReadPermission(manifest, target);
      if (permission == null) {
        return _deny(manifest, 'read_file', PluginPermissions.hostFs);
      }
      final allowed = await _permissions.authorize(
        manifest: manifest,
        permission: permission,
        path: target,
        prompt: uacPrompt,
      );
      if (!allowed) {
        return PluginActionResult(
          PluginActionStatus.denied,
          permission: permission,
          message: requested,
        );
      }
      return _readAbsoluteFile(target, requested);
    }

    if (_hasParentTraversal(requested)) {
      final target = p.normalize(
        p.absolute(p.join(manifest.directoryPath, requested)),
      );
      if (_isInsidePluginSandbox(manifest, target)) {
        if (!manifest.hasPermission(PluginPermissions.fileSystem)) {
          return _deny(manifest, 'read_file', PluginPermissions.fileSystem);
        }
        return _readAbsoluteFile(target, requested);
      }
      final permission = _hostReadPermission(manifest, target);
      if (permission == null) {
        return _deny(manifest, 'read_file', PluginPermissions.hostFs);
      }
      final allowed = await _permissions.authorize(
        manifest: manifest,
        permission: permission,
        path: target,
        prompt: uacPrompt,
      );
      if (!allowed) {
        return PluginActionResult(
          PluginActionStatus.denied,
          permission: permission,
          message: requested,
        );
      }
      return _readAbsoluteFile(target, requested);
    }

    if (!manifest.hasPermission(PluginPermissions.fileSystem)) {
      return _deny(manifest, 'read_file', PluginPermissions.fileSystem);
    }
    final content = await PluginFileSandbox.read(manifest.id, requested);
    LauncherLog.info('Plugins', '插件 ${manifest.id} 读取文件：$requested');
    return PluginActionResult(
      PluginActionStatus.success,
      message: requested,
      data: content,
    );
  }

  Future<PluginActionResult> _readAbsoluteFile(
    String absolutePath,
    String displayPath,
  ) async {
    final file = File(absolutePath);
    if (!await file.exists()) {
      return PluginActionResult(
        PluginActionStatus.failed,
        message: '文件不存在：$displayPath',
      );
    }
    final length = await file.length();
    if (length > PluginFileSandbox.maxReadBytes) {
      return const PluginActionResult(
        PluginActionStatus.failed,
        message: '文件超过 512 KB 读取上限。',
      );
    }
    final content = await file.readAsString();
    LauncherLog.info('Plugins', '读取宿主文件：$absolutePath');
    return PluginActionResult(
      PluginActionStatus.success,
      message: displayPath,
      data: content,
    );
  }

  bool _isInsidePluginSandbox(PluginManifest manifest, String absolutePath) {
    final targets = <String?>[
      manifest.directoryPath,
      PluginManager.instance.dataDirectoryFor(manifest.id),
    ];
    for (final root in targets) {
      if (root == null || root.trim().isEmpty) continue;
      if (p.equals(absolutePath, root) || isPathInside(absolutePath, root)) {
        return true;
      }
    }
    return false;
  }

  Future<PluginActionResult> _listAbsoluteDirectory(
    String target,
    String displayPath,
  ) async {
    final directory = Directory(target);
    if (!await directory.exists()) {
      return PluginActionResult(
        PluginActionStatus.failed,
        message: '目录不存在：$displayPath',
      );
    }
    final names = <String>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File) names.add(p.basename(entity.path));
    }
    names.sort();
    return PluginActionResult(
      PluginActionStatus.success,
      message: displayPath,
      data: names,
    );
  }

  bool _hasParentTraversal(String value) =>
      value.trim().replaceAll('\\', '/').split('/').contains('..');

  /// True when the plugin declared any permission that can open a host read
  /// UAC flow.
  bool _hasReadPermission(PluginManifest manifest) =>
      manifest.hasPermission(PluginPermissions.fileSystem) ||
      manifest.hasPermission(PluginPermissions.minecraftRead) ||
      manifest.hasPermission(PluginPermissions.hostFs);

  /// Returns the declared host-read permission, or `null` when neither
  /// `minecraft_read` nor `host_fs` was requested.
  ///
  /// Out-of-sandbox reads must never check a literal `read_file` permission:
  /// the manifest does not contain one. A declared special permission reaches
  /// [PluginPermissionService.authorize], which applies the persisted
  /// “always allow” decision or shows the UAC dialog.
  String? _hostReadPermission(PluginManifest manifest, String absolutePath) {
    final canReadMinecraft = manifest.hasPermission(
      PluginPermissions.minecraftRead,
    );
    final canReadHost = manifest.hasPermission(PluginPermissions.hostFs);
    final canReadFileSystem = manifest.hasPermission(
      PluginPermissions.fileSystem,
    );
    if (!canReadMinecraft && !canReadHost && !canReadFileSystem) return null;
    final gameRoot = PathManager.instance.minecraftPath;
    final insideGame =
        gameRoot != null &&
        (p.equals(absolutePath, gameRoot) ||
            isPathInside(absolutePath, gameRoot));
    if (insideGame && canReadMinecraft) {
      return PluginPermissions.minecraftRead;
    }
    if (canReadHost) return PluginPermissions.hostFs;
    if (canReadMinecraft) return PluginPermissions.minecraftRead;
    return PluginPermissions.fileSystem;
  }

  Future<PluginActionResult> _writeFile(
    PluginManifest manifest,
    Map<String, dynamic> params,
  ) async {
    final relative = _filePath(params);
    if (relative == null) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'write_file 缺少 path 参数。',
      );
    }
    final raw = params['content'] ?? params['text'] ?? params['data'];
    if (raw == null) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'write_file 缺少 content 参数。',
      );
    }
    final content = raw is String ? raw : jsonEncode(raw);
    final bytes = await PluginFileSandbox.write(manifest.id, relative, content);
    LauncherLog.info('Plugins', '插件 ${manifest.id} 写入文件：$relative（$bytes 字节）');
    return PluginActionResult(
      PluginActionStatus.success,
      message: relative,
      data: bytes,
    );
  }

  Future<PluginActionResult> _openPluginFolder(
    PluginManifest manifest,
    Map<String, dynamic> params,
  ) async {
    final raw = params['folder'] ?? params['path'];
    if (raw != null && raw is! String) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'open_folder 的 folder 必须是字符串。',
      );
    }
    final folder = raw is String ? raw.trim() : '';
    final directory = PluginFileSandbox.resolvePluginDirectory(
      manifest,
      folder,
    );
    if (directory == null) {
      return PluginActionResult(
        PluginActionStatus.invalid,
        message: '路径不在插件目录内或不安全：$folder',
      );
    }
    try {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final executable = Platform.isWindows
          ? 'explorer'
          : Platform.isMacOS
          ? 'open'
          : 'xdg-open';
      final result = await _openFolder(executable, <String>[directory.path]);
      if (!Platform.isWindows && result.exitCode != 0) {
        final detail = result.stderr?.toString().trim() ?? '';
        return PluginActionResult(
          PluginActionStatus.failed,
          message: detail.isEmpty
              ? '打开文件夹失败（退出码 ${result.exitCode}）。'
              : '打开文件夹失败：$detail',
        );
      }
      LauncherLog.info('Plugins', '插件 ${manifest.id} 打开目录：${directory.path}');
      return PluginActionResult(
        PluginActionStatus.success,
        message: folder.isEmpty ? '.' : folder,
        data: directory.path,
      );
    } on FileSystemException catch (error) {
      return PluginActionResult(
        PluginActionStatus.failed,
        message: '无法创建或访问文件夹：${error.message}',
      );
    } on Object catch (error) {
      return PluginActionResult(
        PluginActionStatus.failed,
        message: '打开文件夹失败：$error',
      );
    }
  }

  Future<PluginActionResult> _updateConfig(
    PluginManifest manifest,
    Map<String, dynamic> params,
  ) async {
    final key = _text(params['key'] ?? params['id'] ?? params['name']);
    if (key == null || key.length > 80) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'config_update 需要 1~80 个字符的 key 参数。',
      );
    }
    if (!params.containsKey('value')) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'config_update 缺少 value 参数。',
      );
    }
    final bytes = await PluginFileSandbox.updateConfig(
      manifest.id,
      key,
      params['value'],
    );
    LauncherLog.info('Plugins', '插件 ${manifest.id} 更新配置：$key');
    return PluginActionResult(
      PluginActionStatus.success,
      message: PluginFileSandbox.configFileName,
      data: bytes,
    );
  }

  Future<PluginActionResult> _listPluginFiles(
    PluginManifest manifest,
    Map<String, dynamic> params,
  ) async {
    final folder = _text(params['folder'] ?? params['path']) ?? '';
    if (p.isAbsolute(folder)) {
      final target = p.normalize(p.absolute(folder));
      if (_isInsidePluginSandbox(manifest, target)) {
        if (!manifest.hasPermission(PluginPermissions.fileSystem)) {
          return _deny(
            manifest,
            'list_plugin_files',
            PluginPermissions.fileSystem,
          );
        }
        return _listAbsoluteDirectory(target, folder);
      }
      final permission = _hostReadPermission(manifest, target);
      if (permission == null) {
        return _deny(manifest, 'list_plugin_files', PluginPermissions.hostFs);
      }
      final allowed = await _permissions.authorize(
        manifest: manifest,
        permission: permission,
        path: target,
        prompt: uacPrompt,
      );
      if (!allowed) {
        return PluginActionResult(
          PluginActionStatus.denied,
          permission: permission,
          message: folder,
        );
      }
      return _listAbsoluteDirectory(target, folder);
    }

    if (_hasParentTraversal(folder)) {
      final target = p.normalize(
        p.absolute(p.join(manifest.directoryPath, folder)),
      );
      if (_isInsidePluginSandbox(manifest, target)) {
        if (!manifest.hasPermission(PluginPermissions.fileSystem)) {
          return _deny(
            manifest,
            'list_plugin_files',
            PluginPermissions.fileSystem,
          );
        }
        return _listAbsoluteDirectory(target, folder);
      }
      final permission = _hostReadPermission(manifest, target);
      if (permission == null) {
        return _deny(manifest, 'list_plugin_files', PluginPermissions.hostFs);
      }
      final allowed = await _permissions.authorize(
        manifest: manifest,
        permission: permission,
        path: target,
        prompt: uacPrompt,
      );
      if (!allowed) {
        return PluginActionResult(
          PluginActionStatus.denied,
          permission: permission,
          message: folder,
        );
      }
      return _listAbsoluteDirectory(target, folder);
    }

    if (!manifest.hasPermission(PluginPermissions.fileSystem)) {
      return _deny(manifest, 'list_plugin_files', PluginPermissions.fileSystem);
    }
    final files = await PluginFileSandbox.listPluginFiles(manifest, folder);
    LauncherLog.info(
      'Plugins',
      '插件 ${manifest.id} 列出目录：${folder.isEmpty ? '<root>' : folder}（${files.length} 个文件）',
    );
    return PluginActionResult(
      PluginActionStatus.success,
      message: folder,
      data: files,
    );
  }

  Future<PluginActionResult> _playMusicFolder(
    PluginManifest manifest,
    Map<String, dynamic> params,
  ) async {
    final folder = _text(params['folder']) ?? '';
    final tracks = await PluginMusicPlaylistService.instance.start(
      manifest,
      folder,
      actions: _pluginTaskActions(manifest, params['capsule_actions']),
    );
    LauncherLog.info(
      'Plugins',
      '插件 ${manifest.id} 播放音乐目录：${folder.isEmpty ? '<root>' : folder}（${tracks.length} 首）',
    );
    return PluginActionResult(
      PluginActionStatus.success,
      message: folder,
      data: tracks.map((track) => track.toJson()).toList(growable: false),
    );
  }

  Future<PluginActionResult> _download(
    PluginManifest manifest,
    Map<String, dynamic> params,
  ) async {
    final rawUrl = _text(params['url'] ?? params['href']);
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return PluginActionResult(
        PluginActionStatus.invalid,
        message: rawUrl ?? 'download_file',
      );
    }
    final relative = _filePath(params);
    if (relative == null) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'download_file 缺少 savePath 参数。',
      );
    }
    final target = await PluginFileSandbox.prepareDownload(
      manifest.id,
      relative,
    );
    final bytes = await _downloadFile(uri.toString(), target);
    LauncherLog.info('Plugins', '插件 ${manifest.id} 下载完成：$relative（$bytes 字节）');
    return PluginActionResult(
      PluginActionStatus.success,
      message: relative,
      data: bytes,
    );
  }

  static final RegExp _taskIdPattern = RegExp(r'^[A-Za-z0-9._-]{1,64}$');

  PluginActionResult _taskRegister(
    PluginManifest manifest,
    Map<String, dynamic> params,
  ) {
    final rawId = _text(params['id']);
    final title = _text(params['title']);
    if (rawId == null || !_taskIdPattern.hasMatch(rawId)) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'task_register 的 id 无效。',
      );
    }
    if (title == null) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'task_register 缺少 title 参数。',
      );
    }
    final rawProgress = params['progress'];
    final progress = _number(rawProgress);
    if (rawProgress != null && progress == null) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'task_register 的 progress 必须是 0.0~1.0。',
      );
    }
    final taskId = _pluginTaskId(manifest.id, rawId);
    TaskActivityController.instance.addTask(
      LauncherTask(
        id: taskId,
        title: title,
        icon: launcherTaskIcon(_text(params['icon'])),
        progress: progress?.clamp(0.0, 1.0).toDouble(),
        actions: _pluginTaskActions(manifest, params['actions']),
      ),
    );
    return PluginActionResult(PluginActionStatus.success, message: taskId);
  }

  PluginActionResult _taskUpdate(
    PluginManifest manifest,
    Map<String, dynamic> params,
  ) {
    final rawId = _text(params['id']);
    if (rawId == null || !_taskIdPattern.hasMatch(rawId)) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'task_update 的 id 无效。',
      );
    }
    final taskId = _pluginTaskId(manifest.id, rawId);
    if (TaskActivityController.instance.taskById(taskId) == null) {
      return PluginActionResult(
        PluginActionStatus.failed,
        message: '任务不存在：$taskId',
      );
    }
    final hasProgress = params.containsKey('progress');
    final rawProgress = params['progress'];
    final progress = _number(rawProgress);
    if (hasProgress && rawProgress != null && progress == null) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'task_update 的 progress 必须是数字。',
      );
    }
    TaskActivityController.instance.updateTask(
      taskId,
      progress: progress,
      indeterminate: hasProgress && rawProgress == null,
      subText: _text(params['subText']),
    );
    return PluginActionResult(PluginActionStatus.success, message: taskId);
  }

  PluginActionResult _taskRemove(
    PluginManifest manifest,
    Map<String, dynamic> params,
  ) {
    final rawId = _text(params['id']);
    if (rawId == null || !_taskIdPattern.hasMatch(rawId)) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'task_remove 的 id 无效。',
      );
    }
    final taskId = _pluginTaskId(manifest.id, rawId);
    TaskActivityController.instance.removeTask(taskId);
    return PluginActionResult(PluginActionStatus.success, message: taskId);
  }

  List<LauncherTaskAction> _pluginTaskActions(
    PluginManifest manifest,
    Object? raw,
  ) {
    if (raw is! List) return const <LauncherTaskAction>[];
    final actions = <LauncherTaskAction>[];
    for (final item in raw.take(6)) {
      if (item is! Map) continue;
      final action = _text(item['action']);
      if (action == null) continue;
      final icon = PluginIconMapper.sanitizeName(_text(item['icon']) ?? 'play');
      final actionParams = item['params'] is Map
          ? Map<String, dynamic>.from(item['params'] as Map)
          : <String, dynamic>{};
      actions.add(
        LauncherTaskAction(
          icon: icon,
          tooltip: _text(item['tooltip']) ?? action,
          action: action,
          onPressed: () =>
              unawaited(_runTaskAction(manifest, action, actionParams)),
        ),
      );
    }
    return List<LauncherTaskAction>.unmodifiable(actions);
  }

  Future<void> _runTaskAction(
    PluginManifest manifest,
    String action,
    Map<String, dynamic> params,
  ) async {
    final result = await dispatch(manifest, action, params);
    if (!result.isSuccess) {
      LauncherLog.warning(
        'Plugins',
        '插件 ${manifest.id} 的胶囊按钮执行 $action 失败：${result.message}',
      );
    }
  }

  static String _pluginTaskId(String pluginId, String taskId) =>
      'plugin_${pluginId}_$taskId';

  Future<PluginActionResult> _executeTool(
    PluginManifest manifest,
    Map<String, dynamic> params,
  ) async {
    final relative = _text(params['path'] ?? params['tool']);
    if (relative == null) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'execute_tool 缺少 path 参数。',
      );
    }
    final rawArgs = params['args'];
    if (rawArgs != null && rawArgs is! List) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'execute_tool 的 args 必须是字符串数组。',
      );
    }
    if (rawArgs is List && rawArgs.any((item) => item is! String)) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'execute_tool 的 args 必须是字符串数组。',
      );
    }
    final args = rawArgs is List
        ? rawArgs.cast<String>().toList(growable: false)
        : const <String>[];

    final executable = PluginFileSandbox.resolveReadable(manifest, relative);
    if (executable == null) {
      return const PluginActionResult(
        PluginActionStatus.failed,
        message: '安全拦截：非法工具路径。',
      );
    }
    if (!await File(executable).exists()) {
      return PluginActionResult(
        PluginActionStatus.failed,
        message: '工具不存在：$relative',
      );
    }

    final result = await _runTool(executable, args, p.dirname(executable));
    LauncherLog.info(
      'Plugins',
      '插件 ${manifest.id} 执行工具：$relative（exit ${result.exitCode}）',
    );
    return PluginActionResult(
      PluginActionStatus.success,
      message: relative,
      data: result.toJson(),
    );
  }

  Future<PluginActionResult> _audioPlay(
    PluginManifest manifest,
    Map<String, dynamic> params,
  ) async {
    final raw = _text(params['url'] ?? params['path'] ?? params['source']);
    if (raw == null) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'audio_play 缺少 url 或 path 参数。',
      );
    }
    final title = _text(params['title'] ?? params['song']);
    final artist = _text(params['artist'] ?? params['author']);
    if (PluginAudioService.isNetworkSource(raw)) {
      if (!manifest.hasPermission(PluginPermissions.network)) {
        return _deny(manifest, 'audio_play', PluginPermissions.network);
      }
      await PluginAudioService.instance.play(raw);
      PluginMusicPlaylistService.instance.deactivate();
      _registerAudioTask(manifest, params, title, artist);
      LauncherLog.info('Plugins', '插件 ${manifest.id} 播放网络音频：$raw');
      return PluginActionResult(PluginActionStatus.success, message: raw);
    }

    if (!manifest.hasPermission(PluginPermissions.fileSystem)) {
      return _deny(manifest, 'audio_play', PluginPermissions.fileSystem);
    }
    final path = PluginFileSandbox.resolveReadable(manifest, raw);
    if (path == null) {
      return const PluginActionResult(
        PluginActionStatus.failed,
        message: '本地音频路径必须位于插件目录或数据目录内。',
      );
    }
    if (!await File(path).exists()) {
      return PluginActionResult(
        PluginActionStatus.failed,
        message: '音频文件不存在：$raw',
      );
    }
    await PluginAudioService.instance.play(path);
    PluginMusicPlaylistService.instance.deactivate();
    _registerAudioTask(manifest, params, title, artist);
    LauncherLog.info('Plugins', '插件 ${manifest.id} 播放本地音频：$raw');
    return PluginActionResult(PluginActionStatus.success, message: raw);
  }

  void _registerAudioTask(
    PluginManifest manifest,
    Map<String, dynamic> params,
    String? title,
    String? artist,
  ) {
    if (title == null) return;
    final display = artist == null ? '正在播放: $title' : '正在播放: $title - $artist';
    PluginAudioTaskBridge.instance.start(
      title: display,
      actions: _pluginTaskActions(manifest, params['capsule_actions']),
    );
  }

  Future<PluginActionResult> _audioVolume(Map<String, dynamic> params) async {
    final volume = _number(params['volume']);
    if (volume == null || volume < 0 || volume > 1) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'audio_volume 需要 0.0~1.0 之间的 volume 参数。',
      );
    }
    await PluginAudioService.instance.setVolume(volume);
    return PluginActionResult(PluginActionStatus.success, data: volume);
  }

  Future<PluginActionResult> _audioToggle() async {
    final audio = PluginAudioService.instance;
    if (!audio.hasSource) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'audio_toggle 需要先播放音频。',
      );
    }
    if (audio.playing) {
      await audio.pause();
      return const PluginActionResult(
        PluginActionStatus.success,
        message: 'paused',
      );
    }
    await audio.resume();
    return const PluginActionResult(
      PluginActionStatus.success,
      message: 'resumed',
    );
  }

  Future<PluginActionResult> _audioSkip({required bool next}) async {
    final moved = next
        ? await PluginMusicPlaylistService.instance.next()
        : await PluginMusicPlaylistService.instance.previous();
    if (!moved) {
      return const PluginActionResult(
        PluginActionStatus.failed,
        message: '当前没有可切换的播放列表。',
      );
    }
    return const PluginActionResult(PluginActionStatus.success);
  }

  Future<PluginActionResult> _audioSeek(Map<String, dynamic> params) async {
    final seconds = _number(params['seconds'] ?? params['position']);
    if (seconds == null || seconds < 0) {
      return const PluginActionResult(
        PluginActionStatus.invalid,
        message: 'audio_seek 需要非负的 seconds 参数。',
      );
    }
    final position = Duration(milliseconds: (seconds * 1000).round());
    await PluginAudioService.instance.seek(position);
    return PluginActionResult(
      PluginActionStatus.success,
      message: seconds.toString(),
      data: position,
    );
  }

  PluginActionResult _deny(
    PluginManifest manifest,
    String action,
    String permission,
  ) {
    LauncherLog.warning(
      'Plugins',
      '权限不足：插件 ${manifest.id} 缺少 $permission 权限，无法执行 $action。',
    );
    return PluginActionResult(
      PluginActionStatus.denied,
      permission: permission,
      message: action,
    );
  }

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static String? _filePath(Map<String, dynamic> params) =>
      _text(params['path'] ?? params['savePath'] ?? params['file']);

  static String? _text(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }
}
