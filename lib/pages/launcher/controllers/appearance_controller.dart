import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/path_manager.dart';
import '../../../core/path_utils.dart';
import '../../../core/preferences_store.dart';
import '../../../widgets/wallpaper/wallpaper_background.dart';

const int launcherDefaultSunriseMinute = 6 * 60 + 30;
const int launcherDefaultSunsetMinute = 18 * 60 + 30;

const String _lightWallpaperPathKey = 'lightWallpaperPath';
const String _darkWallpaperPathKey = 'darkWallpaperPath';
const String _lightWallpaperPathsKey = 'lightWallpaperPaths';
const String _darkWallpaperPathsKey = 'darkWallpaperPaths';
const String _lightWallpaperCropKey = 'lightWallpaperCrop';
const String _darkWallpaperCropKey = 'darkWallpaperCrop';
const String _lightWallpaperModeKey = 'lightWallpaperDisplayMode';
const String _darkWallpaperModeKey = 'darkWallpaperDisplayMode';
const String _appearanceModeKey = 'launcherAppearanceMode';
const String _randomWallpaperKey = 'randomWallpaperOnStartup';
const Rect _fullCrop = Rect.fromLTWH(0, 0, 1, 1);

/// UI language used before the persisted preference is read.
const Locale launcherDefaultLocale = Locale('zh');

/// Maps a system locale to a shipped launcher locale.
///
/// Chinese systems keep Chinese; every other system language falls back to
/// English. The result drives the first launch, before any preference exists.
Locale detectLauncherLocale(Locale systemLocale) {
  return systemLocale.languageCode.toLowerCase() == 'zh'
      ? const Locale('zh')
      : const Locale('en');
}

/// Locale consumed by the launcher's `MaterialApp`.
///
/// It lives outside the controller because `MaterialApp` is built above the
/// page that owns [AppearanceController], so it cannot listen to it directly.
final ValueNotifier<Locale> launcherLocale = ValueNotifier<Locale>(
  launcherDefaultLocale,
);

enum LauncherAppearanceMode {
  dark('深色', Icons.dark_mode_outlined),
  light('亮色', Icons.light_mode_outlined),
  automatic('日出日落自动', Icons.wb_twilight_outlined);

  const LauncherAppearanceMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

class AppearanceController extends ChangeNotifier {
  AppearanceController({
    required this.onThemeModeChanged,
    PreferencesStore? preferences,
  }) : _preferences = preferences ?? PreferencesStore();

  final ValueChanged<ThemeMode> onThemeModeChanged;
  final PreferencesStore _preferences;

  String? _lightWallpaperPath;
  List<String> _lightWallpaperPaths = <String>[];
  Rect _lightWallpaperCrop = const Rect.fromLTWH(0, 0, 1, 1);
  WallpaperDisplayMode _lightWallpaperDisplayMode = WallpaperDisplayMode.cover;
  String? _darkWallpaperPath;
  List<String> _darkWallpaperPaths = <String>[];
  Rect _darkWallpaperCrop = const Rect.fromLTWH(0, 0, 1, 1);
  WallpaperDisplayMode _darkWallpaperDisplayMode = WallpaperDisplayMode.cover;
  bool _randomWallpaperOnStartup = false;
  LauncherAppearanceMode _appearanceMode = LauncherAppearanceMode.automatic;
  Locale _locale = launcherDefaultLocale;
  int _sunriseMinute = launcherDefaultSunriseMinute;
  int _sunsetMinute = launcherDefaultSunsetMinute;
  bool _solarTimesOnline = false;
  bool _isLoadingSolarTimes = false;
  String? _solarTimesError;
  DateTime? _lastSolarFetch;
  Timer? _themeClock;

