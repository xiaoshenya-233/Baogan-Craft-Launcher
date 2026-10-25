import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/launcher_log.dart';
import '../../core/path_manager.dart';

const String mcmodApiHost = 'mcmod-api.zkitefly.eu.org';
const String mcmodApiEndpoint = '/s/key=';

/// Normalizes an English mod name for matching and cache keys.
String normalizeMcmodTitleKey(String title) {
  return title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"['’]"), '')
      .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _compactMcmodTitleKey(String title) =>
    normalizeMcmodTitleKey(title).replaceAll(' ', '');

bool _containsChinese(String value) =>
    RegExp(r'[\u4e00-\u9fff]').hasMatch(value);

/// Longest Chinese name accepted from mcmod; mod names are much shorter than
/// wiki entry titles, so longer values are treated as scraped garbage.
const int maxChineseModNameLength = 20;

/// mcmod wiki page kinds that describe an entry instead of a mod, such as
/// `(物品/方块) Meka工具` or `(教程) 通用机械入门`.
const List<String> mcmodEntryKinds = <String>[
  '物品/方块/实体',
  '物品/方块',
  '多方块结构',
  '状态效果',
  '游戏版本',
  '整合包',
  '服务器',
  '教程',
  '模组',
  '命令',
  '附魔',
  '药水',
  '生物',
  '实体',
  '结构',
  '维度',
  '进度',
  '标签',
  '机制',
  '配置',
  '食物',
  '工具',
  '武器',
  '盔甲',
  '矿物',
  '物品',
  '方块',
];

final RegExp _mcmodEntryMarker = RegExp(
  '[\\s\u3000]*[\\(（]\\s*(?:${mcmodEntryKinds.map(RegExp.escape).join('|')})'
  '\\s*[\\)）]',
);

/// True when [value] carries a wiki page kind such as `(物品/方块)`.
bool isMcmodEntryTitle(String value) => _mcmodEntryMarker.hasMatch(value);

bool _startsWithEntryKind(String value) {
  final match = _mcmodEntryMarker.firstMatch(value);
  return match != null && match.start == 0;
}

/// Extracts the mod name from `Meka工具 (Meka-Tool) - [Mek] 通用机械`.
///
/// Item pages append ` - [MODID] <mod name>`; that tail is the only part of
/// such a scraped title that can be trusted as a mod name.
String? _mcmodModNameSuffix(String value) {
  final match = RegExp(
    r'^.*[-\u2010-\u2015|]\s*\[[^\]]+\]\s*(\S.*)$',
  ).firstMatch(value.trim());
  return match?.group(1)?.trim();
}

String _stripLeadingBrackets(String value) {
  var result = value;
  for (var index = 0; index < 3; index++) {
    final next = result.replaceFirst(RegExp(r'^\[[^\]]*\]\s*'), '');
    if (next == result) break;
    result = next;
  }
  return result;
}

String _stripTrailingParentheses(String value) {
  var result = value;
  for (var index = 0; index < 3; index++) {
    final next = result.replaceFirst(RegExp(r'\s*[\(（][^\)）]*[\)）]\s*$'), '');
    if (next == result) break;
    result = next;
  }
  return result.trim();
}

/// Rejects values that must never be shown as a Chinese mod name.
bool isValidChineseModTitle(String value) {
  final title = value.trim();
  if (title.isEmpty) return false;
  if (!_containsChinese(title)) return false;
  if (title.runes.length > maxChineseModNameLength) return false;
  if (isMcmodEntryTitle(title)) return false;
  // Leftover wiki markup means the title was only partially stripped.
  if (RegExp(r'[\[\]\(\)（）]').hasMatch(title)) return false;
  if (RegExp(r'\s[-\u2013\u2014|]\s').hasMatch(title)) return false;
  return true;
}

