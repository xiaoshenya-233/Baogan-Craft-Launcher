import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../core/launcher_log.dart';
import '../../core/path_utils.dart';
import '../installer/version_models.dart';
import '../java/java_service.dart';
import '../network/auth_service.dart';

const List<String> _launchVersionFolders = <String>[
  'mods',
  'shaderpacks',
  'resourcepacks',
  'config',
  'saves',
];

String _launchLastPathSegment(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.split('/').where((part) => part.isNotEmpty).last;
}

class MinecraftLaunchService {
  static Future<Map<String, dynamic>> readConfig(
    MinecraftVersion version,
    String minecraftPath,
  ) {
    final configFile = File(
      joinPath(
        version.directoryPath,
        '${_folderName(version.directoryPath)}.json',
      ),
    );
    return _loadVersionConfig(
      configFile,
      Directory(joinPath(minecraftPath, 'versions')),
      {},
    );
  }

  static Future<LaunchPlan> buildArguments({
    required MinecraftVersion version,
    required String minecraftPath,
    required AuthIdentity identity,
    required String javaExecutable,
    required int memoryGb,
    String? javaAgent,
    String? serverAddress,
    int? serverPort,
  }) async {
    final config = await readConfig(version, minecraftPath);
    final gameDirectory = Directory(version.directoryPath);
    await _ensureVersionFolders(gameDirectory);
    final mainClass = config['mainClass'];
    if (mainClass is! String || mainClass.isEmpty) {
      throw const FormatException('版本配置缺少 mainClass，无法启动。');
    }

    final librariesDirectory = Directory(joinPath(minecraftPath, 'libraries'));
    final classPath = <String>[];
    final nativeArchives = <File>[];
    final libraries = config['libraries'];
    if (libraries is List) {
      for (final rawLibrary in libraries) {
        if (rawLibrary is! Map<String, dynamic> ||
            !_matchesRules(rawLibrary['rules'])) {
          continue;
        }
        final artifactPath = _libraryArtifactPath(rawLibrary);
        if (artifactPath != null) {
          final artifact = File(
            joinPath(librariesDirectory.path, artifactPath),
          );
          if (!await artifact.exists()) {
            throw FileSystemException(
              '缺少游戏依赖 ${rawLibrary['name'] ?? artifactPath}，请先安装或修复此版本。',
              artifact.path,
            );
          }
          classPath.add(artifact.path);
        }
        final classifier = _nativeClassifier(rawLibrary);
        if (classifier != null) {
          final classifiers =
              (rawLibrary['downloads']
                  as Map<String, dynamic>?)?['classifiers'];
          final nativeInfo = classifiers is Map<String, dynamic>
              ? classifiers[classifier]
              : null;
          final nativePath = nativeInfo is Map<String, dynamic>
              ? nativeInfo['path']
              : null;
          if (nativePath is String) {
            final nativeArchive = File(
              joinPath(librariesDirectory.path, nativePath),
            );
            if (!await nativeArchive.exists()) {
              throw FileSystemException(
                '缺少游戏原生依赖，请先安装或修复此版本。',
                nativeArchive.path,
              );
            }
            nativeArchives.add(nativeArchive);
          }
        }
      }
    }

    final clientJarCandidates = minecraftClientJarCandidates(
      versionDirectory: version.directoryPath,
      minecraftPath: minecraftPath,
      versionId: version.id,
      config: config,
    ).map(File.new).toList();
    File? clientJar;
    for (final candidate in clientJarCandidates) {
      if (await candidate.exists()) {
        clientJar = candidate;
        break;
      }
    }
    if (clientJar == null) {
      throw FileSystemException(
        '找不到 Minecraft 客户端 JAR，请先安装或修复此版本。',
        clientJarCandidates.last.path,
      );
    }
    classPath.add(clientJar.path);
    final launchClassPath = deduplicateClassPathEntries(classPath);

    final nativesDirectory = await Directory.systemTemp.createTemp(
      'block-launcher-natives-',
    );
    var handedOffNatives = false;
    try {
      if (nativeArchives.isNotEmpty) {
        final jarExecutable = await _findJarExecutable(javaExecutable);
        for (final archive in nativeArchives) {
          final result = await Process.run(
            jarExecutable,
            ['xf', archive.path],
            workingDirectory: nativesDirectory.path,
            runInShell: false,
          );
          if (result.exitCode != 0) {
            throw ProcessException(
              jarExecutable,
              ['xf', archive.path],
              '无法解压 Minecraft 原生依赖：${result.stderr}',
              result.exitCode,
            );
          }
        }
      }

      final assetIndex = config['assets'] is String
          ? config['assets'] as String
          : (config['assetIndex'] as Map<String, dynamic>?)?['id'] is String
          ? (config['assetIndex'] as Map<String, dynamic>)['id'] as String
          : '';
      final classpathSeparator = Platform.isWindows ? ';' : ':';
      final clientJarName = _launchLastPathSegment(clientJar.path);
      final placeholders = <String, String>{
        'auth_player_name': identity.name,
        'version_name': (config['id'] as String?) ?? version.id,
        'game_directory': gameDirectory.path,
        'assets_root': joinPath(minecraftPath, 'assets'),
        'assets_index_name': assetIndex,
        'auth_uuid': identity.uuid.replaceAll('-', ''),
        'auth_access_token': identity.accessToken,
        'auth_session':
            'token:${identity.accessToken}:${identity.uuid.replaceAll('-', '')}',
        'user_type': identity.userType,
        'version_type': (config['type'] as String?) ?? 'release',
        'user_properties': '{}',
        'clientid': '',
        'auth_client_id': '',
        'auth_xuid': identity.xuid,
        'resolution_width': '854',
        'resolution_height': '480',
        'natives_directory': nativesDirectory.path,
        'library_directory': librariesDirectory.path,
        'classpath_separator': classpathSeparator,
        'classpath': launchClassPath.join(classpathSeparator),
        'launcher_name': 'BLOCK_LAUNCHER',
        'launcher_version': '26.1alpha2',
      };

      final jvmArguments = _argumentList(
        (config['arguments'] as Map<String, dynamic>?)?['jvm'],
      );
      final gameArguments = _argumentList(
        (config['arguments'] as Map<String, dynamic>?)?['game'],
      );
      if (gameArguments.isEmpty && config['minecraftArguments'] is String) {
        gameArguments.addAll(
          _splitLegacyArguments(config['minecraftArguments'] as String),
        );
      }
      final args = <String>[
        '-Xmx${math.max(1, memoryGb)}G',
        '-Djava.library.path=${nativesDirectory.path}',
        '-Dminecraft.launcher.brand=BLOCK_LAUNCHER',
        '-Dminecraft.launcher.version=26.1alpha2',
        if (javaAgent != null) '-javaagent:$javaAgent',
        ...jvmArguments.map((value) {
          var replaced = _replacePlaceholders(value, placeholders);
          replaced = replaceIgnoreListClientJar(
            argument: replaced,
            versionName: placeholders['version_name']!,
            clientJarName: clientJarName,
          );
          return replaced;
        }),
        '-cp',
        launchClassPath.join(classpathSeparator),
        mainClass,
        ...gameArguments.map(
          (value) => _replacePlaceholders(value, placeholders),
        ),
      ];
      handedOffNatives = true;
      final targetServer = serverAddress?.trim() ?? '';
      if (targetServer.isNotEmpty) {
        // Vanilla client arguments: `--server <host> --port <port>`.
        args.addAll(<String>['--server', targetServer]);
        if (serverPort != null && serverPort > 0) {
          args.addAll(<String>['--port', '$serverPort']);
        }
      }
      return LaunchPlan(
        arguments: args,
        nativesDirectory: nativesDirectory,
        gameDirectory: gameDirectory,
      );
    } finally {
      if (!handedOffNatives && await nativesDirectory.exists()) {
        await nativesDirectory.delete(recursive: true);
      }
    }
  }

