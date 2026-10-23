// Java runtime model, version parsing and single-executable probing.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

int parseJavaMajorVersion(String output) {
  final match = RegExp(r'version "([0-9]+)(?:\.([0-9]+))?').firstMatch(output);
  if (match == null) return 0;
  final first = match.group(1);
  final second = match.group(2);
  if (first == null) return 0;
  return int.tryParse(first == '1' && second != null ? second : first) ?? 0;
}

/// Parses a bare version string such as the `JAVA_VERSION` field in a JDK
/// `release` file (`17.0.10`, `1.8.0_402`, `21`).
int parseJavaVersionNumber(String version) {
  final match = RegExp(r'^(\d+)(?:\.(\d+))?').firstMatch(version.trim());
  if (match == null) return 0;
  final first = int.tryParse(match.group(1) ?? '');
  final second = int.tryParse(match.group(2) ?? '');
  if (first == null) return 0;
  if (first == 1 && second != null) return second;
  return first;
}

/// Decodes output from external Java / Windows tools.
///
/// Windows Chinese consoles emit GBK (the active ANSI code page), so
/// [systemEncoding] is attempted first. UTF-8 and a byte-preserving fallback
/// keep the ASCII version fields parseable on other systems.
String decodeJavaProcessOutput(List<int> bytes) {
  try {
    return systemEncoding.decode(bytes);
  } on FormatException {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }
}

/// Parses vendor, bitness, full version and architecture from
/// `java -version` output.
({String? vendor, int bitness, String? fullVersion, String? arch})
parseJavaRuntimeDetails(String output) {
  final fullVersion = RegExp(r'version "([^"]+)"').firstMatch(output)?.group(1);
  final bitnessMatch = RegExp(r'(\d+)-Bit').firstMatch(output);
  final bitness = bitnessMatch == null
      ? 0
      : int.tryParse(bitnessMatch.group(1)!) ?? 0;
  String? vendor;
  final vendorMatch = RegExp(
    r'Runtime Environment[ \t]+(?:\([^)]*\)[ \t]+)?([A-Za-z][A-Za-z0-9]*)',
  ).firstMatch(output);
  if (vendorMatch != null) {
    vendor = vendorMatch.group(1)!.replaceFirst(RegExp(r'[\d.]+$'), '');
  } else if (output.contains('OpenJDK')) {
    vendor = 'OpenJDK';
  } else if (output.contains('HotSpot')) {
    vendor = 'Oracle';
  }
  final arch = bitness == 64
      ? 'x86_64'
      : bitness == 32
      ? 'x86'
      : null;
  return (
    vendor: vendor,
    bitness: bitness,
    fullVersion: fullVersion,
    arch: arch,
  );
}

int _javaBitnessFromArch(String? arch) {
  if (arch == null) return 0;
  final value = arch.toLowerCase();
  if (value.contains('64')) return 64;
  if (value.contains('86') ||
      value.contains('i386') ||
      value.contains('i686')) {
    return 32;
  }
  return 0;
}

/// Parses the contents of a JDK `release` file without spawning a process.
///
/// Returns null when `JAVA_VERSION` is missing or invalid.
({
  int majorVersion,
  String? vendor,
  int bitness,
  String? fullVersion,
  String? arch,
})?
parseJavaReleaseContents(String contents) {
  final values = <String, String>{};
  for (final line in contents.split(RegExp(r'\r?\n'))) {
    final separator = line.indexOf('=');
    if (separator <= 0) continue;
    final key = line.substring(0, separator).trim();
    var value = line.substring(separator + 1).trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    if (key.isNotEmpty) values[key] = value;
  }
  final version = values['JAVA_VERSION'];
  if (version == null || version.isEmpty) return null;
  final major = parseJavaVersionNumber(version);
  if (major == 0) return null;
  final arch = values['OS_ARCH'];
  final vendor = (values['IMPLEMENTOR'] ?? values['JAVA_VENDOR'])?.trim();
  return (
    majorVersion: major,
    vendor: vendor == null || vendor.isEmpty ? null : vendor,
    bitness: _javaBitnessFromArch(arch),
    fullVersion: version,
    arch: arch,
  );
}