  LauncherAppearanceMode get appearanceMode => _appearanceMode;
  int get sunriseMinute => _sunriseMinute;
  int get sunsetMinute => _sunsetMinute;
  bool get solarTimesOnline => _solarTimesOnline;
  bool get isLoadingSolarTimes => _isLoadingSolarTimes;
  String? get solarTimesError => _solarTimesError;
  String? get lightWallpaperPath => _lightWallpaperPath;
  String? get darkWallpaperPath => _darkWallpaperPath;
  List<String> get lightWallpaperPaths =>
      List<String>.unmodifiable(_lightWallpaperPaths);
  List<String> get darkWallpaperPaths =>
      List<String>.unmodifiable(_darkWallpaperPaths);
  bool get randomWallpaperOnStartup => _randomWallpaperOnStartup;
  Rect get lightWallpaperCrop => _lightWallpaperCrop;
  Rect get darkWallpaperCrop => _darkWallpaperCrop;
  WallpaperDisplayMode get lightWallpaperDisplayMode =>
      _lightWallpaperDisplayMode;
  WallpaperDisplayMode get darkWallpaperDisplayMode =>
      _darkWallpaperDisplayMode;

  /// Currently selected UI language.
  Locale get locale => _locale;

  /// Switches the UI language immediately and persists the choice.
  set locale(Locale value) => setLocale(value);

  /// Restores the persisted UI language without rewriting preferences.
  ///
  /// When the player never picked a language, the system locale detected before
  /// `runApp` (already stored in [launcherLocale]) decides between Chinese and
  /// English. A saved choice always wins.
  Future<void> loadLanguagePreference({Locale? systemLocale}) async {
    final stored = await _preferences.readLanguageOrNull();
    if (stored != null) {
      _applyLocale(Locale(stored), persist: false);
      return;
    }
    _applyLocale(
      detectLauncherLocale(systemLocale ?? launcherLocale.value),
      persist: false,
    );
  }

  /// Applies [locale], falling back to Chinese for unsupported languages.
  void setLocale(Locale locale) {
    _applyLocale(normalizeLocale(locale), persist: true);
  }

  /// Normalizes [locale] to one of the languages shipped with the launcher.
  static Locale normalizeLocale(Locale locale) {
    final code = locale.languageCode.toLowerCase();
    return PreferencesStore.supportedLanguages.contains(code)
        ? Locale(code)
        : launcherDefaultLocale;
  }

  void _applyLocale(Locale locale, {required bool persist}) {
    final changed = _locale != locale;
    _locale = locale;
    if (launcherLocale.value != locale) launcherLocale.value = locale;
    if (persist) {
      unawaited(_preferences.setLanguage(locale.languageCode));
    }
    if (changed) notifyListeners();
  }

  /// Restores wallpaper paths, crops and display modes from preferences.
  Future<void> loadWallpaperPreferences() async {
    try {
      final decoded = await _preferences.readAll();
      if (decoded.isEmpty) return;
      _lightWallpaperPath = _readPath(decoded[_lightWallpaperPathKey]);
      _darkWallpaperPath = _readPath(decoded[_darkWallpaperPathKey]);
      _lightWallpaperPaths = _readPaths(decoded[_lightWallpaperPathsKey]);
      _darkWallpaperPaths = _readPaths(decoded[_darkWallpaperPathsKey]);
      if (_lightWallpaperPath != null &&
          !_lightWallpaperPaths.contains(_lightWallpaperPath)) {
        _lightWallpaperPaths.add(_lightWallpaperPath!);
      }
      if (_darkWallpaperPath != null &&
          !_darkWallpaperPaths.contains(_darkWallpaperPath)) {
        _darkWallpaperPaths.add(_darkWallpaperPath!);
      }
      _randomWallpaperOnStartup = decoded[_randomWallpaperKey] == true;
      final storedMode = decoded[_appearanceModeKey];
      if (storedMode is String) {
        for (final mode in LauncherAppearanceMode.values) {
          if (mode.name == storedMode) {
            _appearanceMode = mode;
            break;
          }
        }
      }
      _lightWallpaperCrop = _readCrop(decoded[_lightWallpaperCropKey]);
      _darkWallpaperCrop = _readCrop(decoded[_darkWallpaperCropKey]);
      _lightWallpaperDisplayMode = _readDisplayMode(
        decoded[_lightWallpaperModeKey],
      );
      _darkWallpaperDisplayMode = _readDisplayMode(
        decoded[_darkWallpaperModeKey],
      );
      notifyListeners();
    } on FormatException {
      // A corrupt preferences file must not block the launcher.
    } on FileSystemException {
      // Wallpapers simply fall back to their defaults.
    }
  }

