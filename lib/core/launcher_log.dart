import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'format_utils.dart';
import 'path_manager.dart';

const String _debugFontFamily = 'SourceHanSansSC';

/// Returns the log file path when this process was started as the standalone
/// debug-log viewer. Supports both `--debug-log-window=<path>` and
/// `--debug-log-window <path>`.
String? debugLogWindowPathFromArgs(List<String> args) {
  for (var index = 0; index < args.length; index++) {
    const prefix = '--debug-log-window=';
    final argument = args[index];
    if (argument.startsWith(prefix)) {
      final path = argument.substring(prefix.length).trim();
      if (path.isNotEmpty) return path;
    }
    if (argument == '--debug-log-window' && index + 1 < args.length) {
      final path = args[index + 1].trim();
      if (path.isNotEmpty) return path;
    }
  }
  return null;
}

/// Masks an identifier while retaining only a tiny, non-reversible hint.
String _maskLogIdentifier(String value) {
  if (value.isEmpty || value.contains('***')) return value;
  final visible = value.length >= 6 ? 2 : 1;
  return '${value.substring(0, visible)}***';
}

/// Removes credentials that may appear in launch commands and game output.
String redactLogSecrets(String value) {
  var result = value;
  result = result.replaceAllMapped(
    RegExp(r'(--accessToken\s+)(\S+)', caseSensitive: false),
    (match) => '${match[1]}***',
  );
  result = result.replaceAllMapped(
    RegExp(r'(access[_-]?token\s*[=:]\s*)(\S+)', caseSensitive: false),
    (match) => '${match[1]}***',
  );
  result = result.replaceAllMapped(
    RegExp(r'(Authorization\s*:\s*Bearer\s+)(\S+)', caseSensitive: false),
    (match) => '${match[1]}***',
  );
  // Passwords and OAuth secrets must never reach the log file either.
  result = result.replaceAllMapped(
    RegExp(
      r'((?:password|passwd|pwd)\s*[=:]\s*)([^\s&,;]+)',
      caseSensitive: false,
    ),
    (match) => '${match[1]}***',
  );
  result = result.replaceAllMapped(
    RegExp(
      r'((?:refresh[_-]?token|client[_-]?secret)\s*[=:]\s*)([^\s&,;]+)',
      caseSensitive: false,
    ),
    (match) => '${match[1]}***',
  );
  result = result.replaceAll(
    RegExp(r'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}'),
    '***',
  );
  // Player UUIDs identify an account; never write them to the log file.
  result = result.replaceAll(
    RegExp(
      r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b',
    ),
    '***',
  );
  // Some providers (e.g. LittleSkin) use compact 32-character UUIDs.
  result = result.replaceAll(RegExp(r'\b[0-9a-fA-F]{32}\b'), '***');
  // Avatar/profile URLs often embed the player name or UUID. Keep only a tiny
  // prefix so the log can identify the endpoint without identifying the player.
  result = result.replaceAllMapped(
    RegExp(
      r'(/(?:avatar/player|avatar|textures|profiles|'
      r'sessionserver/session/minecraft/profile)/)([^/?#\s]+)',
      caseSensitive: false,
    ),
    (match) => '${match[1]}${_maskLogIdentifier(match[2]!)}',
  );
  result = result.replaceAllMapped(
    RegExp(
      r'((?:username|player[_-]?name|profile[_-]?name)\s*[=:]\s*)'
      r'([^\s&,;]+)',
      caseSensitive: false,
    ),
    (match) => '${match[1]}${_maskLogIdentifier(match[2]!)}',
  );
  return result;
}

/// Rewrites a legacy log file after masking secrets. Returns whether it changed.
Future<bool> sanitizeLogFileSecrets(File file) async {
  try {
    if (!await file.exists()) return false;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return false;
    final content = utf8.decode(bytes, allowMalformed: true);
    final safe = redactLogSecrets(content);
    if (safe == content) return false;
    await file.writeAsString(safe, flush: true);
    return true;
  } catch (_) {
    return false;
  }
}