  /// Ensures the standard game folders exist inside a client's version
  /// directory (`.minecraft/versions/<客户端>`), so the launched client loads
  /// mods, shader packs and resource packs from its own isolated directory.
  static Future<void> _ensureVersionFolders(Directory gameDirectory) async {
    await gameDirectory.create(recursive: true);
    for (final folder in _launchVersionFolders) {
      await Directory(joinPath(gameDirectory.path, folder))
          .create(recursive: true);
    }
  }

  static Future<Map<String, dynamic>> _loadVersionConfig(
    File file,
    Directory versionsDirectory,
    Set<String> loading,
  ) async {
    final normalizedPath = file.absolute.path.toLowerCase();
    if (!loading.add(normalizedPath)) {
      throw FormatException('版本配置继承循环：${file.path}');
    }
    try {
      if (!await file.exists()) {
        throw FileSystemException('找不到版本配置文件。', file.path);
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('版本配置格式无效：${file.path}');
      }
      final merged = <String, dynamic>{};
      Map<String, dynamic>? parentConfig;
      final parentId = decoded['inheritsFrom'];
      if (parentId is String && parentId.isNotEmpty) {
        final parentFile = File(
          joinPath(
            joinPath(versionsDirectory.path, parentId),
            '$parentId.json',
          ),
        );
        parentConfig = await _loadVersionConfig(
          parentFile,
          versionsDirectory,
          loading,
        );
        merged.addAll(parentConfig);
      }
      merged.addAll(decoded);
      final parentLibraries = parentConfig?['libraries'];
      final childLibraries = decoded['libraries'];
      if (parentLibraries is List && childLibraries is List) {
        merged['libraries'] = [...parentLibraries, ...childLibraries];
      }
      final parentArguments = parentConfig?['arguments'];
      final childArguments = decoded['arguments'];
      if (parentArguments is Map<String, dynamic> &&
          childArguments is Map<String, dynamic>) {
        merged['arguments'] = {
          ...parentArguments,
          ...childArguments,
          for (final key in ['jvm', 'game'])
            if (parentArguments[key] is List && childArguments[key] is List)
              key: [
                ...(parentArguments[key] as List),
                ...(childArguments[key] as List),
              ],
        };
      }
      return merged;
    } finally {
      loading.remove(normalizedPath);
    }
  }