  void _persistWallpaper({required bool dark}) {
    final crop = dark ? _darkWallpaperCrop : _lightWallpaperCrop;
    final mode = dark ? _darkWallpaperDisplayMode : _lightWallpaperDisplayMode;
    unawaited(
      _preferences.write(
        dark ? _darkWallpaperPathKey : _lightWallpaperPathKey,
        dark ? _darkWallpaperPath : _lightWallpaperPath,
      ),
    );
    unawaited(
      _preferences.write(
        dark ? _darkWallpaperPathsKey : _lightWallpaperPathsKey,
        List<String>.from(dark ? _darkWallpaperPaths : _lightWallpaperPaths),
      ),
    );
    unawaited(
      _preferences.write(
        dark ? _darkWallpaperCropKey : _lightWallpaperCropKey,
        <double>[crop.left, crop.top, crop.right, crop.bottom],
      ),
    );
    unawaited(
      _preferences.write(
        dark ? _darkWallpaperModeKey : _lightWallpaperModeKey,
        mode.name,
      ),
    );
  }

  String? _readPath(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  List<String> _readPaths(Object? value) {
    if (value is! List) return <String>[];
    final paths = <String>[];
    for (final item in value) {
      final path = _readPath(item);
      if (path != null && !paths.contains(path)) paths.add(path);
    }
    return paths;
  }

  Rect _readCrop(Object? value) {
    if (value is List && value.length == 4) {
      final numbers = <double>[];
      for (final item in value) {
        if (item is! num) return _fullCrop;
        numbers.add(item.toDouble().clamp(0.0, 1.0).toDouble());
      }
      final rect = Rect.fromLTRB(
        numbers[0],
        numbers[1],
        numbers[2],
        numbers[3],
      );
      if (rect.width <= 0 || rect.height <= 0) return _fullCrop;
      return rect;
    }
    return _fullCrop;
  }

  WallpaperDisplayMode _readDisplayMode(Object? value) {
    if (value is String) {
      for (final mode in WallpaperDisplayMode.values) {
        if (mode.name == value) return mode;
      }
    }
    return WallpaperDisplayMode.cover;
  }

  void startClock() {
    _themeClock?.cancel();
    _themeClock = Timer.periodic(
      const Duration(minutes: 1),
      (_) => applyAppearanceMode(),
    );
  }

  void applyAppearanceMode() {
    final now = DateTime.now();
    if (_appearanceMode == LauncherAppearanceMode.automatic &&
        (_lastSolarFetch == null ||
            now.difference(_lastSolarFetch!) > const Duration(hours: 12))) {
      unawaited(loadSolarTimes());
    }
    final minutes = now.hour * 60 + now.minute;
    final useDark = switch (_appearanceMode) {
      LauncherAppearanceMode.dark => true,
      LauncherAppearanceMode.light => false,
      LauncherAppearanceMode.automatic =>
        minutes < _sunriseMinute || minutes >= _sunsetMinute,
    };
    onThemeModeChanged(useDark ? ThemeMode.dark : ThemeMode.light);
  }

  void setAppearanceMode(LauncherAppearanceMode mode) {
    _appearanceMode = mode;
    _lastSolarFetch = null;
    unawaited(_preferences.write(_appearanceModeKey, mode.name));
    applyAppearanceMode();
    notifyListeners();
  }

  Future<void> loadSolarTimes() async {
    if (_isLoadingSolarTimes) return;
    _isLoadingSolarTimes = true;
    _solarTimesError = null;
    notifyListeners();

    final localOffset = DateTime.now().timeZoneOffset;
    final longitude = localOffset.inMinutes / 4;
    final date = DateTime.now();
    final dateString =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final uri = Uri.https('api.sunrise-sunset.org', '/json', {
      'lat': '0',
      'lng': longitude.toStringAsFixed(4),
      'date': dateString,
      'formatted': '0',
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('日出日落服务返回 HTTP ${response.statusCode}', uri: uri);
      }
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 8));
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic> ||
          decoded['status'] != 'OK' ||
          decoded['results'] is! Map<String, dynamic>) {
        throw const FormatException('日出日落服务返回了无效数据');
      }
      final results = decoded['results'] as Map<String, dynamic>;
      final sunriseValue = results['sunrise'];
      final sunsetValue = results['sunset'];
      if (sunriseValue is! String || sunsetValue is! String) {
        throw const FormatException('日出日落服务缺少 sunrise/sunset');
      }
      final sunrise = DateTime.parse(sunriseValue).toLocal();
      final sunset = DateTime.parse(sunsetValue).toLocal();
      if (sunset.isBefore(sunrise)) {
        throw const FormatException('日出日落顺序无效');
      }
      _sunriseMinute = sunrise.hour * 60 + sunrise.minute;
      _sunsetMinute = sunset.hour * 60 + sunset.minute;
      _solarTimesOnline = true;
      _solarTimesError = null;
      _isLoadingSolarTimes = false;
      _lastSolarFetch = DateTime.now();
      notifyListeners();
      applyAppearanceMode();
    } on SocketException catch (error) {
      _setSolarTimeFallback('网络不可用：${error.message}');
    } on HttpException catch (error) {
      _setSolarTimeFallback('无法获取日出日落时间：${error.message}');
    } on TimeoutException {
      _setSolarTimeFallback('获取日出日落时间超时');
    } on FormatException catch (error) {
      _setSolarTimeFallback('日出日落数据格式无效：${error.message}');
    } on HandshakeException catch (error) {
      _setSolarTimeFallback('无法建立日出日落服务连接：${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  void refreshSolarTimes() {
    _lastSolarFetch = null;
    unawaited(loadSolarTimes());
  }

  void _setSolarTimeFallback(String message) {
    _sunriseMinute = launcherDefaultSunriseMinute;
    _sunsetMinute = launcherDefaultSunsetMinute;
    _solarTimesOnline = false;
    _solarTimesError = message;
    _isLoadingSolarTimes = false;
    _lastSolarFetch = DateTime.now();
    notifyListeners();
    applyAppearanceMode();
  }

  /// Copies [path] into `BGCL/user_data/wallpapers` and applies it.
  ///
  /// Keeping only the picked path would break the wallpaper as soon as the
  /// player moves, renames or deletes the original image.
  Future<void> setWallpaper({
    required bool dark,
    required String path,
    required Rect crop,
  }) async {
    final storedPath = await _cacheWallpaperFile(path: path, dark: dark);
    final paths = dark ? _darkWallpaperPaths : _lightWallpaperPaths;
    if (!paths.contains(storedPath)) paths.add(storedPath);
    if (dark) {
      _darkWallpaperPath = storedPath;
      _darkWallpaperCrop = crop;
    } else {
      _lightWallpaperPath = storedPath;
      _lightWallpaperCrop = crop;
    }
    notifyListeners();
    _persistWallpaper(dark: dark);
  }

  /// Copies the picked image into the launcher cache and returns its new path.
  ///
  /// Falls back to the original path when the launcher root is not configured
  /// yet or the copy fails, so the player never loses the choice.
  Future<String> _cacheWallpaperFile({
    required String path,
    required bool dark,
  }) async {
    final directoryPath = PathManager.instance.userWallpapersDir;
    if (directoryPath == null) return path;
    if (_isInsideDirectory(path, directoryPath)) return path;
    try {
      final directory = Directory(directoryPath);
      await directory.create(recursive: true);
      final fileName =
          'wallpaper_${dark ? 'dark' : 'light'}_'
          '${DateTime.now().microsecondsSinceEpoch}${_imageExtension(path)}';
      final target = File(joinPath(directory.path, fileName));
      await File(path).copy(target.path);
      return target.path;
    } on FileSystemException {
      // A removed drive or a permission error must not discard the choice.
      return path;
    }
  }

  /// Deletes a cached wallpaper that is no longer referenced.
  Future<void> _deleteCachedWallpaper(String? path, {String? keepPath}) async {
    if (path == null || path == keepPath) return;
    final directoryPath = PathManager.instance.userWallpapersDir;
    if (directoryPath == null) return;
    if (!_isInsideDirectory(path, directoryPath)) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A preview or virus scanner may hold the file briefly; the next import
      // retries, so a failed cleanup is not fatal.
    }
  }

