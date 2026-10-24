import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Thin backend seam so unit tests can verify routing without platform
/// channels; production uses [AudioPlayersBackend].
abstract class PluginAudioBackend {
  Future<void> play(String source, {required bool isUrl});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> setVolume(double volume);
  Future<void> seek(Duration position);

  Stream<bool> get playingStream => const Stream<bool>.empty();
  Stream<Duration> get positionStream => const Stream<Duration>.empty();
  Stream<Duration> get durationStream => const Stream<Duration>.empty();
  Stream<void> get completionStream => const Stream<void>.empty();
}

/// Uses the platform decoders exposed by `audioplayers` (no bundled codecs).
class AudioPlayersBackend implements PluginAudioBackend {
  AudioPlayer? _player;

  AudioPlayer get _audio => _player ??= AudioPlayer();

  @override
  Stream<bool> get playingStream =>
      _audio.onPlayerStateChanged.map((state) => state == PlayerState.playing);

  @override
  Stream<Duration> get positionStream => _audio.onPositionChanged;

  @override
  Stream<Duration> get durationStream => _audio.onDurationChanged;

  @override
  Stream<void> get completionStream => _audio.onPlayerComplete;

  @override
  Future<void> play(String source, {required bool isUrl}) =>
      _audio.play(isUrl ? UrlSource(source) : DeviceFileSource(source));

  @override
  Future<void> pause() => _audio.pause();

  @override
  Future<void> resume() => _audio.resume();

  @override
  Future<void> stop() => _audio.stop();

  @override
  Future<void> setVolume(double volume) => _audio.setVolume(volume);

  @override
  Future<void> seek(Duration position) => _audio.seek(position);
}

/// Global audio player for plugins.
///
/// One shared [AudioPlayer] is enough for background music / sound effects;
/// the service also exposes playback state for the renderer's audio bar.
class PluginAudioService extends ChangeNotifier {
  PluginAudioService._();

  static final PluginAudioService instance = PluginAudioService._();

  PluginAudioBackend? _backend;
  bool _bound = false;
  String? _source;
  bool _playing = false;
  double _volume = 1;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final StreamController<void> _completions =
      StreamController<void>.broadcast();

  String? get source => _source;
  bool get playing => _playing;
  bool get isPlaying => _playing;
  bool get hasSource => _source != null;
  double get volume => _volume;
  Duration get position => _position;
  Duration get duration => _duration;

  /// Emits when the underlying player finishes the current source.
  Stream<void> get completions => _completions.stream;

  /// Replaces the platform backend (tests) and drops the previous bindings.
  @visibleForTesting
  set backend(PluginAudioBackend value) {
    _backend = value;
    _bound = false;
  }

  @visibleForTesting
  void resetForTest() {
    _backend = null;
    _bound = false;
    _source = null;
    _playing = false;
    _volume = 1;
    _position = Duration.zero;
    _duration = Duration.zero;
  }

  PluginAudioBackend get _activeBackend {
    final backend = _backend ??= AudioPlayersBackend();
    if (!_bound) {
      _bound = true;
      backend.playingStream.listen((value) {
        _playing = value;
        notifyListeners();
      });
      backend.positionStream.listen((value) {
        _position = value;
        notifyListeners();
      });
      backend.durationStream.listen((value) {
        _duration = value;
        notifyListeners();
      });
      backend.completionStream.listen((_) => _completions.add(null));
    }
    return backend;
  }

  /// Plays a network URL or a local file path (`file://` is stripped).
  Future<void> play(String urlOrPath) async {
    final raw = urlOrPath.trim();
    if (raw.isEmpty) {
      throw ArgumentError('音频地址不能为空。');
    }
    final normalized = normalizeSource(raw);
    final isUrl = isNetworkSource(normalized);
    await _activeBackend.play(normalized, isUrl: isUrl);
    _source = normalized;
    _playing = true;
    _position = Duration.zero;
    notifyListeners();
  }

  Future<void> pause() async {
    await _activeBackend.pause();
    _playing = false;
    notifyListeners();
  }

  Future<void> resume() async {
    await _activeBackend.resume();
    _playing = true;
    notifyListeners();
  }

  Future<void> stop() async {
    try {
      await _activeBackend.stop();
    } finally {
      _playing = false;
      _source = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      notifyListeners();
    }
  }

  Future<void> setVolume(double volume) async {
    final value = volume.clamp(0.0, 1.0).toDouble();
    await _activeBackend.setVolume(value);
    _volume = value;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    final value = position.isNegative ? Duration.zero : position;
    await _activeBackend.seek(value);
    _position = value;
    notifyListeners();
  }

  static bool isNetworkSource(String source) =>
      source.startsWith('http://') || source.startsWith('https://');

  /// Converts `file://` URIs to a plain path; other values pass through.
  static String normalizeSource(String source) {
    final value = source.trim();
    if (value.startsWith('file://')) return Uri.parse(value).toFilePath();
    return value;
  }
}