  static String? _libraryArtifactPath(Map<String, dynamic> library) {
    final downloads = library['downloads'];
    final artifact = downloads is Map<String, dynamic>
        ? downloads['artifact']
        : null;
    if (artifact is Map<String, dynamic> && artifact['path'] is String) {
      return artifact['path'] as String;
    }
    final name = library['name'];
    if (name is! String) return null;
    final notation = name.split('@');
    final coordinates = notation.first.split(':');
    if (coordinates.length < 3) return null;
    final group = coordinates[0].replaceAll('.', '/');
    final artifactId = coordinates[1];
    final version = coordinates[2];
    final classifier = coordinates.length > 3 ? '-${coordinates[3]}' : '';
    final extension = notation.length > 1 ? notation.last : 'jar';
    return '$group/$artifactId/$version/$artifactId-$version$classifier.$extension';
  }

  static String? _nativeClassifier(Map<String, dynamic> library) {
    final natives = library['natives'];
    if (natives is! Map<String, dynamic>) return null;
    final nativePattern =
        natives[Platform.isWindows
            ? 'windows'
            : Platform.isMacOS
            ? 'osx'
            : 'linux'];
    if (nativePattern is! String) return null;
    final architecture =
        Platform.environment['PROCESSOR_ARCHITECTURE']?.toLowerCase() ?? '';
    return nativePattern.replaceAll(
      r'${arch}',
      architecture.contains('86') && !architecture.contains('64') ? '32' : '64',
    );
  }

  static bool _matchesRules(dynamic rules) {
    if (rules is! List) return true;
    var allowed = false;
    final osName = Platform.isWindows
        ? 'windows'
        : Platform.isMacOS
        ? 'osx'
        : 'linux';
    for (final rawRule in rules) {
      if (rawRule is! Map<String, dynamic>) continue;
      final os = rawRule['os'];
      final ruleOs = os is Map<String, dynamic> ? os['name'] : null;
      if (ruleOs != null && ruleOs != osName) continue;
      final osArch = os is Map<String, dynamic> ? os['arch'] : null;
      final currentArch =
          Platform.environment['PROCESSOR_ARCHITECTURE']?.toLowerCase() ?? '';
      if (osArch is String && !currentArch.contains(osArch.toLowerCase())) {
        continue;
      }
      final osVersion = os is Map<String, dynamic> ? os['version'] : null;
      if (osVersion is String &&
          !RegExp(osVersion).hasMatch(Platform.operatingSystemVersion)) {
        continue;
      }
      final requiredFeatures = rawRule['features'];
      if (requiredFeatures is Map<String, dynamic> &&
          requiredFeatures.values.any((value) => value != false)) {
        continue;
      }
      final action = rawRule['action'];
      if (action == 'allow') allowed = true;
      if (action == 'disallow') allowed = false;
    }
    return allowed;
  }