  String _imageExtension(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '.img';
    final extension = name.substring(dot).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(extension)
        ? extension
        : '.img';
  }

  bool _isInsideDirectory(String path, String directory) {
    final target = File(path).absolute.path;
    final base = Directory(directory).absolute.path;
    final separator = Platform.pathSeparator;
    final prefix = base.endsWith(separator) ? base : '$base$separator';
    if (Platform.isWindows) {
      return target.toLowerCase().startsWith(prefix.toLowerCase());
    }
    return target.startsWith(prefix);
  }

  void setWallpaperCrop({required bool dark, required Rect crop}) {
    if (dark) {
      _darkWallpaperCrop = crop;
    } else {
      _lightWallpaperCrop = crop;
    }
    notifyListeners();
    _persistWallpaper(dark: dark);
  }

  void setWallpaperDisplayMode({
    required bool dark,
    required WallpaperDisplayMode mode,
  }) {
    if (dark) {
      _darkWallpaperDisplayMode = mode;
    } else {
      _lightWallpaperDisplayMode = mode;
    }
    notifyListeners();
    _persistWallpaper(dark: dark);
  }

  void resetWallpaper({required bool dark}) {
    final previous = dark ? _darkWallpaperPath : _lightWallpaperPath;
    final paths = dark ? _darkWallpaperPaths : _lightWallpaperPaths;
    if (previous != null) paths.remove(previous);
    final next = paths.firstOrNull;
    if (dark) {
      _darkWallpaperPath = next;
      _darkWallpaperCrop = const Rect.fromLTWH(0, 0, 1, 1);
      _darkWallpaperDisplayMode = WallpaperDisplayMode.cover;
    } else {
      _lightWallpaperPath = next;
      _lightWallpaperCrop = const Rect.fromLTWH(0, 0, 1, 1);
      _lightWallpaperDisplayMode = WallpaperDisplayMode.cover;
    }
    notifyListeners();
    _persistWallpaper(dark: dark);
    if (!_lightWallpaperPaths.contains(previous) &&
        !_darkWallpaperPaths.contains(previous)) {
      unawaited(_deleteCachedWallpaper(previous));
    }
  }