class JavaReleaseInfo {
  const JavaReleaseInfo({
    required this.majorVersion,
    this.vendor,
    this.bitness = 0,
    this.fullVersion,
    this.arch,
  });

  final int majorVersion;
  final String? vendor;
  final int bitness;
  final String? fullVersion;
  final String? arch;
}

class JavaRuntime {
  const JavaRuntime({
    required this.executable,
    required this.majorVersion,
    required this.displayName,
    this.vendor,
    this.bitness = 0,
    this.fullVersion,
    this.isJdk = false,
    this.arch,
    this.source = '',
    this.fromCache = false,
  });

  final String executable;
  final int majorVersion;
  final String displayName;
  final String? vendor;
  final int bitness;
  final String? fullVersion;
  final bool isJdk;
  final String? arch;
  final String source;
  final bool fromCache;

  /// Human readable runtime details used by the Java management card.
  String get detailsLabel {
    final parts = <String>[];
    final vendor = this.vendor?.trim();
    if (vendor != null && vendor.isNotEmpty) parts.add(vendor);
    if (bitness == 64) {
      parts.add('64 位');
    } else if (bitness == 32) {
      parts.add('32 位');
    }
    parts.add(isJdk ? '完整 JDK' : 'JRE');
    return parts.join(' · ');
  }

  Map<String, Object?> toJson() => {
    'executable': executable,
    'majorVersion': majorVersion,
    'displayName': displayName,
    'vendor': vendor,
    'bitness': bitness,
    'fullVersion': fullVersion,
    'isJdk': isJdk,
    'arch': arch,
    'source': source,
  };

  static JavaRuntime? fromJson(Object? value) {
    if (value is! Map) return null;
    final executable = value['executable'];
    final majorVersion = value['majorVersion'];
    if (executable is! String || executable.isEmpty || majorVersion is! int) {
      return null;
    }
    final vendor = value['vendor'];
    final bitness = value['bitness'];
    final fullVersion = value['fullVersion'];
    final isJdk = value['isJdk'];
    final arch = value['arch'];
    final source = value['source'];
    final displayName = value['displayName'];
    return JavaRuntime(
      executable: executable,
      majorVersion: majorVersion,
      displayName: displayName is String && displayName.isNotEmpty
          ? displayName
          : 'Java $majorVersion',
      vendor: vendor is String ? vendor : null,
      bitness: bitness is int ? bitness : 0,
      fullVersion: fullVersion is String ? fullVersion : null,
      isJdk: isJdk is bool ? isJdk : false,
      arch: arch is String ? arch : null,
      source: source is String && source.isNotEmpty ? source : '缓存',
      fromCache: true,
    );
  }
}

typedef JavaRuntimeDiscoverer = Future<List<JavaRuntime>> Function();
typedef JavaRuntimePathResolver = Future<JavaRuntime?> Function(
  String path,
  String source,
);

String decodeJavaProcessResult(Object? output) {
  if (output is List<int>) return decodeJavaProcessOutput(output);
  return output?.toString() ?? '';
}