  static List<String> _argumentList(dynamic rawArguments) {
    if (rawArguments is! List) return [];
    final result = <String>[];
    for (final argument in rawArguments) {
      if (argument is String) {
        result.add(argument);
        continue;
      }
      if (argument is! Map<String, dynamic> ||
          !_matchesRules(argument['rules'])) {
        continue;
      }
      final value = argument['value'];
      if (value is String) result.add(value);
      if (value is List) result.addAll(value.whereType<String>());
    }
    return result;
  }

  static List<String> _splitLegacyArguments(String arguments) {
    return RegExp(r'"((?:\\.|[^"])*)"|(\S+)')
        .allMatches(arguments)
        .map(
          (match) =>
              (match.group(1) ?? match.group(2) ?? '').replaceAll(r'\"', '"'),
        )
        .where((argument) => argument.isNotEmpty)
        .toList();
  }

  static String _replacePlaceholders(
    String argument,
    Map<String, String> placeholders,
  ) {
    var result = argument;
    for (final entry in placeholders.entries) {
      result = result.replaceAll('\${${entry.key}}', entry.value);
    }
    return result;
  }

  static Future<String> _findJarExecutable(String javaExecutable) async {
    final javaDirectory = File(javaExecutable).parent;
    final siblingJar = File(
      joinPath(javaDirectory.path, Platform.isWindows ? 'jar.exe' : 'jar'),
    );
    if (await siblingJar.exists()) return siblingJar.path;
    throw const FormatException('需要解压游戏原生库，但当前 Java 运行时未包含 jar 工具；请安装完整 JDK。');
  }

  static String _folderName(String path) => _launchLastPathSegment(path);
}

String? resolveActiveMinecraftSource(
  String minecraftPath,
  List<String> sources,
) {
  final current = minecraftPath.trim();
  if (current.isNotEmpty) return current;
  for (final source in sources) {
    final candidate = source.trim();
    if (candidate.isNotEmpty) return candidate;
  }
  return null;
}

Future<List<MinecraftVersion>> loadActiveMinecraftVersions({
  required String minecraftPath,
  required List<String> sources,
}) async {
  final active = resolveActiveMinecraftSource(minecraftPath, sources);
  if (active == null) return [];
  return getLocalVersions(active);
}

Future<List<MinecraftVersion>> getLocalVersions(String minecraftPath) async {
  final versionsDirectory = Directory(
    '$minecraftPath${Platform.pathSeparator}versions',
  );
  if (!await versionsDirectory.exists()) return [];

  final versions = <MinecraftVersion>[];
  await for (final entry in versionsDirectory.list(followLinks: false)) {
    if (entry is! Directory) continue;
    final normalizedPath = entry.path.replaceAll('\\', '/');
    final folderName = normalizedPath
        .split('/')
        .where((part) => part.isNotEmpty)
        .last;
    final jsonFile = File(
      '${entry.path}${Platform.pathSeparator}$folderName.json',
    );
    if (!await jsonFile.exists()) continue;

    try {
      final decoded = jsonDecode(await jsonFile.readAsString());
      if (decoded is! Map<String, dynamic>) continue;
      final id = decoded['id'];
      final type = decoded['type'];
      if (id is! String || id.isEmpty) continue;
      final chainIds = await versionInheritanceIds(jsonFile, versionsDirectory);
      Map<String, dynamic> resolvedConfig = decoded;
      try {
        resolvedConfig = await MinecraftLaunchService._loadVersionConfig(
          jsonFile,
          versionsDirectory,
          <String>{},
        );
      } on FileSystemException {
        // A missing parent should not hide the child from the version list.
      } on FormatException {
        // Invalid parent JSON: still expose metadata from the child itself.
      }
      final identity = inferVersionIdentity(
        configId: id,
        config: resolvedConfig,
        chainIds: chainIds,
      );
      versions.add(
        MinecraftVersion(
          id: id,
          type: type is String ? type : null,
          directoryPath: entry.path,
          minecraftPath: minecraftPath,
          minecraftVersion: identity.minecraftVersion,
          loaderType: identity.loaderType,
          loaderVersion: identity.loaderVersion,
        ),
      );
    } on FormatException {
      continue;
    }
  }
  versions.sort((a, b) => a.id.toLowerCase().compareTo(b.id.toLowerCase()));
  return versions;
}