  String? wallpaperPath(bool dark) =>
      dark ? _darkWallpaperPath : _lightWallpaperPath;
  Rect wallpaperCrop(bool dark) =>
      dark ? _darkWallpaperCrop : _lightWallpaperCrop;
  WallpaperDisplayMode wallpaperDisplayMode(bool dark) =>
      dark ? _darkWallpaperDisplayMode : _lightWallpaperDisplayMode;

  List<String> wallpaperPaths(bool dark) => List<String>.unmodifiable(
    dark ? _darkWallpaperPaths : _lightWallpaperPaths,
  );

  Future<void> selectWallpaper({
    required bool dark,
    required String path,
  }) async {
    final paths = dark ? _darkWallpaperPaths : _lightWallpaperPaths;
    if (!paths.contains(path)) return;
    if (dark) {
      _darkWallpaperPath = path;
      _darkWallpaperCrop = _fullCrop;
    } else {
      _lightWallpaperPath = path;
      _lightWallpaperCrop = _fullCrop;
    }
    notifyListeners();
    _persistWallpaper(dark: dark);
  }

  Future<void> removeWallpaper({
    required bool dark,
    required String path,
  }) async {
    final paths = dark ? _darkWallpaperPaths : _lightWallpaperPaths;
    if (!paths.remove(path)) return;
    final active = dark ? _darkWallpaperPath : _lightWallpaperPath;
    if (active == path) {
      final next = paths.firstOrNull;
      if (dark) {
        _darkWallpaperPath = next;
        _darkWallpaperCrop = _fullCrop;
      } else {
        _lightWallpaperPath = next;
        _lightWallpaperCrop = _fullCrop;
      }
    }
    notifyListeners();
    _persistWallpaper(dark: dark);
    if (!_lightWallpaperPaths.contains(path) &&
        !_darkWallpaperPaths.contains(path)) {
      await _deleteCachedWallpaper(path);
    }
  }

