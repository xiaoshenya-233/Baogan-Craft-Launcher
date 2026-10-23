// Java discovery, cache management and runtime selection.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'java_runtime.dart';

export 'java_runtime.dart';

class JavaRuntimeService {
  const JavaRuntimeService({this.minecraftPath = '', this.cacheFile});

  final String minecraftPath;
  final File? cacheFile;

  Future<List<JavaRuntime>> loadCache({
    Iterable<JavaRuntime> known = const [],
  }) async {
    final file = cacheFile;
    if (file == null || !await file.exists()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      final rows = decoded is Map<String, dynamic> ? decoded['runtimes'] : null;
      if (rows is! List) return const [];
      final loaded = <JavaRuntime>[];
      for (final row in rows) {
        final runtime = JavaRuntime.fromJson(row);
        if (runtime == null) continue;
        if (!await File(runtime.executable).exists()) continue;
        loaded.add(runtime);
      }
      if (loaded.isEmpty) return const [];
      final merged = <String, JavaRuntime>{};
      for (final runtime in loaded) {
        merged[normalizeJavaPath(runtime.executable)] = runtime;
      }
      for (final runtime in known) {
        merged[normalizeJavaPath(runtime.executable)] = runtime;
      }
      return sort(merged.values);
    } on FormatException {
      return const [];
    } on FileSystemException {
      return const [];
    }
  }