/// Prepared Minecraft launch arguments and the directories they use.
class LaunchPlan {
  const LaunchPlan({
    required this.arguments,
    required this.nativesDirectory,
    required this.gameDirectory,
  });

  final List<String> arguments;
  final Directory nativesDirectory;
  final Directory gameDirectory;
}

/// Result of a Minecraft process after all output streams have closed.
class MinecraftLaunchResult {
  const MinecraftLaunchResult({
    required this.exitCode,
    required this.output,
    required this.elapsed,
    this.cleanupError,
  });

  final int exitCode;
  final String output;
  final Duration elapsed;
  final String? cleanupError;
}

/// Starts Minecraft and owns its output streams, exit watcher and natives
/// cleanup. The page only observes [MinecraftLaunchSession.waitForExit].
class MinecraftLaunchRunner {
  const MinecraftLaunchRunner();

  static const int _maxCapturedOutput = 24000;

  Future<MinecraftLaunchSession> launch({
    required String javaExecutable,
    required LaunchPlan plan,
  }) async {
    final process = await Process.start(
      javaExecutable,
      plan.arguments,
      workingDirectory: plan.gameDirectory.path,
    );
    LauncherLog.info('Launch', '游戏进程已启动，PID=${process.pid}');
    return MinecraftLaunchSession._(process: process, plan: plan);
  }

  Future<String?> cleanupNatives(Directory directory) async {
    if (!await directory.exists()) return null;
    try {
      await directory.delete(recursive: true);
      return null;
    } on FileSystemException catch (error) {
      final message = '清理临时游戏文件失败：${error.message}';
      LauncherLog.warning('Launch', message);
      return message;
    }
  }
}

class MinecraftLaunchSession {
  MinecraftLaunchSession._({required this.process, required this.plan})
    : startedAt = DateTime.now() {
    _stdoutDone = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(_captureOutput)
        .asFuture<void>();
    _stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(_captureOutput)
        .asFuture<void>();
    _completion = _watchExit();
  }

  final Process process;
  final LaunchPlan plan;
  final DateTime startedAt;
  final StringBuffer _output = StringBuffer();
  late final Future<void> _stdoutDone;
  late final Future<void> _stderrDone;
  late final Future<MinecraftLaunchResult> _completion;

  int get pid => process.pid;

  /// Terminates the running game process (used by the task capsule stop action).
  void terminate() {
    process.kill();
  }

  String get output => _output.toString();

  Future<MinecraftLaunchResult> waitForExit() => _completion;

  void _captureOutput(String text) {
    if (text.isEmpty) return;
    if (_output.length < MinecraftLaunchRunner._maxCapturedOutput) {
      _output.write(text);
    }
    LauncherLog.info('Minecraft', text.trimRight());
  }

  Future<MinecraftLaunchResult> _watchExit() async {
    final exitCode = await process.exitCode;
    try {
      await Future.wait<void>([_stdoutDone, _stderrDone]);
    } catch (_) {
      // 输出流异常不应阻止退出处理。
    }
    final cleanupError = await const MinecraftLaunchRunner().cleanupNatives(
      plan.nativesDirectory,
    );
    final elapsed = DateTime.now().difference(startedAt);
    LauncherLog.info('Launch', '游戏进程退出：代码 $exitCode，运行 ${elapsed.inSeconds} 秒');
    return MinecraftLaunchResult(
      exitCode: exitCode,
      output: output,
      elapsed: elapsed,
      cleanupError: cleanupError,
    );
  }
}

enum LaunchFailureKind { missingMods, incompatibleMods, javaVersion, unknown }

class LaunchFailureDiagnosis {
  const LaunchFailureDiagnosis({
    required this.kind,
    required this.snippet,
    this.missingDependencies = const [],
    this.compatibilityIssue,
    this.javaIssue = false,
  });

  final LaunchFailureKind kind;
  final String snippet;
  final List<String> missingDependencies;
  final String? compatibilityIssue;
  final bool javaIssue;
}

/// Classifies Minecraft crash output without depending on Flutter UI.
class MinecraftLaunchDiagnostics {
  const MinecraftLaunchDiagnostics();