/// Reads the tail of a UTF-8 log file without keeping the whole file in memory.
Future<({String content, bool truncated})> readLogTail(
  String path, {
  int maxBytes = 512 * 1024,
}) async {
  final file = File(path);
  if (!await file.exists()) {
    return (content: '', truncated: false);
  }
  final length = await file.length();
  final start = math.max(0, length - math.max(1, maxBytes)).toInt();
  final handle = await file.open();
  late List<int> bytes;
  try {
    await handle.setPosition(start);
    bytes = await handle.read(length - start);
  } finally {
    await handle.close();
  }
  var content = utf8.decode(bytes, allowMalformed: true);
  final truncated = start > 0;
  if (truncated) {
    final newline = content.indexOf('\n');
    if (newline >= 0 && newline + 1 < content.length) {
      content = content.substring(newline + 1);
    }
    content =
        '…（仅显示日志末尾 ${formatByteSize(start)} 之后的 '
        '${formatByteSize(length - start)}）\n$content';
  }
  // Logs written by older builds may predate write-side redaction.
  content = redactLogSecrets(content);
  return (content: content, truncated: truncated);
}

Future<void> openLocalDirectory(String path) async {
  if (Platform.isWindows) {
    await Process.start('explorer.exe', [path]);
  } else if (Platform.isMacOS) {
    await Process.start('open', [path]);
  } else {
    await Process.start('xdg-open', [path]);
  }
}

/// Process-wide append-only debug log. It is enabled by default; the settings
/// page can disable it and the standalone viewer reads the same file.
class LauncherLog {
  LauncherLog._();

  static const String fileName = 'launcher.log';
  static const int maxFileBytes = 8 * 1024 * 1024;
  static const int maxMessageChars = 200000;

  static bool _enabled = true;
  static bool _initialized = false;
  static File? _file;
  static Future<void> _pending = Future<void>.value();

  static bool get enabled => _enabled;
  static String? get filePath => _file?.path;
  static File? get file => _file;

  static Future<String?> initialize({bool enabled = true}) async {
    _enabled = enabled;
    if (_initialized && _file != null) return _file!.path;
    final directory = _resolveDirectory();
    if (directory == null) {
      _initialized = false;
      _file = null;
      return null;
    }
    _initialized = true;
    try {
      await directory.create(recursive: true);
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');
      try {
        if (await file.exists() && await file.length() > maxFileBytes) {
          final previous = File('${file.path}.1');
          if (await previous.exists()) await previous.delete();
          await file.rename(previous.path);
          await sanitizeLogFileSecrets(previous);
        }
      } on FileSystemException {
        // 旧日志窗口或杀毒软件可能暂时占用文件；继续追加而不是关闭日志。
      }
      await sanitizeLogFileSecrets(file);
      _file = file;
      if (_enabled) info('App', '调试日志已初始化：${file.path}');
      return file.path;
    } catch (_) {
      _initialized = false;
      _file = null;
      return null;
    }
  }

  static Directory? _resolveDirectory() {
    final logsDirectory = PathManager.instance.logsDirectory;
    return logsDirectory == null ? null : Directory(logsDirectory);
  }

  static Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await initialize(enabled: true);
      info('Debug', '调试日志记录已开启');
      return;
    }
    info('Debug', '调试日志记录已关闭');
    _enabled = false;
    await flush();
  }

  static void info(String category, String message) {
    _write('INFO', category, message);
  }

  static void warning(String category, String message) {
    _write('WARN', category, message);
  }

  static void error(String category, String message, [StackTrace? stackTrace]) {
    _write('ERROR', category, message);
    if (stackTrace != null) {
      _write('ERROR', category, stackTrace.toString());
    }
  }

  static void _write(String level, String category, String message) {
    if (!_enabled) return;
    final file = _file;
    if (file == null) return;
    final timestamp = _timestamp(DateTime.now());
    final safeMessage = redactLogSecrets(message);
    final lines = safeMessage.length > maxMessageChars
        ? '${safeMessage.substring(0, maxMessageChars)}…（已截断）'
        : safeMessage;
    final buffer = StringBuffer();
    for (final rawLine in lines.split('\n')) {
      final line = rawLine.replaceAll('\r', '');
      if (line.isEmpty) continue;
      buffer.writeln('[$timestamp] [$level] [$category] $line');
    }
    if (buffer.isEmpty) return;
    final bytes = utf8.encode(buffer.toString());
    _pending = _pending.then((_) async {
      try {
        await file.writeAsBytes(bytes, mode: FileMode.append);
      } catch (_) {
        // Logging must never break the launcher.
      }
    });
  }

  static Future<void> flush() => _pending;

  static String _timestamp(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }
}

/// Standalone window shown by a second launcher process. It only reads the log
/// file and never initializes the launcher, so it cannot affect a running game.
class DebugLogWindowApp extends StatelessWidget {
  const DebugLogWindowApp({super.key, required this.logPath});

