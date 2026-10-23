import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pool/pool.dart';

import '../../core/launcher_log.dart';
import '../../core/path_utils.dart';

/// One server saved in a client's `servers.dat`.
class ServerEntry {
  const ServerEntry({
    required this.name,
    required this.ip,
    required this.port,
    this.ping = -1,
    this.isOnline = false,
  });

  final String name;
  final String ip;
  final int port;

  /// Measured TCP handshake time in milliseconds (`-1` before the first ping).
  final int ping;
  final bool isOnline;

  String get address => '$ip:$port';

  ServerEntry copyWith({int? ping, bool? isOnline}) {
    return ServerEntry(
      name: name,
      ip: ip,
      port: port,
      ping: ping ?? this.ping,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

/// Parses `servers.dat` and measures server latency.
///
/// Minecraft stores the list as gzip-compressed NBT. Pulling in a full NBT
/// reader for two string tags is overkill, so the payload is inflated with
/// `dart:io`'s gzip codec, decoded as text (UTF-8, UTF-16 and Latin-1 are all
/// attempted) and reduced to `name` / `ip` pairs by token scanning.
class ServerService {
  const ServerService._();

  static const int defaultPort = 25565;
  static const Duration defaultTimeout = Duration(seconds: 2);
  static const int defaultConcurrency = 5;

  /// Reads and parses `<clientDirectory>/servers.dat`.
  static Future<List<ServerEntry>> readServers(String clientDirectory) async {
    final directory = clientDirectory.trim();
    if (directory.isEmpty) return const <ServerEntry>[];
    final file = File(joinPath(directory, 'servers.dat'));
    if (!await file.exists()) {
      LauncherLog.info('Servers', '未找到 servers.dat：${file.path}');
      return const <ServerEntry>[];
    }
    final servers = parseServersDat(await file.readAsBytes());
    LauncherLog.info('Servers', '已从 servers.dat 解析 ${servers.length} 个服务器');
    return servers;
  }

  /// Parses gzip or plain NBT bytes into [ServerEntry] values.
  static List<ServerEntry> parseServersDat(Uint8List bytes) {
    if (bytes.isEmpty) return const <ServerEntry>[];
    final payload = _inflate(bytes);
    for (final text in _decodeCandidates(payload)) {
      final servers = _extractServers(text);
      if (servers.isNotEmpty) return servers;
    }
    return const <ServerEntry>[];
  }

  /// Splits `host`, `host:port` and `[ipv6]:port` into address and port.
  static ({String ip, int port})? parseAddress(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.length > 300) return null;
    if (value.startsWith('[')) {
      final end = value.indexOf(']');
      if (end <= 1) return null;
      final host = value.substring(1, end);
      final rest = value.substring(end + 1);
      final port = rest.startsWith(':')
          ? int.tryParse(rest.substring(1))
          : defaultPort;
      if (port == null || port <= 0 || port > 65535) return null;
      return (ip: host, port: port);
    }
    final separator = value.lastIndexOf(':');
    if (separator < 0) {
      return _isValidHost(value) ? (ip: value, port: defaultPort) : null;
    }
    final host = value.substring(0, separator).trim();
    final port = int.tryParse(value.substring(separator + 1).trim());
    if (port == null || port <= 0 || port > 65535) return null;
    if (!_isValidHost(host)) return null;
    return (ip: host, port: port);
  }

  /// Measures the TCP handshake time. Failures mark the server offline.
  static Future<ServerEntry> pingServer(
    ServerEntry server, {
    Duration timeout = defaultTimeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(server.ip, server.port, timeout: timeout);
      stopwatch.stop();
      return server.copyWith(
        ping: stopwatch.elapsedMilliseconds,
        isOnline: true,
      );
    } on Object catch (error) {
      stopwatch.stop();
      LauncherLog.warning('Servers', '服务器连接失败：${server.address}（$error）');
      return server.copyWith(
        ping: timeout.inMilliseconds,
        isOnline: false,
      );
    } finally {
      socket?.destroy();
    }
  }

  /// Pings every server, limiting the number of sockets opened at once.
  static Future<List<ServerEntry>> pingAll(
    List<ServerEntry> servers, {
    int concurrency = defaultConcurrency,
    Duration timeout = defaultTimeout,
  }) async {
    if (servers.isEmpty) return const <ServerEntry>[];
    final pool = Pool(concurrency < 1 ? 1 : concurrency);
    final results = List<ServerEntry?>.filled(servers.length, null);
    try {
      await Future.wait(
        servers.asMap().entries.map((entry) async {
          results[entry.key] = await pool.withResource(
            () => pingServer(entry.value, timeout: timeout),
          );
        }),
      );
    } finally {
      await pool.close();
    }
    return results.whereType<ServerEntry>().toList();
  }

  /// Older worlds are gzip-compressed; newer ones may be stored plainly.
  static Uint8List _inflate(Uint8List bytes) {
    if (bytes.length > 2 && bytes[0] == 0x1F && bytes[1] == 0x8B) {
      try {
        return Uint8List.fromList(gzip.decode(bytes));
      } on Object catch (error) {
        LauncherLog.warning('Servers', 'servers.dat 解压失败：$error');
      }
    }
    return bytes;
  }

  /// NBT strings were UTF-16 before 1.13 and UTF-8 afterwards, so every
  /// plausible decoding is tried until one yields server entries.
  static List<String> _decodeCandidates(Uint8List bytes) {
    final candidates = <String>[utf8.decode(bytes, allowMalformed: true)];
    if (_looksLikeUtf16(bytes)) {
      candidates.add(
        String.fromCharCodes(_utf16Units(bytes, littleEndian: true)),
      );
      candidates.add(
        String.fromCharCodes(_utf16Units(bytes, littleEndian: false)),
      );
    }
    candidates.add(latin1.decode(bytes, allowInvalid: true));
    return candidates;
  }

  static bool _looksLikeUtf16(Uint8List bytes) {
    final limit = bytes.length < 512 ? bytes.length : 512;
    if (limit < 8) return false;
    var zeroBytes = 0;
    for (var index = 0; index < limit; index++) {
      if (bytes[index] == 0) zeroBytes++;
    }
    return zeroBytes > limit ~/ 4;
  }

  static List<int> _utf16Units(Uint8List bytes, {required bool littleEndian}) {
    final units = <int>[];
    for (var index = 0; index + 1 < bytes.length; index += 2) {
      units.add(
        littleEndian
            ? bytes[index] | (bytes[index + 1] << 8)
            : (bytes[index] << 8) | bytes[index + 1],
      );
    }
    return units;
  }

  static final RegExp _textToken = RegExp(r'[\x20-\x7E\u00A0-\uFFFF]{1,512}');
  static final RegExp _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
  static final RegExp _hostname = RegExp(
    r'^[A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?$',
  );

  static bool _isValidHost(String host) {
    if (host.isEmpty || host.length > 253) return false;
    if (_ipv4.hasMatch(host)) return true;
    return _hostname.hasMatch(host) && !host.contains('..');
  }

  /// NBT stores `TAG_String "name" <value>` and `TAG_String "ip" <value>`.
  /// Extracting printable tokens drops the binary length prefixes, then each
  /// address is paired with the closest `name` value (order independent).
  static List<ServerEntry> _extractServers(String text) {
    final tokens = _textToken
        .allMatches(text)
        .map((match) => match.group(0)!.trim())
        .toList();
    if (tokens.length < 3) return const <ServerEntry>[];
    final names = <int, String>{};
    final addresses = <int, String>{};
    for (var index = 0; index < tokens.length - 1; index++) {
      if (tokens[index] == 'name') names[index + 1] = tokens[index + 1];
      if (tokens[index] == 'ip') addresses[index + 1] = tokens[index + 1];
    }
    final servers = <ServerEntry>[];
    final usedNameIndexes = <int>{};
    final seenAddresses = <String>{};
    for (final address in addresses.entries) {
      final parsed = parseAddress(address.value);
      if (parsed == null) continue;
      if (!seenAddresses.add('${parsed.ip}:${parsed.port}')) continue;
      var bestIndex = -1;
      var bestDistance = 5;
      for (final name in names.entries) {
        if (usedNameIndexes.contains(name.key)) continue;
        final distance = (name.key - address.key).abs();
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = name.key;
        }
      }
      if (bestIndex >= 0) usedNameIndexes.add(bestIndex);
      final name = bestIndex >= 0 ? names[bestIndex]!.trim() : '';
      servers.add(
        ServerEntry(
          name: name.isEmpty ? parsed.ip : name,
          ip: parsed.ip,
          port: parsed.port,
        ),
      );
    }
    return servers;
  }
}
