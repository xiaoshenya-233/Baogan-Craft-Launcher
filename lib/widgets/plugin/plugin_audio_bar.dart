import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/plugin/plugin_audio_service.dart';

/// Simple playback bar used by the renderer's `audioPlayer` / `musicBar` node.
class PluginAudioBar extends StatelessWidget {
  const PluginAudioBar({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final audio = PluginAudioService.instance;
    return AnimatedBuilder(
      animation: audio,
      builder: (context, _) {
        final duration = audio.duration.inMilliseconds;
        final progress = duration <= 0
            ? 0.0
            : (audio.position.inMilliseconds / duration).clamp(0.0, 1.0);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: audio.hasSource
                        ? () => unawaited(
                            audio.playing ? audio.pause() : audio.resume(),
                          )
                        : null,
                    icon: Icon(
                      audio.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      label ?? audio.source ?? 'Audio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    onPressed: audio.hasSource
                        ? () => unawaited(audio.stop())
                        : null,
                    icon: const Icon(Icons.stop_rounded),
                  ),
                ],
              ),
              Slider(
                value: progress,
                onChanged: duration <= 0
                    ? null
                    : (value) => unawaited(
                        audio.seek(
                          Duration(milliseconds: (value * duration).round()),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
