import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/plugin/plugin_music_library.dart';

/// Material 3 song list rendered by the `musicPlaylist` UI node.
///
/// Scanning is sandboxed to the plugin directory and the parsed title/artist
/// are shown verbatim; tapping plays through the host action callback.
class PluginMusicPlaylist extends StatefulWidget {
  const PluginMusicPlaylist({
    super.key,
    required this.directory,
    required this.folder,
    required this.granted,
    required this.onPlay,
  });

  final String? directory;
  final String folder;
  final bool granted;
  final void Function(String relativePath, String title, String artist) onPlay;

  @override
  State<PluginMusicPlaylist> createState() => _PluginMusicPlaylistState();
}

class _PluginMusicPlaylistState extends State<PluginMusicPlaylist> {
  Future<List<PluginMusicTrack>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PluginMusicPlaylist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directory != widget.directory ||
        oldWidget.folder != widget.folder) {
      _load();
    }
  }

  void _load() {
    final directory = widget.directory;
    if (!widget.granted || directory == null) {
      _future = null;
      return;
    }
    _future = PluginMusicLibrary.scanDirectory(directory, widget.folder);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.granted) {
      return const _MusicHint('权限不足：需要 file_system 权限。');
    }
    if (widget.directory == null) {
      return const _MusicHint('缺少插件目录。');
    }
    return FutureBuilder<List<PluginMusicTrack>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 72,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return _MusicHint('无法读取音乐目录：${snapshot.error}');
        }
        final tracks = snapshot.data ?? const <PluginMusicTrack>[];
        if (tracks.isEmpty) {
          return const _MusicHint('未找到音频文件。');
        }
        return _buildCard(context, tracks);
      },
    );
  }

  Widget _buildCard(BuildContext context, List<PluginMusicTrack> tracks) {
    final theme = Theme.of(context);
    final height = math.min(360.0, tracks.length * 64.0);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: SizedBox(
        height: height,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: tracks.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            indent: 64,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          itemBuilder: (context, index) {
            final track = tracks[index];
            void play() =>
                widget.onPlay(track.relativePath, track.title, track.artist);
            return RepaintBoundary(
              child: ListTile(
                onTap: play,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  track.artist.isEmpty ? '未知歌手' : track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: '播放',
                  onPressed: play,
                  icon: const Icon(Icons.play_circle_fill_rounded),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MusicHint extends StatelessWidget {
  const _MusicHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