/// Turns an mcmod title into a displayable Chinese mod name.
///
/// Handles the wiki formats seen in the API, e.g.
/// `[Mek] 通用机械` -> `通用机械`,
/// `(Meka工具) (Meka-Tool) - [Mek] 通用机械` -> `通用机械`,
/// `钠 (Sodium)` -> `钠`.
///
/// Returns an empty string when the title is an entry page without a usable mod
/// name (`(物品/方块) Meka工具`), is too long, or still contains wiki markup, so
/// callers can fall back to the English name.
String cleanChineseTitle(String value) {
  var title = value.trim();
  if (title.isEmpty) return '';

  final suffix = _mcmodModNameSuffix(title);
  if (_startsWithEntryKind(title)) {
    // `(物品/方块) 富集铀锭` is an item page: reject it unless the trailing
    // `- [Mek] 通用机械` fragment still names the owning mod.
    if (suffix == null) return '';
    title = suffix;
  } else {
    title = suffix ?? title;
  }

  title = _stripLeadingBrackets(title);
  title = _stripTrailingParentheses(title);
  title = title.replaceAll(RegExp(r'[\s\u3000]+'), ' ').trim();
  return isValidChineseModTitle(title) ? title : '';
}

/// One resolved display name together with aliases collected from the same
/// API response.
///
/// [aliases] uses normalized English keys, so one request such as `Sodium`
/// can also populate related titles such as `Sodium Extra`.
class McmodTitleLookup {
  const McmodTitleLookup({required this.chinese, required this.aliases});

  final String chinese;
  final Map<String, String> aliases;
}

