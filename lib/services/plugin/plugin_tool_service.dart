import 'dart:convert';
import 'dart:io';

/// Captured output of one plugin tool invocation.
class PluginToolResult {
  const PluginToolResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'exitCode': exitCode,
    'stdout': stdout,
    'stderr': stderr,
  };
}

/// Default tool runner used by `execute_tool`.
///
/// Runs the executable directly (`runInShell: false`), never through a shell.
class PluginToolService {
  const PluginToolService._();

  static const Duration timeout = Duration(minutes: 2);

  static Future<PluginToolResult> run(
    String executable,
    List<String> arguments,
    String workingDirectory,
  ) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: false,
    );
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode.timeout(
      timeout,
      onTimeout: () {
        process.kill();
        return -1;
      },
    );
    return PluginToolResult(
      exitCode: exitCode,
      stdout: await stdoutFuture,
      stderr: await stderrFuture,
    );
  }
}