  Future<LaunchFailureDiagnosis> diagnose({
    required String versionId,
    required int exitCode,
    required String output,
    required JavaRuntime? javaRuntime,
    required Future<int?> Function() loadRequiredJavaMajor,
  }) async {
    final trimmedOutput = output.trim();
    final snippet = trimmedOutput.length > 1600
        ? trimmedOutput.substring(0, 1600)
        : trimmedOutput;
    LauncherLog.error(
      'Launch',
      'Minecraft $versionId 启动失败，退出代码 $exitCode'
          '${snippet.isEmpty ? '' : '\n$snippet'}',
    );

    final missingDependencies = missingModDependencies(output);
    if (missingDependencies.isNotEmpty) {
      return LaunchFailureDiagnosis(
        kind: LaunchFailureKind.missingMods,
        snippet: snippet,
        missingDependencies: missingDependencies,
      );
    }
    final compatibilityIssue = modCompatibilityIssue(output);
    if (compatibilityIssue != null) {
      return LaunchFailureDiagnosis(
        kind: LaunchFailureKind.incompatibleMods,
        snippet: snippet,
        compatibilityIssue: compatibilityIssue,
      );
    }
    final javaIssue = await isLikelyJavaVersionFailure(
      output: output,
      javaRuntime: javaRuntime,
      loadRequiredJavaMajor: loadRequiredJavaMajor,
    );
    return LaunchFailureDiagnosis(
      kind: javaIssue
          ? LaunchFailureKind.javaVersion
          : LaunchFailureKind.unknown,
      snippet: snippet,
      javaIssue: javaIssue,
    );
  }

  Future<bool> isLikelyJavaVersionFailure({
    required String output,
    required JavaRuntime? javaRuntime,
    required Future<int?> Function() loadRequiredJavaMajor,
  }) async {
    final lower = output.toLowerCase();
    if (looksLikeJavaVersionFailure(output)) return true;
    if (javaRuntime == null || javaRuntime.majorVersion == 0) return false;
    try {
      final requiredMajor = await loadRequiredJavaMajor();
      if (requiredMajor != null && requiredMajor != javaRuntime.majorVersion) {
        return output.trim().isEmpty ||
            lower.contains('error') ||
            lower.contains('exception');
      }
    } on Exception {
      // 配置无法读取时只依赖启动输出判断。
    }
    return false;
  }
}

bool looksLikeJavaVersionFailure(String output) {
  final lower = output.toLowerCase();
  const markers = [
    'unsupportedclassversionerror',
    'unsupported major.minor version',
    'has been compiled by a more recent version',
    'class file version',
    'unrecognized vm option',
    'could not create the java virtual machine',
    'a jni error has occurred',
    'requires java',
  ];
  return markers.any(lower.contains);
}

List<String> missingModDependencies(String output) {
  final ids = <String>{};
  final pattern = RegExp(
    r"Mod ID:\s*'([^']+)'[^\r\n]*\[MISSING\]",
    caseSensitive: false,
  );
  for (final match in pattern.allMatches(output)) {
    final id = match.group(1)?.trim();
    if (id != null && id.isNotEmpty) ids.add(id);
  }
  return ids.toList();
}

/// Returns an actionable explanation for known mod-loader crashes.
///
/// Iris 1.8.x is built against Sodium 0.6.x. Sodium 0.8 removed
/// `SodiumGameOptions.PerformanceSettings`, so Iris' compatibility mixin fails
/// and Minecraft exits with code 1. This check turns that stack trace into a
/// concrete upgrade/downgrade instruction instead of a generic crash dialog.
String? modCompatibilityIssue(String output) {
  final lower = output.toLowerCase();
  final sodiumClassMissing =
      lower.contains('sodiumgameoptions\$performancesettings') &&
      lower.contains('classnotfoundexception');
  final irisMixinFailed =
      lower.contains('mixinrendersectionmanager') &&
      lower.contains('mixins.iris');
  if (sodiumClassMissing && (irisMixinFailed || lower.contains('iris'))) {
    return 'Iris 与 Sodium 版本不兼容。\n\n'
        '当前 Iris 1.8.x 依赖 Sodium 0.6.13，但 Sodium 0.8.x 已移除 '
        'SodiumGameOptions.PerformanceSettings，因此渲染初始化时崩溃。\n\n'
        '解决方法：将 Sodium 换成 0.6.13，或者把 Iris 升级到 1.8.14 及更高版本。'
        '请只保留一个 Sodium JAR。';
  }
  return null;
}
