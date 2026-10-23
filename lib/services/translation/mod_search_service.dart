import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/launcher_log.dart';
import '../../core/path_manager.dart';
import '../../core/path_utils.dart';

/// 中文模组名 → 英文标识符（Modrinth ID）查询服务。
///
/// 依赖本机 SQLite 数据库（Windows 桌面端使用 sqflite_common_ffi，而非仅限
/// 移动端的 sqflite）。数据库存储了模组的中英文映射数据。
///
/// ⚠️ 表结构已探索确认（如与实际数据库不符，请修改下方常量）：
///   表名:   project
///   列:
///     - curseforgeId  INTEGER  （CurseForge 模组 ID）
///     - modrinthId    TEXT     （Modrinth 英文标识符 / ID）
///     - name          TEXT     （中文名）
///     - description   TEXT     （中文描述）
class ModSearchService {
  ModSearchService._();

  static final ModSearchService instance = ModSearchService._();

  /// 数据库文件名；运行时位于 `BGCL/data` 目录，避免泄露开发机路径。
  static const String databaseFileName = 'zh-cn.sqlite';

  /// 随启动器打包的中英文映射字典。
  static const String databaseAssetKey = 'assets/data/zh-cn.sqlite';

  /// 数据库绝对路径；启动器数据目录尚未配置时为 `null`。
  static String? get databasePath {
    final dataDir = PathManager.instance.dataDir;
    if (dataDir == null || dataDir.trim().isEmpty) return null;
    return joinPath(dataDir, databaseFileName);
  }

  /// 首次运行时把内置字典释放到 `BGCL/data`，之后不再覆盖。
  ///
  /// 已存在的文件可能是玩家积累的增量翻译，因此只在文件缺失或为空时写入。
  /// [dataDirectory] 仅用于测试注入；生产环境始终使用 PathManager。
  Future<String?> ensureDatabaseExtracted({String? dataDirectory}) async {
    final dataDir =
        (dataDirectory ?? PathManager.instance.dataDir)?.trim() ?? '';
    if (dataDir.isEmpty) {
      LauncherLog.warning('ModSearch', '启动器数据目录未配置，跳过内置字典释放。');
      return null;
    }
    final file = File(joinPath(dataDir, databaseFileName));
    try {
      if (await file.exists() && await file.length() > 0) {
        return file.path;
      }
      final data = await rootBundle.load(databaseAssetKey);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      LauncherLog.info('ModSearch', '已释放内置中文映射字典：$databaseFileName');
      return file.path;
    } on Object catch (error) {
      LauncherLog.warning('ModSearch', '释放内置中文映射字典失败：$error');
      return null;
    }
  }

  /// ⚠️ 如果表名/列名与实际情况不同，只需修改下面这几个常量。
  static const String tableName = 'project';
  static const String chineseNameColumn = 'name';
  static const String englishIdColumn = 'modrinthId';
  static const String curseForgeIdColumn = 'curseforgeId';
  static const String descriptionColumn = 'description';

  Database? _db;

  /// 初始化 SQLite FFI 并连接到数据库，保持连接。
  ///
  /// Windows 桌面端必须使用 sqflite_common_ffi（内部会调用 sqfliteFfiInit()）。
  Future<void> initDatabase() async {
    // Release the bundled dictionary first so the connection has a file.
    final released = await ensureDatabaseExtracted();
    final path = released ?? databasePath;
    if (path == null) {
      _db = null;
      LauncherLog.warning('ModSearch', '启动器数据目录未配置，跳过中文映射数据库。');
      return;
    }
    try {
      if (!await File(path).exists()) {
        _db = null;
        LauncherLog.info(
          'ModSearch',
          '未找到中文映射数据库 $databaseFileName，中文搜索将回退到在线查询。',
        );
        return;
      }
      sqfliteFfiInit();
      // Opened read-write so player-collected translations can be appended.
      _db = await databaseFactoryFfi.openDatabase(path);
      LauncherLog.info('ModSearch', '已打开中文映射数据库：$databaseFileName');
    } catch (error) {
      _db = null;
      LauncherLog.warning('ModSearch', '打开中文映射数据库失败：$error');
    }
  }