  Future<void> setRandomWallpaperOnStartup(bool value) async {
    if (_randomWallpaperOnStartup == value) return;
    _randomWallpaperOnStartup = value;
    notifyListeners();
    await _preferences.write(_randomWallpaperKey, value);
  }

  /// Chooses one wallpaper from the active theme's list before the UI starts.
  ///
  /// This is called from `main()` so the very first frame already uses the
  /// selected list entry. It is a no-op unless the player enabled random mode.
  static Future<void> prepareStartupWallpaper({
    PreferencesStore? preferences,
  }) async {
    try {
      final store = preferences ?? PreferencesStore();
      final decoded = await store.readAll();
      if (decoded[_randomWallpaperKey] != true) return;

      var mode = LauncherAppearanceMode.automatic;
      final storedMode = decoded[_appearanceModeKey];
      if (storedMode is String) {
        for (final candidate in LauncherAppearanceMode.values) {
          if (candidate.name == storedMode) {
            mode = candidate;
            break;
          }
        }
      }
      final now = DateTime.now();
      final minutes = now.hour * 60 + now.minute;
      final useDark = switch (mode) {
        LauncherAppearanceMode.dark => true,
        LauncherAppearanceMode.light => false,
        LauncherAppearanceMode.automatic =>
          minutes < launcherDefaultSunriseMinute ||
              minutes >= launcherDefaultSunsetMinute,
      };
      final rawPaths =
          decoded[useDark ? _darkWallpaperPathsKey : _lightWallpaperPathsKey];
      if (rawPaths is! List) return;
      final paths = <String>[
        for (final item in rawPaths)
          if (item is String &&
              item.trim().isNotEmpty &&
              File(item).existsSync())
            item,
      ];
      if (paths.isEmpty) return;
      final selected = paths[math.Random().nextInt(paths.length)];
      await store.write(
        useDark ? _darkWallpaperPathKey : _lightWallpaperPathKey,
        selected,
      );
      await store.write(
        useDark ? _darkWallpaperCropKey : _lightWallpaperCropKey,
        <double>[
          _fullCrop.left,
          _fullCrop.top,
          _fullCrop.right,
          _fullCrop.bottom,
        ],
      );
    } on Object {
      // Random wallpaper is cosmetic; startup must continue on any failure.
    }
  }

  String formatMinutes(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  double estimatedLongitude() => DateTime.now().timeZoneOffset.inMinutes / 4;

  String formatOffset(Duration offset) {
    final totalMinutes = offset.inMinutes.abs();
    final sign = offset.isNegative ? '-' : '+';
    return '$sign${(totalMinutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(totalMinutes % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _themeClock?.cancel();
    super.dispose();
  }
}
