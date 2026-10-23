import 'package:flutter/material.dart';

import '../../../services/launcher/server_service.dart';
import '../../launcher/launcher_palette.dart';
import '../controllers/server_status_controller.dart';

/// Server card shown on the client details page.
///
/// The list is loaded and pinged when the widget appears, so opening a client
/// detail page is the only trigger; nothing runs during the version scan.
class ServerListSection extends StatefulWidget {
  const ServerListSection({
    super.key,
    required this.clientDirectory,
    required this.palette,
    required this.onMessage,
    required this.onFastJoin,
  });

  final String clientDirectory;
  final LauncherPalette palette;
  final ValueChanged<String> onMessage;

  /// Launches the client with `--server`/`--port` for the chosen entry.
  final Future<void> Function(ServerEntry server) onFastJoin;

  @override
  State<ServerListSection> createState() => _ServerListSectionState();
}

class _ServerListSectionState extends State<ServerListSection> {
  late final ServerStatusController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ServerStatusController(
      minecraftPath: widget.clientDirectory,
      onFastJoin: (server) => widget.onFastJoin(server),
    )..addListener(_refresh);
    _controller.loadAndPingServers();
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _startJoin(ServerEntry server) async {
    widget.onMessage('正在启动 ${server.name}（${server.address}）…');
    await _controller.fastJoin(server);
  }

  Color _statusColor(ServerEntry server) {
    if (!server.isOnline) return const Color(0xFFE05B5B);
    return server.ping <= 120
        ? const Color(0xFF7BC043)
        : const Color(0xFFE0B04A);
  }

  String get _summary {
    if (_controller.isLoading) return '正在检测服务器延迟…';
    final servers = _controller.servers;
    if (servers.isEmpty) return '未读取到已保存的服务器';
    return '${servers.length} 个服务器 · ${_controller.onlineCount} 个在线';
  }

  @override
  Widget build(BuildContext context) {
    final muted = widget.palette.muted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _summary,
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ),
            IconButton(
              tooltip: '重新检测',
              onPressed: _controller.isLoading
                  ? null
                  : _controller.loadAndPingServers,
              icon: Icon(Icons.refresh_rounded, color: muted),
            ),
          ],
        ),
        if (_controller.isLoading) const LinearProgressIndicator(minHeight: 2),
        if (_controller.error != null)
          Text(
            _controller.error!,
            style: const TextStyle(fontSize: 11, color: Color(0xFFE05B5B)),
          ),
        ..._controller.servers.map(
          (server) => ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              Icons.circle,
              size: 10,
              color: _statusColor(server),
            ),
            title: Text(
              server.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            subtitle: Text(
              server.address,
              style: TextStyle(fontSize: 10, color: muted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  server.isOnline ? '${server.ping} ms' : '超时',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(server),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: _controller.isJoining
                      ? null
                      : () => _startJoin(server),
                  child: Text(
                    _controller.isJoining &&
                            _controller.joiningAddress == server.address
                        ? '启动中…'
                        : '快速加入',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