  /// 探索表结构（调试用），打印所有表和列名。
  Future<void> exploreSchema() async {
    final db = _db;
    if (db == null) return;
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      for (final table in tables) {
        final name = table['name'];
        final columns = await db.rawQuery('PRAGMA table_info($name)');
        LauncherLog.info(
          'ModSearch',
          '表 $name 的列：${columns.map((c) => c['name']).toList()}',
        );
      }
    } catch (error) {
      LauncherLog.warning('ModSearch', '探索表结构失败：$error');
    }
  }

  /// 根据中文名模糊搜索对应的英文标识符（Modrinth ID）。
  ///
  /// 命中则返回英文标识符（如 slug/ID），未命中返回 null，方便调用方做纯
  /// 英文搜索的兜底逻辑。
  Future<String?> searchChineseToEnglish(String query) async {
    final ids = await searchChineseToEnglishIds(query, limit: 1);
    return ids.isEmpty ? null : ids.first;
  }

  /// 返回所有与中文关键词匹配的英文标识符（去重，按相关度排序）。
  ///
  /// 中文名精确匹配排最前，其次中文名模糊匹配，最后描述模糊匹配。
  Future<List<String>> searchChineseToEnglishIds(
    String query, {
    int limit = 12,
  }) async {
    final db = _db;
    if (db == null) return const [];

    final keyword = query.trim();
    if (keyword.isEmpty) return const [];

    try {
      final ids = <String>[];

      // 1) 中文名精确匹配。
      final exact = await db.rawQuery(
        'SELECT $englishIdColumn FROM $tableName '
        'WHERE $chineseNameColumn = ? '
        "AND $englishIdColumn IS NOT NULL AND $englishIdColumn != ''",
        [keyword],
      );
      _appendIds(ids, exact, limit);
      if (ids.length >= limit) return ids;

      // 2) 中文名模糊匹配（LIKE）。
      final nameRows = await db.rawQuery(
        'SELECT $englishIdColumn FROM $tableName '
        'WHERE $chineseNameColumn LIKE ? '
        "AND $englishIdColumn IS NOT NULL AND $englishIdColumn != ''",
        ['%$keyword%'],
      );
      _appendIds(ids, nameRows, limit);
      if (ids.length >= limit) return ids;

      // 3) 描述模糊匹配（LIKE）。
      final descRows = await db.rawQuery(
        'SELECT $englishIdColumn FROM $tableName '
        'WHERE $descriptionColumn LIKE ? '
        "AND $englishIdColumn IS NOT NULL AND $englishIdColumn != ''",
        ['%$keyword%'],
      );
      _appendIds(ids, descRows, limit);
      return ids;
    } catch (error) {
      LauncherLog.warning('ModSearch', '中文到 Modrinth ID 查询失败：$error');
      return const [];
    }
  }

  /// 返回所有与中文关键词匹配的 CurseForge 模组 ID（去重，按相关度排序）。
  ///
  /// 与 [searchChineseToEnglishIds] 使用同一张中文映射表，读取
  /// `curseforgeId` 列，供 CurseForge 搜索使用。
  Future<List<int>> searchChineseToCurseForgeIds(
    String query, {
    int limit = 12,
  }) async {
    final db = _db;
    if (db == null) return const [];

    final keyword = query.trim();
    if (keyword.isEmpty) return const [];

    try {
      final ids = <int>[];

      // 1) 中文名精确匹配。
      final exact = await db.rawQuery(
        'SELECT $curseForgeIdColumn FROM $tableName '
        'WHERE $chineseNameColumn = ? '
        "AND $curseForgeIdColumn IS NOT NULL AND $curseForgeIdColumn > 0",
        [keyword],
      );
      _appendCurseForgeIds(ids, exact, limit);
      if (ids.length >= limit) return ids;

      // 2) 中文名模糊匹配（LIKE）。
      final nameRows = await db.rawQuery(
        'SELECT $curseForgeIdColumn FROM $tableName '
        'WHERE $chineseNameColumn LIKE ? '
        "AND $curseForgeIdColumn IS NOT NULL AND $curseForgeIdColumn > 0",
        ['%$keyword%'],
      );
      _appendCurseForgeIds(ids, nameRows, limit);
      if (ids.length >= limit) return ids;

      // 3) 描述模糊匹配（LIKE）。
      final descRows = await db.rawQuery(
        'SELECT $curseForgeIdColumn FROM $tableName '
        'WHERE $descriptionColumn LIKE ? '
        "AND $curseForgeIdColumn IS NOT NULL AND $curseForgeIdColumn > 0",
        ['%$keyword%'],
      );
      _appendCurseForgeIds(ids, descRows, limit);
      return ids;
    } catch (error) {
      LauncherLog.warning('ModSearch', '中文到 CurseForge ID 查询失败：$error');
      return const [];
    }
  }

  void _appendCurseForgeIds(
    List<int> ids,
    List<Map<String, Object?>> rows,
    int limit,
  ) {
    for (final row in rows) {
      final value = row[curseForgeIdColumn];
      final id = value is int
          ? value
          : value is num
          ? value.toInt()
          : null;
      if (id != null && id > 0 && !ids.contains(id)) {
        ids.add(id);
        if (ids.length >= limit) break;
      }
    }
  }

  void _appendIds(
    List<String> ids,
    List<Map<String, Object?>> rows,
    int limit,
  ) {
    for (final row in rows) {
      final id = row[englishIdColumn];
      if (id is String && id.isNotEmpty && !ids.contains(id)) {
        ids.add(id);
        if (ids.length >= limit) break;
      }
    }
  }

  /// 关闭数据库连接。
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