  final String logPath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baogan Craft Launcher - 调试日志',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: _debugFontFamily,
        scaffoldBackgroundColor: const Color(0xFFF1F4ED),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7BC043),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: _debugFontFamily,
        scaffoldBackgroundColor: const Color(0xFF101510),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7BC043),
          brightness: Brightness.dark,
        ),
      ),
      home: DebugLogWindowPage(logPath: logPath),
    );
  }
}

class DebugLogWindowPage extends StatefulWidget {
  const DebugLogWindowPage({super.key, required this.logPath});

  final String logPath;

  @override
  State<DebugLogWindowPage> createState() => _DebugLogWindowPageState();
}

class _DebugLogWindowPageState extends State<DebugLogWindowPage> {
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;
  String _content = '';
  String? _error;
  bool _loading = true;
  bool _reading = false;
  bool _paused = false;
  bool _followTail = true;
  int _lastLength = -1;
  DateTime? _lastModified;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    unawaited(_refresh(force: true));
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!_paused) unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atBottom = position.maxScrollExtent - position.pixels < 48;
    if (atBottom != _followTail) {
      setState(() => _followTail = atBottom);
    }
  }

  Future<void> _refresh({bool force = false}) async {
    if (_reading) return;
    _reading = true;
    try {
      final file = File(widget.logPath);
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = null;
            _content = '日志文件尚未创建，等待启动器写入…';
          });
        }
        return;
      }
      final length = await file.length();
      final modified = await file.lastModified();
      if (!force && length == _lastLength && modified == _lastModified) {
        return;
      }
      final tail = await readLogTail(widget.logPath);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _content = tail.content.isEmpty ? '（日志为空）' : tail.content;
        _lastLength = length;
        _lastModified = modified;
      });
      if (_followTail) _scrollToBottom();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '读取日志失败：$error';
        });
      }
    } finally {
      _reading = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _content));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制当前显示的日志。')));
    }
  }

  Future<void> _openFolder() async {
    try {
      final directory = File(widget.logPath).parent;
      await directory.create(recursive: true);
      await openLocalDirectory(directory.path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('无法打开日志文件夹：$error')));
      }
    }
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (!_paused) unawaited(_refresh(force: true));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panel = dark ? const Color(0xFF1B211B) : const Color(0xFFF8FAF6);
    final border = dark ? const Color(0xFF2A3228) : const Color(0xFFD8E0D2);
    final muted = dark ? const Color(0xFF9AA397) : const Color(0xFF52614F);
    final foreground = dark ? const Color(0xFFDDE5D8) : const Color(0xFF26351F);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8BC34A).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.terminal_rounded,
                      color: Color(0xFF8BC34A),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '调试日志',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.logPath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _statusChip(dark: dark, paused: _paused, loading: _loading),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _togglePause,
                    icon: Icon(
                      _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 17,
                    ),
                    label: Text(_paused ? '继续刷新' : '暂停刷新'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _refresh(force: true),
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('刷新'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _copyAll,
                    icon: const Icon(Icons.copy_all_outlined, size: 17),
                    label: const Text('复制全部'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openFolder,
                    icon: const Icon(Icons.folder_open_outlined, size: 17),
                    label: const Text('打开日志文件夹'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: SelectableText(
                        _error ?? (_content.isEmpty ? '正在读取日志…' : _content),
                        style: TextStyle(
                          fontFamily: _debugFontFamily,
                          fontSize: 11.5,
                          height: 1.38,
                          color: foreground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    _followTail
                        ? Icons.vertical_align_bottom_rounded
                        : Icons.pause_circle_outline_rounded,
                    size: 15,
                    color: muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error ??
                          (_paused
                              ? '已暂停自动刷新；日志仍在后台记录。'
                              : _followTail
                              ? '自动刷新并跟随日志末尾。'
                              : '已向上滚动，自动跟随已暂停。'),
                      style: TextStyle(fontSize: 10.5, color: muted),
                    ),
                  ),
                  if (!_followTail)
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _followTail = true);
                        _scrollToBottom();
                      },
                      icon: const Icon(
                        Icons.vertical_align_bottom_rounded,
                        size: 15,
                      ),
                      label: const Text('回到底部'),
                    ),
                  Text(
                    formatByteSize(utf8.encode(_content).length),
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip({
    required bool dark,
    required bool paused,
    required bool loading,
  }) {
    final color = loading
        ? const Color(0xFFE0B779)
        : paused
        ? const Color(0xFFE58A7A)
        : const Color(0xFF8BC34A);
    final label = loading
        ? '读取中'
        : paused
        ? '已暂停'
        : '实时';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