  Future<void> saveCache(Iterable<JavaRuntime> runtimes) async {
    final file = cacheFile;
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'version': 1,
          'updatedAt': DateTime.now().toIso8601String(),
          'runtimes': runtimes.map((runtime) => runtime.toJson()).toList(),
        }),
        flush: true,
      );
    } on FileSystemException {
      // 缓存写入失败不影响 Java 搜索与启动。
    }
  }

  Future<List<JavaRuntime>> discover({
    Iterable<JavaRuntime> known = const [],
    String customPath = '',
    String? selectedExecutable,
  }) async {
    final cached = <String, JavaRuntime>{};
    for (final runtime in known) {
      if (await File(runtime.executable).exists()) {
        cached[normalizeJavaPath(runtime.executable)] = runtime;
      }
    }

    final candidates = <String, String>{};
    addJavaCandidate(candidates, customPath, '自定义');
    addJavaCandidate(candidates, selectedExecutable, '已选择');
    for (final key in const ['JAVA_HOME', 'JDK_HOME', 'JRE_HOME']) {
      addJavaCandidate(candidates, Platform.environment[key], key);
    }
    final pathValue =
        Platform.environment['PATH'] ?? Platform.environment['Path'];
    if (pathValue != null) {
      for (final entry in pathValue.split(Platform.isWindows ? ';' : ':')) {
        addJavaCandidate(candidates, entry, 'PATH');
      }
    }
    await _collectWhereCandidates(candidates);
    if (Platform.isWindows) {
      await _collectWindowsRegistryCandidates(candidates);
    }

    for (final root in _commonRoots()) {
      await _collectCandidatesFromDirectory(
        candidates,
        Directory(root),
        '常见安装目录',
        0,
        4,
      );
    }
    for (final root in _launcherRoots()) {
      await _collectCandidatesFromDirectory(
        candidates,
        Directory(root),
        '启动器运行时',
        0,
        5,
      );
    }

    final runtimes = <String, JavaRuntime>{...cached};
    final seenCandidates = <String>{};
    final pending = candidates.entries.where((entry) {
      final key = normalizeJavaPath(entry.key);
      return !cached.containsKey(key) && seenCandidates.add(key);
    }).toList();
    const probeConcurrency = 8;
    for (var start = 0; start < pending.length; start += probeConcurrency) {
      final batch = pending.skip(start).take(probeConcurrency);
      final probed = await Future.wait(
        batch.map((entry) async {
          try {
            return await probeJavaExecutable(entry.key, source: entry.value);
          } on Exception {
            return null;
          }
        }),
      );
      for (final runtime in probed.whereType<JavaRuntime>()) {
        runtimes[normalizeJavaPath(runtime.executable)] = runtime;
      }
    }

    return sort(runtimes.values);
  }

  /// Resolves the Java executable for a Minecraft version.
  ///
  /// [discover] and [resolveRuntimePath] are supplied by the page so this
  /// service can stay independent from widget state and preference storage.
  Future<String> resolveExecutable({
    required int? requiredMajor,
    required String customPath,
    required String? selectedExecutable,
    required List<JavaRuntime> runtimes,
    required bool hasSearched,
    required JavaRuntimeDiscoverer discover,
    required JavaRuntimePathResolver resolveRuntimePath,
  }) async {
    final custom = customPath.trim();
    if (custom.isNotEmpty) {
      final customRuntime = await resolveRuntimePath(custom, '自定义');
      if (customRuntime == null) {
        throw const FormatException(
          '自定义 Java 无法运行或无法识别其版本。请在设置 → Java 管理中选择其他 Java。',
        );
      }
      return customRuntime.executable;
    }

    if (selectedExecutable != null && selectedExecutable.trim().isNotEmpty) {
      final selectedRuntime = await resolveRuntimePath(
        selectedExecutable,
        '已选择',
      );
      if (selectedRuntime == null) {
        throw const FormatException('所选 Java 已不存在，请重新选择 Java 位置。');
      }
      return selectedRuntime.executable;
    }

    if (runtimes.isNotEmpty) {
      if (requiredMajor != null) {
        final exact = runtimes
            .where((runtime) => runtime.majorVersion == requiredMajor)
            .firstOrNull;
        if (exact != null) return exact.executable;
      }
      final known = runtimes
          .where((runtime) => runtime.majorVersion != 0)
          .toList();
      final candidates = known.isNotEmpty ? known : runtimes;
      return candidates.first.executable;
    }

    if (!hasSearched) {
      final discovered = await discover();
      if (discovered.isNotEmpty) {
        return resolveExecutable(
          requiredMajor: requiredMajor,
          customPath: customPath,
          selectedExecutable: selectedExecutable,
          runtimes: discovered,
          hasSearched: true,
          discover: discover,
          resolveRuntimePath: resolveRuntimePath,
        );
      }
    }

    final majorHint = requiredMajor != null
        ? '建议安装 Java $requiredMajor 或更高版本，并在设置中将 Java 加入列表。'
        : '请安装 Java 并将其加入 PATH 或设置 JAVA_HOME。';
    throw FormatException('未找到可用的 Java 运行时。$majorHint');
  }


  Future<JavaRuntime?> runtimeForPath(
    String path, {
    Iterable<JavaRuntime> known = const [],
    String source = '',
  }) => javaRuntimeForPath(path, known: known, source: source);

  JavaRuntime? runtimeForExecutable(
    String executable,
    Iterable<JavaRuntime> runtimes,
  ) => javaRuntimeForExecutable(executable, runtimes);

  List<JavaRuntime> sort(Iterable<JavaRuntime> runtimes) =>
      sortJavaRuntimes(runtimes);

  String normalizePath(String path) => normalizeJavaPath(path);

  Future<JavaRuntime?> probeExecutable(
    String candidate, {
    String source = '',
  }) => probeJavaExecutable(candidate, source: source);

  Future<String> versionProbeExecutable(String executable) =>
      versionProbeJavaExecutable(executable);

  List<String> _commonRoots() {
    final environment = Platform.environment;
    final separator = Platform.pathSeparator;
    if (Platform.isWindows) {
      final programFiles = environment['ProgramFiles'] ?? r'C:\Program Files';
      final programFilesX86 = environment['ProgramFiles(x86)'];
      final localAppData = environment['LOCALAPPDATA'];
      final userProfile = environment['USERPROFILE'];
      final roots = <String>[];
      const vendors = <String>[
        'Java',
        'Eclipse Adoptium',
        'Eclipse Foundation',
        'Zulu',
        'Azul Systems',
        'BellSoft',
        'Amazon Corretto',
        'Microsoft',
        'RedHat',
        'Semeru',
        'SapMachine',
        'GraalVM',
      ];
      for (final vendor in vendors) {
        roots.add('$programFiles$separator$vendor');
        if (programFilesX86 != null) {
          roots.add('$programFilesX86$separator$vendor');
        }
        if (localAppData != null) {
          roots.add('$localAppData${separator}Programs$separator$vendor');
        }
      }
      roots.add(r'C:\Java');
      if (userProfile != null) {
        roots.add('$userProfile$separator.jdks');
        for (final app in const [
          'openjdk',
          'temurin',
          'zulu',
          'corretto',
          'graalvm',
          'liberica',
          'sapmachine',
        ]) {
          roots.add(
            '$userProfile${separator}scoop${separator}apps$separator$app',
          );
        }
      }
      return roots;
    }
    final home = environment['HOME'] ?? '';
    if (Platform.isMacOS) {
      return <String>[
        '/Library/Java/JavaVirtualMachines',
        '/System/Library/Java/JavaVirtualMachines',
        if (home.isNotEmpty) '$home/Library/Java/JavaVirtualMachines',
        '/opt/homebrew/opt',
        '/usr/local/opt',
      ];
    }
    return <String>[
      '/usr/lib/jvm',
      '/usr/java',
      '/opt',
      if (home.isNotEmpty) '$home/.jdks',
      if (home.isNotEmpty) '$home/.sdkman/candidates/java',
    ];
  }

  List<String> _launcherRoots() {
    final environment = Platform.environment;
    final separator = Platform.pathSeparator;
    final roots = <String>[];
    final preferences = cacheFile;
    if (preferences != null) {
      roots.add('${preferences.parent.path}${separator}runtime');
      roots.add('${preferences.parent.path}${separator}java');
    }
    if (minecraftPath.isNotEmpty) {
      roots.add('$minecraftPath${separator}runtime');
    }
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    roots.add('${executableDirectory.path}${separator}runtime');
    roots.add('${executableDirectory.path}${separator}jre');
    if (Platform.isWindows) {
      final appData = environment['APPDATA'];
      final userProfile = environment['USERPROFILE'];
      if (appData != null) {
        roots.addAll(<String>[
          '$appData$separator.minecraft${separator}runtime',
          '$appData${separator}PrismLauncher${separator}java',
          '$appData${separator}MultiMC${separator}java',
          '$appData${separator}HMCL${separator}java',
          '$appData${separator}PCL${separator}runtime',
        ]);
      }
      if (userProfile != null) {
        roots.addAll(<String>[
          '$userProfile$separator.hmcl${separator}java',
          '$userProfile$separator.xmcl${separator}runtime${separator}java',
          '$userProfile$separator.sjmcl${separator}runtime',
        ]);
      }
    } else {
      final home = environment['HOME'] ?? '';
      if (home.isNotEmpty) {
        roots.addAll(<String>[
          '$home/.local/share/PrismLauncher/java',
          '$home/.local/share/multimc/java',
          '$home/.hmcl/java',
          '$home/.xmcl/runtime/java',
          '$home/.sjmcl/runtime',
        ]);
      }
    }
    return roots;
  }

  Future<void> _collectWhereCandidates(Map<String, String> candidates) async {
    for (final command in Platform.isWindows ? ['java', 'javaw'] : ['java']) {
      try {
        final result = await Process.run(
          Platform.isWindows ? 'where.exe' : 'which',
          [command],
          runInShell: false,
          stdoutEncoding: systemEncoding,
          stderrEncoding: systemEncoding,
        );
        if (result.exitCode != 0) continue;
        final output = decodeJavaProcessResult(result.stdout);
        for (final line in output.split(RegExp(r'\r?\n'))) {
          addJavaCandidate(candidates, line, 'PATH');
        }
      } on ProcessException {
        // Ignore missing where/which.
      } on FormatException {
        // Ignore output that cannot be decoded.
      }
    }
  }

  Future<void> _collectWindowsRegistryCandidates(
    Map<String, String> candidates,
  ) async {
    const roots = <String>[
      r'HKLM\SOFTWARE\JavaSoft',
      r'HKLM\SOFTWARE\WOW6432Node\JavaSoft',
      r'HKLM\SOFTWARE\Eclipse Adoptium\JDK',
      r'HKLM\SOFTWARE\WOW6432Node\Eclipse Adoptium\JDK',
      r'HKLM\SOFTWARE\Eclipse Foundation\JDK',
      r'HKLM\SOFTWARE\WOW6432Node\Eclipse Foundation\JDK',
      r'HKLM\SOFTWARE\Microsoft\JDK',
      r'HKLM\SOFTWARE\WOW6432Node\Microsoft\JDK',
      r'HKLM\SOFTWARE\Azul Systems\Zulu',
      r'HKLM\SOFTWARE\WOW6432Node\Azul Systems\Zulu',
      r'HKLM\SOFTWARE\BellSoft\LibericaJDK',
      r'HKLM\SOFTWARE\WOW6432Node\BellSoft\LibericaJDK',
      r'HKLM\SOFTWARE\Semeru\JDK',
      r'HKLM\SOFTWARE\WOW6432Node\Semeru\JDK',
      r'HKLM\SOFTWARE\SapMachine\JDK',
      r'HKLM\SOFTWARE\WOW6432Node\SapMachine\JDK',
    ];
    for (final root in roots) {
      try {
        final result = await Process.run(
          'reg.exe',
          ['query', root, '/s'],
          runInShell: false,
          stdoutEncoding: systemEncoding,
          stderrEncoding: systemEncoding,
        );
        if (result.exitCode != 0) continue;
        final output = decodeJavaProcessResult(result.stdout);
        for (final match in RegExp(
          r'(?:JavaHome|Path)\s+REG_SZ\s+(.+)',
          caseSensitive: false,
        ).allMatches(output)) {
          addJavaCandidate(candidates, match.group(1), '注册表');
        }
      } on ProcessException {
        // Missing registry entries are expected on systems without a JDK.
      } on FormatException {
        // Ignore output that cannot be decoded.
      }
    }
  }

  Future<void> _collectCandidatesFromDirectory(
    Map<String, String> candidates,
    Directory directory,
    String source,
    int depth,
    int maxDepth,
  ) async {
    if (depth > maxDepth) return;
    if (!await directory.exists()) return;
    try {
      await for (final entity in directory.list(followLinks: false)) {
        final segments = entity.uri.pathSegments;
        final name = segments.isEmpty ? '' : segments.last.toLowerCase();
        if (entity is File) {
          if (const {'java.exe', 'javaw.exe', 'java'}.contains(name)) {
            addJavaCandidate(candidates, entity.path, source);
          }
          continue;
        }
        if (entity is! Directory) continue;
        if (_javaSearchSkippedDirectories.contains(name)) continue;
        final executables = Platform.isWindows
            ? const ['java.exe', 'javaw.exe']
            : const ['java'];
        for (final executable in executables) {
          final candidate = File(
            '${entity.path}${Platform.pathSeparator}bin'
            '${Platform.pathSeparator}$executable',
          );
          if (await candidate.exists()) {
            addJavaCandidate(candidates, candidate.path, source);
          }
        }
        await _collectCandidatesFromDirectory(
          candidates,
          entity,
          source,
          depth + 1,
          maxDepth,
        );
      }
    } on FileSystemException {
      // Skip directories that cannot be accessed.
    }
  }
}

/// Directories skipped by the bounded Java directory scan.
const Set<String> _javaSearchSkippedDirectories = <String>{
  r'$recycle.bin',
  'system volume information',
  'windows',
  'perflogs',
  'node_modules',
  '.git',
  '.svn',
  'config.msi',
  'msocache',
  'temp',
  'tmp',
  'cache',
  'logs',
  'crash-reports',
  'mods',
  'saves',
  'resourcepacks',
  'shaderpacks',
  'assets',
  'libraries',
  'versions',
};