/// Removes a trailing platform/loader qualifier such as `(Fabric)` or
/// `[Forge]`. Some resource search results append these, while mcmod usually
/// stores only the base English name.
String _mcmodBaseTitle(String value) {
  var result = value.trim();
  for (var index = 0; index < 3; index++) {
    final previous = result;
    result = result
        .replaceFirst(RegExp(r'\s*\[[^\]]*\]\s*$'), '')
        .replaceFirst(RegExp(r'\s*[\(（][^\)）]*[\)）]\s*$'), '')
        .replaceFirst(
          RegExp(
            r'(?:\s+|[:\-–—|]\s*)'
            r'(?:forge|neoforge|fabric|quilt|common)\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    if (result == previous) break;
  }
  return result;
}

String? _mcmodEntryChinese(Map data, String title) {
  final candidates = <String>[];
  final chineseName = data['chinese_name'];
  if (chineseName is String && chineseName.trim().isNotEmpty) {
    candidates.add(chineseName);
  }
  candidates.add(title);
  for (final candidate in candidates) {
    final cleaned = cleanChineseTitle(candidate);
    if (cleaned.isNotEmpty && _containsChinese(cleaned)) return cleaned;
  }
  return null;
}

Set<String> _mcmodEntryAliases(Map data, String title) {
  final aliases = <String>{};
  void add(Object? value) {
    if (value is! String) return;
    final key = normalizeMcmodTitleKey(_mcmodBaseTitle(value));
    if (key.isNotEmpty && !_containsChinese(key)) aliases.add(key);
  }

  add(data['sub_name']);
  add(data['abbr']);
  add(RegExp(r'^\[([^\]]+)\]').firstMatch(title)?.group(1));
  add(RegExp(r'-\s*\[([^\]]+)\]').firstMatch(title)?.group(1));
  add(RegExp(r'[\(（]([^\)）]*)[\)）]\s*$').firstMatch(title)?.group(1));
  if (!_containsChinese(title)) add(title);
  return aliases;
}

/// Selects the best English match from an mcmod API search response.
///
/// The endpoint returns a JSON array. `data.sub_name` is normally the English
/// name and `title` may look like `钠 (Sodium)`. Matching is whitespace- and
/// punctuation-insensitive and also accepts a trailing platform qualifier, so
/// `Just Enough Items (JEI)` matches `JustEnoughItems`.
///
/// All English aliases in the response are returned, allowing the caller to
/// populate the local display cache beyond the title that was queried.
McmodTitleLookup? chineseTitleLookupFromApiResponse(String body, String query) {
  dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return null;
  }
  if (decoded is! List) return null;

  final fullQuery = _compactMcmodTitleKey(query);
  final baseQuery = _compactMcmodTitleKey(_mcmodBaseTitle(query));
  final fullQueryKey = normalizeMcmodTitleKey(query);
  final baseQueryKey = normalizeMcmodTitleKey(_mcmodBaseTitle(query));
  if (fullQuery.isEmpty && baseQuery.isEmpty) return null;

  final aliases = <String, String>{};
  McmodTitleLookup? exactMatch;
  McmodTitleLookup? baseMatch;
  for (final entry in decoded.whereType<Map>()) {
    final data = entry['data'];
    if (data is! Map) continue;
    final title = entry['title'] is String ? entry['title'] as String : '';
    final chinese = _mcmodEntryChinese(data, title);
    if (chinese == null) continue;

    final entryAliases = _mcmodEntryAliases(data, title);
    final compactAliases = entryAliases
        .map(_compactMcmodTitleKey)
        .where((alias) => alias.isNotEmpty)
        .toSet();
    for (final alias in entryAliases) {
      aliases.putIfAbsent(alias, () => chinese);
    }
    if (fullQuery.isNotEmpty && compactAliases.contains(fullQuery)) {
      exactMatch ??= McmodTitleLookup(chinese: chinese, aliases: const {});
    }
    if (baseQuery.isNotEmpty && compactAliases.contains(baseQuery)) {
      baseMatch ??= McmodTitleLookup(chinese: chinese, aliases: const {});
    }
  }

  final match = exactMatch ?? baseMatch;
  if (match == null) return null;
  if (fullQueryKey.isNotEmpty) aliases[fullQueryKey] = match.chinese;
  if (baseQueryKey.isNotEmpty) aliases[baseQueryKey] = match.chinese;
  return McmodTitleLookup(chinese: match.chinese, aliases: aliases);
}

/// Selects the exact English match from an mcmod API search response.
String? chineseTitleFromApiResponse(String body, String query) {
  return chineseTitleLookupFromApiResponse(body, query)?.chinese;
}

/// Small handwritten semaphore used to cap mcmod API requests.
class AsyncSemaphore {
  AsyncSemaphore(this.maxConcurrent);

  final int maxConcurrent;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  int _active = 0;

  Future<void> acquire() async {
    if (_active < maxConcurrent) {
      _active++;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    } else if (_active > 0) {
      _active--;
    }
  }

  Future<T> withPermit<T>(Future<T> Function() action) async {
    await acquire();
    try {
      return await action();
    } finally {
      release();
    }
  }
}

/// Caches English -> Chinese mod names in SQLite and fetches missing entries
/// from the unofficial mcmod API with at most two concurrent requests.
///
/// This service manages the persistent `mcmod_titles.sqlite` database in
/// `PathManager.dataDir`. It is not a disposable cache.
/// The Chinese -> project ID mapping used to resolve search queries lives in
/// `ModSearchService` and must not be written from here.
class McmodTitleService {
  McmodTitleService._();

  static final McmodTitleService instance = McmodTitleService._();

  static const String _tableName = 'mods';
  static const int _databaseVersion = 2;
  static const int _maxConcurrentRequests = 2;

  final Map<String, String> _cache = <String, String>{};
  final Map<String, Future<String>> _inFlight = <String, Future<String>>{};
  final AsyncSemaphore _semaphore = AsyncSemaphore(_maxConcurrentRequests);
  Database? _db;
  Future<void>? _initFuture;

  /// Opens the local cache. Safe to call multiple times; concurrent callers
  /// await the same initialization future.
  Future<void> init() => _initFuture ??= _openDatabase();

  Future<void> _openDatabase() async {
    final path = _databasePath();
    if (path == null) return;
    try {
      await PathManager.instance.migrateLegacyCacheDatabase(
        PathManager.mcmodTitleDatabaseName,
      );
      sqfliteFfiInit();
      await Directory(File(path).parent.path).create(recursive: true);
      final db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: _databaseVersion,
          onCreate: (database, version) => _createModsTable(database),
          onUpgrade: (database, oldVersion, newVersion) =>
              _createModsTable(database),
        ),
      );
      _db = db;
      // Also covers a database that existed before the `mods` table was added.
      await _createModsTable(db);
      final dirtyKeys = <String>[];
      final rows = await db.query(_tableName);
      for (final row in rows) {
        final english = row['english_name'];
        final chinese = row['chinese_name'];
        if (english is! String || chinese is! String) continue;
        final key = _cacheKey(english);
        if (key.isEmpty) continue;
        // Older builds stored whole mcmod wiki titles such as
        // `(物品/方块) Meka工具 (Meka-Tool) - [Mek] 通用机械`; clean them up and
        // drop rows that cannot be recovered.
        final cleaned = cleanChineseTitle(chinese);
        if (cleaned.isEmpty) {
          dirtyKeys.add(english);
          continue;
        }
        _cache[key] = cleaned;
      }
      if (dirtyKeys.isNotEmpty) {
        await _deleteStoredNames(db, dirtyKeys);
      }
      LauncherLog.info('McmodTitles', '已加载 ${_cache.length} 条中文模组名');
    } catch (error) {
      LauncherLog.warning('McmodTitles', '打开中文模组名数据库失败：$error');
    }
  }

  /// Removes scraped rows that must never be displayed again.
  Future<void> _deleteStoredNames(
    Database db,
    List<String> englishNames,
  ) async {
    try {
      final batch = db.batch();
      for (final name in englishNames) {
        batch.delete(_tableName, where: 'english_name = ?', whereArgs: [name]);
      }
      await batch.commit(noResult: true);
      LauncherLog.info(
        'McmodTitles',
        '已清理 ${englishNames.length} 条无效中文模组名',
      );
    } catch (error) {
      LauncherLog.warning('McmodTitles', '清理无效中文模组名失败：$error');
    }
  }

  Future<void> _createModsTable(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $_tableName ('
      'english_name TEXT PRIMARY KEY, '
      'chinese_name TEXT NOT NULL, '
      'updated_at INTEGER NOT NULL'
      ')',
    );
  }

  /// Returns a Chinese title already loaded in memory.
  ///
  /// This is the display database (English title -> Chinese title), not the
  /// Chinese -> project-ID mapping database used by search. Callers can use
  /// this synchronous lookup to render a cached title on the first frame
  /// instead of flashing the English name while SQLite is queried.
  String? cachedChineseTitle(String englishName) {
    final original = englishName.trim();
    if (original.isEmpty || _containsChinese(original)) return null;
    final key = _cacheKey(original);
    if (key.isEmpty) return null;
    final cached = _cache[key] ?? _cache[_compactMcmodTitleKey(original)];
    if (cached == null) return null;
    final cleaned = cleanChineseTitle(cached);
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Returns the translated name, or the original English name on cache miss
  /// plus failure. Cache lookup order is memory -> SQLite -> network.
  Future<String> translateAndCache(String englishName) async {
    final original = englishName.trim();
    if (original.isEmpty || _containsChinese(original)) return original;

    final key = _cacheKey(original);
    if (key.isEmpty) return original;
    final memoryValue = _cache[key] ?? _cache[_compactMcmodTitleKey(original)];
    if (memoryValue != null && memoryValue.trim().isNotEmpty) {
      final cleaned = cleanChineseTitle(memoryValue);
      if (cleaned.isNotEmpty) return cleaned;
      _cache.remove(key);
      _cache.remove(_compactMcmodTitleKey(original));
    }

    final cached = await _readFromDatabase(key);
    if (cached != null) return cached;

    final running = _inFlight[key];
    if (running != null) return running;

    final future = _translateAndCache(original, key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    }
  }

  Future<String?> _readFromDatabase(String key) async {
    await init();
    final memoryValue = _cache[key];
    if (memoryValue != null && memoryValue.trim().isNotEmpty) {
      return memoryValue;
    }
    final db = _db;
    if (db == null) return null;
    try {
      final rows = await db.query(
        _tableName,
        columns: const ['chinese_name'],
        where: 'english_name = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final chinese = rows.first['chinese_name'];
      final cleaned = chinese is String ? cleanChineseTitle(chinese) : '';
      if (cleaned.isEmpty) {
        // Legacy scraped row: drop it so it can never reach the UI.
        await _deleteStoredNames(db, [key]);
        return null;
      }
      _cache[key] = cleaned;
      return cleaned;
    } catch (error) {
      LauncherLog.warning('McmodTitles', '读取中文模组名缓存失败：$error');
      return null;
    }
  }

  Future<String> _translateAndCache(String englishName, String key) async {
    try {
      final lookup = await _semaphore.withPermit(
        () => _requestChinese(englishName),
      );
      final chinese = lookup == null ? '' : cleanChineseTitle(lookup.chinese);
      if (chinese.isNotEmpty) {
        final mappings = <String, String>{};
        for (final entry in (lookup?.aliases ?? const <String, String>{}).entries) {
          final cleaned = cleanChineseTitle(entry.value);
          if (cleaned.isNotEmpty) mappings[entry.key] = cleaned;
        }
        mappings[key] = chinese;
        _cache.addAll(mappings);
        await _writeMappingsToDatabase(mappings);
        return chinese;
      }
    } on Object catch (error) {
      LauncherLog.warning('McmodTitles', '翻译「$englishName」失败，保留英文名：$error');
    }
    return englishName;
  }

  Future<McmodTitleLookup?> _requestChinese(String englishName) async {
    final queries = <String>[englishName];
    final baseTitle = _mcmodBaseTitle(englishName);
    if (baseTitle.isNotEmpty && baseTitle != englishName) {
      queries.add(baseTitle);
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..userAgent = 'BlockLauncher/26.1alpha2.1 (mcmod title translation)';
    try {
      for (final query in queries) {
        final lookup = await _requestChineseQuery(client, query);
        if (lookup != null) return lookup;
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<McmodTitleLookup?> _requestChineseQuery(
    HttpClient client,
    String query,
  ) async {
    try {
      final encodedName = Uri.encodeComponent(query);
      final request = await client
          .getUrl(
            Uri.parse('https://$mcmodApiHost$mcmodApiEndpoint$encodedName'),
          )
          .timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 12));
      return chineseTitleLookupFromApiResponse(body, query);
    } on Object catch (error) {
      LauncherLog.warning('McmodTitles', '请求「$query」中文名失败：$error');
      return null;
    }
  }

  Future<void> _writeMappingsToDatabase(Map<String, String> mappings) async {
    final db = _db;
    if (db == null || mappings.isEmpty) return;
    try {
      final batch = db.batch();
      final updatedAt = DateTime.now().millisecondsSinceEpoch;
      for (final entry in mappings.entries) {
        final cleaned = cleanChineseTitle(entry.value);
        if (entry.key.isEmpty || cleaned.isEmpty) continue;
        batch.insert(_tableName, {
          'english_name': entry.key,
          'chinese_name': cleaned,
          'updated_at': updatedAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (error) {
      LauncherLog.warning('McmodTitles', '保存中文模组名失败：$error');
    }
  }

  String _cacheKey(String name) => normalizeMcmodTitleKey(name);

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initFuture = null;
  }

  String? _databasePath() {
    return PathManager.instance.mcmodTitleDatabaseFile?.path;
  }
}

/// Canonical English category keys -> Chinese display names.
///
/// The keys are normalized through [normalizeModTag], so both Modrinth's
/// `adventure` and CurseForge's `Adventure and RPG` resolve to `adventure`.
const Map<String, String> modTagTranslationSeed = {
  'adventure': '冒险',
  'rpg': 'RPG',
  'combat': '战斗',
  'technology': '科技',
  'magic': '魔法',
  'worldgen': '世界生成',
  'biomes': '生物群系',
  'dimensions': '维度',
  'mobs': '生物',
  'food': '食物',
  'equipment': '装备',
  'tools': '工具',
  'armor': '盔甲',
  'storage': '存储',
  'transportation': '运输',
  'decoration': '装饰',
  'structures': '结构',
  'optimization': '优化',
  'utility': '实用工具',
  'library': '前置库',
  'api': 'API',
  'configuration': '配置',
  'management': '管理',
  'miscellaneous': '杂项',
  'server': '服务器',
  'client': '客户端',
  'shaders': '光影',
  'resourcepacks': '资源包',
  'datapacks': '数据包',
  'mods': '模组',
  'game mechanics': '游戏机制',
  'economy': '经济',
  'quests': '任务',
  'minigame': '小游戏',
  'social': '社交',
  'cursed': '诅咒',
  'farming': '农业',
  'map': '地图',
  'information': '信息',
  'map information': '地图与信息',
  'adventure mode': '冒险模式',
  'anarchy': '无政府',
  'atmosphere': '氛围',
  'audio': '音频',
  'battle royale': '大逃杀',
  'bedwars': '起床战争',
  'blocks': '方块',
  'bloom': '泛光',
  'bosses': 'Boss',
  'cartoon': '卡通',
  'challenging': '高难度',
  'classes': '职业',
  'colored lighting': '彩色光照',
  'competitive': '竞技',
  'core shaders': '核心光影',
  'creative mode': '创造模式',
  'creator community': '创作者社区',
  'crossplay': '跨平台',
  'custom content': '自定义内容',
  'dungeons': '地牢',
  'entities': '实体',
  'environment': '环境',
  'factions': '阵营',
  'fantasy': '奇幻',
  'foliage': '植被',
  'fonts': '字体',
  'gens': '生成',
  'gui': '界面',
  'hardcore mode': '硬核模式',
  'items': '物品',
  'keep inventory': '保留物品',
  'kitchen sink': '整合包',
  'kitpvp': '职业 PVP',
  'lifesteal': '生命偷取',
  'lightweight': '轻量',
  'locale': '语言',
  'media': '媒体',
  'microgames': '小游戏',
  'mmo': 'MMO',
  'modded': '模组',
  'models': '模型',
  'multiplayer': '多人',
  'network': '网络',
  'offline mode': '离线模式',
  'oneblock': '单方块',
  'parkour': '跑酷',
  'path tracing': '路径追踪',
  'pbr': 'PBR',
  'personal worlds': '个人世界',
  'plots': '地皮',
  'pokemon': '宝可梦',
  'potato': '低配',
  'prison': '监狱',
  'pve': 'PVE',
  'pvp': 'PVP',
  'questing': '任务',
  'racing': '竞速',
  'realistic': '写实',
  'recording smp': '录制 SMP',
  'reflections': '反射',
  'roleplay': '角色扮演',
  'screenshot': '截图',
  'semi realistic': '半写实',
  'shadows': '阴影',
  'simplistic': '简约',
  'skyblock': '空岛',
  'smp': 'SMP',
  'survival mode': '生存模式',
  'teams': '队伍',
  'technical': '科技',
  'themed': '主题',
  'towns': '城镇',
  'tweaks': '调整',
  'vanilla like': '原版风',
  'whitelisted': '白名单',
  'world resets': '世界重置',
  'addons': '附属',
  'automation': '自动化',
  'blood magic': '血魔法',
  'bug fixes': 'Bug 修复',
  'buildcraft': '建筑',
  'cosmetic': '装饰',
  'crafttweaker': 'CraftTweaker',
  'create': '机械动力',
  'education': '教育',
  'energy': '能源',
  'energy fluid item transport': '能源、流体与物品运输',
  'forestry': '林业',
  'galacticraft': '星系',
  'genetics': '遗传学',
  'horror': '恐怖',
  'industrial craft': '工业时代',
  'integrated dynamics': '集成动力',
  'kubejs': 'KubeJS',
  'mcreator': 'MCreator',
  'modjam 2025': 'ModJam 2025',
  'ores and resources': '矿石与资源',
  'player transport': '玩家运输',
  'processing': '加工',
  'redstone': '红石',
  'refined storage': '精致存储',
  'server utility': '服务器实用工具',
  'thaumcraft': '神秘时代',
  'thermal expansion': '热力膨胀',
  'tinkers construct': '匠魂',
  'twilight forest': '暮色森林',
  'twitch integration': 'Twitch 集成',
  'utility qol': '实用工具与生活质量',
  'applied energistics 2': '应用能源 2',
  'farmers delight': '农夫乐事',
  'high': '高',
  'low': '低',
  'medium': '中',
  'op': 'OP',
};

const Map<String, String> _modTagAliases = {
  'adventure and rpg': 'adventure',
  'adventure rpg': 'adventure',
  'adventure and rpgs': 'adventure',
  'world gen': 'worldgen',
  'world generation': 'worldgen',
  'world-gen': 'worldgen',
  'api and library': 'library',
  'api library': 'library',
  'apis and libraries': 'library',
  'library and api': 'library',
  'data pack': 'datapacks',
  'data packs': 'datapacks',
  'resource pack': 'resourcepacks',
  'resource packs': 'resourcepacks',
  'resourcepack': 'resourcepacks',
  'shader': 'shaders',
  'performance': 'optimization',
  'utilities': 'utility',
  'tech': 'technology',
  'transport': 'transportation',
  'mob': 'mobs',
  'structure': 'structures',
  'biome': 'biomes',
  'dimension': 'dimensions',
  'foods': 'food',
  'decorations': 'decoration',
  'game-mechanics': 'game mechanics',
  'game mechanic': 'game mechanics',
  'game mechanics': 'game mechanics',
  'minigames': 'minigame',
  'map and information': 'map information',
  'maps and information': 'map information',
  'armor tools and weapons': 'equipment',
  'utility and qol': 'utility qol',
  'energy fluid and item transport': 'energy fluid item transport',
  'creativemode': 'creative mode',
};

/// Normalizes category spellings from both platforms.
///
/// Examples:
/// - `Adventure and RPG` -> `adventure`
/// - `adventure` -> `adventure`
/// - `World Generation` -> `worldgen`
String normalizeModTag(String tag) {
  var normalized = tag.trim().toLowerCase().replaceAll('&', ' and ');
  normalized = normalized.replaceAll(RegExp(r"['’]"), '');
  normalized = normalized
      .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  return _modTagAliases[normalized] ?? normalized;
}

String? knownModTagTranslation(String tag) {
  return modTagTranslationSeed[normalizeModTag(tag)];
}

/// Local SQLite-backed category translation cache.
///
/// The database is created in the launcher settings folder and seeded once.
/// Subsequent launches only need one small table read; the in-memory cache is
/// used for synchronous widget rendering.
class ModTagTranslationService {
  ModTagTranslationService._();

  static final ModTagTranslationService instance = ModTagTranslationService._();

  static const String _tableName = 'tag_translation';
  static const int _databaseVersion = 1;

  final Map<String, String> _cache = Map.of(modTagTranslationSeed);
  Database? _db;
  bool _initialized = false;

  /// Synchronous lookup used by the resource cards and detail page.
  String translate(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return tag;
    return _cache[normalizeModTag(trimmed)] ?? trimmed;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final path = _databasePath();
    if (path == null) return;
    try {
      await PathManager.instance.migrateLegacyCacheDatabase(
        PathManager.tagTranslationDatabaseName,
      );
      sqfliteFfiInit();
      final parent = Directory(File(path).parent.path);
      await parent.create(recursive: true);
      _db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: _databaseVersion,
          onCreate: (db, version) async {
            await db.execute(
              'CREATE TABLE $_tableName ('
              'normalized TEXT PRIMARY KEY, '
              'english TEXT NOT NULL, '
              'chinese TEXT NOT NULL, '
              'updated_at INTEGER NOT NULL'
              ')',
            );
          },
        ),
      );
      final batch = _db!.batch();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in modTagTranslationSeed.entries) {
        batch.insert(_tableName, {
          'normalized': entry.key,
          'english': entry.key,
          'chinese': entry.value,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
      final rows = await _db!.query(_tableName);
      for (final row in rows) {
        final normalized = row['normalized'];
        final chinese = row['chinese'];
        if (normalized is String && chinese is String) {
          _cache[normalized] = chinese;
        }
      }
      LauncherLog.info('ModTags', '已加载 ${_cache.length} 条本地标签翻译：$path');
    } catch (error) {
      LauncherLog.warning('ModTags', '打开本地标签翻译数据库失败：$error');
    }
  }

  /// Allows future downloaded tag dictionaries to extend the local cache.
  Future<void> saveTranslation(String english, String chinese) async {
    final normalized = normalizeModTag(english);
    if (normalized.isEmpty || chinese.trim().isEmpty) return;
    _cache[normalized] = chinese.trim();
    final db = _db;
    if (db == null) return;
    try {
      await db.insert(_tableName, {
        'normalized': normalized,
        'english': english.trim(),
        'chinese': chinese.trim(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (error) {
      LauncherLog.warning('ModTags', '保存标签翻译失败：$error');
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  String? _databasePath() {
    return PathManager.instance.tagTranslationDatabaseFile?.path;
  }
}