/// Discovers, probes and caches Java runtimes used by Minecraft.
///
/// The service owns filesystem/process work only. UI state and persistence
/// side effects remain in the page so callers can update their own widget
/// state at a safe point.
Future<JavaRuntime?> javaRuntimeForPath(
  String path, {
  Iterable<JavaRuntime> known = const [],
  String source = '',
}) async {
  final normalized = normalizeJavaPath(path);
  for (final runtime in known) {
    if (normalizeJavaPath(runtime.executable) == normalized &&
        await File(runtime.executable).exists()) {
      return runtime;
    }
  }
  return probeJavaExecutable(path, source: source);
}
JavaRuntime? javaRuntimeForExecutable(
  String executable,
  Iterable<JavaRuntime> runtimes,
) {
  final normalized = normalizeJavaPath(executable);
  return runtimes
      .where((runtime) => normalizeJavaPath(runtime.executable) == normalized)
      .firstOrNull;
}
List<JavaRuntime> sortJavaRuntimes(Iterable<JavaRuntime> runtimes) {
  final list = runtimes.toList();
  list.sort((left, right) {
    final byMajor = right.majorVersion.compareTo(left.majorVersion);
    if (byMajor != 0) return byMajor;
    return left.executable.toLowerCase().compareTo(
      right.executable.toLowerCase(),
    );
  });
  return list;
}
String normalizeJavaPath(String path) {
  final normalized = path.trim().replaceAll('/', Platform.pathSeparator);
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}
Future<JavaRuntime?> probeJavaExecutable(
  String candidate, {
  String source = '',
}) async {
  final file = File(candidate);
  if (!await file.exists()) return null;
  final release = await readJavaReleaseInfo(candidate);
  if (release != null) {
    return JavaRuntime(
      executable: candidate,
      majorVersion: release.majorVersion,
      displayName: 'Java ${release.majorVersion}',
      vendor: release.vendor,
      bitness: release.bitness,
      fullVersion: release.fullVersion,
      isJdk: await hasJavacSibling(candidate),
      arch: release.arch,
      source: source,
    );
  }
  final probeExecutable = await versionProbeJavaExecutable(candidate);
  try {
    final result = await Process.run(
      probeExecutable,
      ['-version'],
      runInShell: false,
      stdoutEncoding: systemEncoding,
      stderrEncoding: systemEncoding,
    );
    if (result.exitCode != 0) return null;
    final versionText =
        '${decodeJavaProcessResult(result.stdout)}\n'
        '${decodeJavaProcessResult(result.stderr)}';
    final major = parseJavaMajorVersion(versionText);
    if (major == 0) return null;
    final details = parseJavaRuntimeDetails(versionText);
    return JavaRuntime(
      executable: candidate,
      majorVersion: major,
      displayName: 'Java $major',
      vendor: details.vendor,
      bitness: details.bitness,
      fullVersion: details.fullVersion,
      isJdk: await hasJavacSibling(candidate),
      arch: details.arch,
      source: source,
    );
  } on ProcessException {
    return null;
  } on FormatException {
    return null;
  }
}

Future<String> versionProbeJavaExecutable(String executable) async {
  if (!Platform.isWindows ||
      !executable.toLowerCase().endsWith('javaw.exe')) {
    return executable;
  }
  final siblingJava =
      '${executable.substring(0, executable.length - 'javaw.exe'.length)}java.exe';
  return await File(siblingJava).exists() ? siblingJava : executable;
}

Future<JavaReleaseInfo?> readJavaReleaseInfo(String executable) async {
  final file = File(executable);
  var home = file.parent;
  if (home.uri.pathSegments.isNotEmpty &&
      home.uri.pathSegments.last.toLowerCase() == 'bin') {
    home = home.parent;
  }
  final releaseFile = File('${home.path}${Platform.pathSeparator}release');
  if (!await releaseFile.exists()) return null;
  try {
    final parsed = parseJavaReleaseContents(await releaseFile.readAsString());
    if (parsed == null) return null;
    return JavaReleaseInfo(
      majorVersion: parsed.majorVersion,
      vendor: parsed.vendor,
      bitness: parsed.bitness,
      fullVersion: parsed.fullVersion,
      arch: parsed.arch,
    );
  } on FileSystemException {
    return null;
  } on FormatException {
    return null;
  }
}

Future<bool> hasJavacSibling(String executable) async {
  final directory = File(executable).parent;
  final javac = File(
    '${directory.path}${Platform.pathSeparator}'
    '${Platform.isWindows ? 'javac.exe' : 'javac'}',
  );
  return javac.exists();
}

void addJavaCandidate(
  Map<String, String> candidates,
  String? rawPath,
  String source,
) {
  if (rawPath == null) return;
  var path = rawPath.trim().replaceAll('"', '');
  if (path.isEmpty) return;
  if (path.toLowerCase().startsWith('file:')) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.scheme == 'file') path = uri.toFilePath();
  }
  final fileName = path.split(RegExp(r'[\\/]')).last.toLowerCase();
  if (const {'java.exe', 'javaw.exe', 'java'}.contains(fileName)) {
    candidates.putIfAbsent(path, () => source);
    return;
  }
  final separator = Platform.pathSeparator;
  final names = Platform.isWindows ? ['java.exe', 'javaw.exe'] : ['java'];
  for (final name in names) {
    candidates.putIfAbsent('$path$separator$name', () => source);
    candidates.putIfAbsent(
      '$path${separator}bin$separator$name',
      () => source,
    );
  }
}

