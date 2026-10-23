import 'dart:convert';
import 'dart:io';

import '../../core/path_utils.dart';

/// Per-client launch overrides stored inside `<version>/BGCL/client.json`.
///
/// A client stays "follow global" until the user changes its Java or memory on
/// the details page; only then does it get a JSON file here. Launching reads
/// this file first, so later global changes cannot disturb such a client.
class ClientLaunchSettings {
  const ClientLaunchSettings({
    this.java = followGlobal,
    this.memoryGb,
  });

  /// Marker meaning "use the global Java selection".
  static const String followGlobal = 'global';
  static const String folderName = 'BGCL';
  static const String fileName = 'client.json';

  /// Global marker or a concrete `java.exe` path.
  final String java;

  /// `null` means the global memory setting is used.
  final double? memoryGb;

  bool get usesOwnJava => java.trim().isNotEmpty && java != followGlobal;

  double? get ownMemoryGb =>
      memoryGb != null && memoryGb! > 0 ? memoryGb : null;

  /// True when this client no longer follows the global defaults.
  bool get isIndependent => usesOwnJava || ownMemoryGb != null;

  static File fileFor(String versionDirectory) => File(
    joinPath(joinPath(versionDirectory, folderName), fileName),
  );

  static Future<ClientLaunchSettings> load(String versionDirectory) async {
    if (versionDirectory.trim().isEmpty) return const ClientLaunchSettings();
    final file = fileFor(versionDirectory);
    try {
      if (!await file.exists()) return const ClientLaunchSettings();
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return const ClientLaunchSettings();
      final java = decoded['java'];
      final memory = decoded['memoryGb'];
      return ClientLaunchSettings(
        java: java is String && java.trim().isNotEmpty
            ? java.trim()
            : followGlobal,
        memoryGb: memory is num && memory > 0 ? memory.toDouble() : null,
      );
    } on Object {
      return const ClientLaunchSettings();
    }
  }

  ClientLaunchSettings copyWith({
    String? java,
    double? memoryGb,
    bool clearMemory = false,
  }) => ClientLaunchSettings(
    java: java ?? this.java,
    memoryGb: clearMemory ? null : (memoryGb ?? this.memoryGb),
  );

  Future<void> save(String versionDirectory) async {
    if (versionDirectory.trim().isEmpty) return;
    final file = fileFor(versionDirectory);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'java': java, 'memoryGb': memoryGb}),
      flush: true,
    );
  }
}
