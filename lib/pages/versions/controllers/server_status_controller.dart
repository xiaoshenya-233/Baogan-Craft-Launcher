import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/launcher_log.dart';
import '../../../services/launcher/server_service.dart';

/// Loads the saved server list of one client and refreshes its latency.
///
/// [minecraftPath] is the client directory that holds `servers.dat`
/// (`<minecraft>/versions/<client>`), matching the per-client layout used by
/// the rest of the launcher.
class ServerStatusController extends ChangeNotifier {
  ServerStatusController({required this.minecraftPath, this.onFastJoin});

  final String minecraftPath;

  /// Invoked by the "快速加入" button; wired to the launch flow by the page.
  final Future<void> Function(ServerEntry server)? onFastJoin;

  List<ServerEntry> _servers = const <ServerEntry>[];
  bool _isLoading = false;
  bool _isJoining = false;
  String? _joiningAddress;
  String? _error;
  bool _isDisposed = false;
  int _requestId = 0;

  List<ServerEntry> get servers => _servers;
  bool get isLoading => _isLoading;
  bool get isJoining => _isJoining;
  String? get joiningAddress => _joiningAddress;
  String? get error => _error;
  int get onlineCount => _servers.where((server) => server.isOnline).length;

  /// Parses `servers.dat` and pings every entry with at most five sockets.
  Future<void> loadAndPingServers() async {
    if (_isLoading) return;
    final requestId = ++_requestId;
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final parsed = await ServerService.readServers(minecraftPath);
      if (_isDisposed || requestId != _requestId) return;
      // Show the list immediately, then fill in the latency values.
      _servers = parsed;
      _notify();
      final pinged = await ServerService.pingAll(parsed);
      if (_isDisposed || requestId != _requestId) return;
      _servers = pinged;
    } on FileSystemException catch (error) {
      _error = '读取 servers.dat 失败：${error.message}';
    } on Object catch (error) {
      _error = '服务器检测失败：$error';
    } finally {
      if (!_isDisposed && requestId == _requestId) {
        _isLoading = false;
        _notify();
      }
    }
  }

  /// Starts the game and connects to [server] (`--server` / `--port`).
  Future<void> fastJoin(ServerEntry server) async {
    if (_isJoining) return;
    final handler = onFastJoin;
    if (handler == null) {
      LauncherLog.warning('Servers', '未配置快速加入回调，已忽略：${server.address}');
      return;
    }
    _isJoining = true;
    _joiningAddress = server.address;
    _notify();
    LauncherLog.info('Servers', '快速加入请求：${server.name}（${server.address}）');
    try {
      await handler(server);
    } on Object catch (error) {
      LauncherLog.warning('Servers', '快速加入失败：${server.address}（$error）');
    } finally {
      _isJoining = false;
      _joiningAddress = null;
      _notify();
    }
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
