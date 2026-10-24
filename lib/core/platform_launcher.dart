import 'dart:io';

/// Small wrapper around platform URL handlers.
class PlatformLauncher {
  const PlatformLauncher._();

  static Future<void> openUrl(String url) async {
    final command = switch (Platform.operatingSystem) {
      'windows' => ('rundll32.exe', ['url.dll,FileProtocolHandler', url]),
      'macos' => ('open', [url]),
      _ => ('xdg-open', [url]),
    };
    await Process.start(
      command.$1,
      command.$2,
      mode: ProcessStartMode.detached,
    );
  }

  /// Opens [path] with the platform file manager (Explorer / Finder / xdg-open).
  static Future<void> openPath(String path) async {
    final command = switch (Platform.operatingSystem) {
      'windows' => ('explorer.exe', [path]),
      'macos' => ('open', [path]),
      _ => ('xdg-open', [path]),
    };
    await Process.start(
      command.$1,
      command.$2,
      mode: ProcessStartMode.detached,
    );
  }
}
