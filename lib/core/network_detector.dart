import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'launcher_log.dart';
import 'path_manager.dart';

enum RegionStatus { domestic, overseas, unknown }

class NetworkDetector {
  const NetworkDetector();

  static const Duration _timeout = Duration(seconds: 3);

  static final List<_RegionProbe> _probes = <_RegionProbe>[
    _RegionProbe(
      'https://api.ip.sb/geoip',
      (body) => _countryCodeFromJson(body, 'country_code'),
    ),
    _RegionProbe(
      'https://www.cloudflare.com/cdn-cgi/trace',
      _countryCodeFromTrace,
    ),
    _RegionProbe(
      'http://ip-api.com/json/?fields=countryCode',
      (body) => _countryCodeFromJson(body, 'countryCode'),
    ),
  ];

  /// Probes the region in order and stops at the first usable response.
  ///
  /// A response with a non-CN country code is still a valid result, so the
  /// remaining APIs are only tried when a request fails or its body cannot be
  /// parsed. If every probe fails, [RegionStatus.unknown] is returned.
  Future<RegionStatus> checkRegion() async {
    await _ensureLogging();

    final proxy = await _resolveSystemProxy();
    final proxyRule = proxy == null || proxy.isEmpty
        ? 'DIRECT'
        : 'PROXY $proxy';
    return HttpOverrides.runZoned(() async {
      final dio = Dio(
        BaseOptions(
          connectTimeout: _timeout,
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
          responseType: ResponseType.plain,
          headers: const <String, dynamic>{
            'Accept': 'application/json, text/plain, */*',
            'User-Agent': 'BlockLauncher/26.1alpha2.1 (network detector)',
          },
        ),
      );

      try {
        for (final probe in _probes) {
          LauncherLog.info(
            'NetworkDetector',
            '[NetworkDetector] 正在请求 API: ${probe.url}',
          );
          try {
            final response = await dio.get<String>(probe.url).timeout(_timeout);
            final body = response.data;
            if (body == null || body.trim().isEmpty) {
              LauncherLog.info(
                'NetworkDetector',
                '[NetworkDetector] API 返回内容为空，尝试下一个 API',
              );
              continue;
            }
            LauncherLog.info(
              'NetworkDetector',
              '[NetworkDetector] API 返回结果: $body',
            );
            final countryCode = probe.parseCountry(body)?.trim().toUpperCase();
            if (countryCode == null || countryCode.isEmpty) {
              LauncherLog.info(
                'NetworkDetector',
                '[NetworkDetector] 未能解析国家代码，尝试下一个 API',
              );
              continue;
            }
            LauncherLog.info(
              'NetworkDetector',
              '[NetworkDetector] 成功解析国家代码: $countryCode',
            );
            final status = countryCode == 'CN'
                ? RegionStatus.domestic
                : RegionStatus.overseas;
            LauncherLog.info(
              'NetworkDetector',
              '[NetworkDetector] 最终判定为: $status',
            );
            return status;
          } on Object catch (error) {
            LauncherLog.info(
              'NetworkDetector',
              '[NetworkDetector] 请求失败: $error',
            );
          }
        }
      } finally {
        dio.close(force: true);
      }

      LauncherLog.info(
        'NetworkDetector',
        '[NetworkDetector] 最终判定为: ${RegionStatus.unknown}',
      );
      return RegionStatus.unknown;
    }, createHttpClient: _ProxyHttpOverrides(proxyRule).createHttpClient);
  }
}

class _ProxyHttpOverrides extends HttpOverrides {
  _ProxyHttpOverrides(this.proxyRule);

  final String proxyRule;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (_) => proxyRule;
    return client;
  }
}

Future<void> _ensureLogging() async {
  if (LauncherLog.file != null) return;
  try {
    await PathManager.instance.load();
    await LauncherLog.initialize();
  } on Object {
    // Logging must never prevent region detection from completing.
  }
}

Future<String?> _resolveSystemProxy() async {
  _ProxyEndpoint? endpoint;
  String? rawProxy;

  try {
    if (Platform.isWindows) {
      endpoint = await _readWindowsSystemProxy();
    } else if (Platform.isMacOS) {
      rawProxy = _readMacProxyRaw();
    } else if (Platform.isLinux) {
      rawProxy = _readEnvironmentProxyRaw();
    }
  } on Object catch (error) {
    LauncherLog.warning(
      'NetworkDetector',
      '[NetworkDetector] 平台 $_platformName 系统代理读取失败: $error',
    );
  }

  // 通用兜底：系统级读取失败时，尝试 Dart 环境变量。
  rawProxy ??= _readEnvironmentProxyRaw();

  if (endpoint == null && rawProxy != null) {
    endpoint = _parseProxyEndpoint(rawProxy);
    if (endpoint == null && !_looksLikeSocksProxy(rawProxy)) {
      final fallback = _readEnvironmentProxyRaw();
      if (fallback != null && fallback != rawProxy) {
        endpoint = _parseProxyEndpoint(fallback);
      }
    }
  }

  final proxy = endpoint?.authority;
  if (proxy == null) {
    LauncherLog.info(
      'NetworkDetector',
      '[NetworkDetector] 平台 $_platformName 未检测到代理',
    );
    return null;
  }

  LauncherLog.info(
    'NetworkDetector',
    '[NetworkDetector] 平台 $_platformName 检测到代理: $proxy',
  );
  return proxy;
}

String? _readMacProxyRaw() {
  try {
    final result = Process.runSync('scutil', <String>['--proxy']);
    if (result.exitCode != 0) {
      LauncherLog.warning(
        'NetworkDetector',
        '[NetworkDetector] macOS scutil 代理读取失败 '
            '(exit ${result.exitCode}): ${result.stderr}',
      );
      return null;
    }

    final output = result.stdout.toString();
    final enabled = RegExp(r'HTTPSEnable\s*:\s*1\b').hasMatch(output);
    if (!enabled) return null;

    final host = RegExp(r'HTTPSProxy\s*:\s*(\S+)')
        .firstMatch(output)
        ?.group(1)
        ?.trim();
    final port = int.tryParse(
      RegExp(r'HTTPSPort\s*:\s*(\d{1,5})').firstMatch(output)?.group(1) ?? '',
    );

    if (host == null ||
        host.isEmpty ||
        host == '(null)' ||
        port == null ||
        port <= 0 ||
        port > 65535) {
      return null;
    }

    return _ProxyEndpoint(host, port).authority;
  } on Object catch (error) {
    LauncherLog.warning(
      'NetworkDetector',
      '[NetworkDetector] macOS scutil 代理读取异常: $error',
    );
    return null;
  }
}

String? _readEnvironmentProxyRaw() {
  const keys = <String>[
    'https_proxy',
    'HTTPS_PROXY',
    'http_proxy',
    'HTTP_PROXY',
    'all_proxy',
    'ALL_PROXY',
  ];

  for (final key in keys) {
    final value = Platform.environment[key];
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

bool _looksLikeSocksProxy(String raw) => raw.toLowerCase().contains('socks');

void _logSocksProxyWarning() {
  LauncherLog.warning(
    'NetworkDetector',
    '[NetworkDetector] 检测到 SOCKS 代理，但 Dart 原生 HttpClient '
        '仅支持 HTTP/HTTPS 代理。将尝试降级或直连。',
  );
}

String get _platformName {
  if (Platform.isWindows) return 'Windows';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isLinux) return 'Linux';
  return Platform.operatingSystem;
}

class _ProxyEndpoint {
  const _ProxyEndpoint(this.host, this.port);

  final String host;
  final int port;

  String get authority => host.contains(':') ? '[$host]:$port' : '$host:$port';
}

Future<_ProxyEndpoint?> _readWindowsSystemProxy() async {
  if (!Platform.isWindows) {
    LauncherLog.info(
      'NetworkDetector',
      '[NetworkDetector] 当前平台不使用 Windows 注册表代理，使用 DIRECT 直连',
    );
    return null;
  }

  const command =
      "Get-ItemProperty 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings' | Select-Object ProxyEnable, ProxyServer | ConvertTo-Json -Compress";
  try {
    final result = await Process.run('powershell.exe', <String>[
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      command,
    ], runInShell: false).timeout(const Duration(seconds: 3));

    if (result.exitCode != 0) {
      LauncherLog.warning(
        'NetworkDetector',
        '[NetworkDetector] 读取注册表代理失败 '
            '(exit ${result.exitCode}): ${result.stderr}',
      );
      return null;
    }

    final rawOutput = result.stdout.toString().trim();
    if (rawOutput.isEmpty || rawOutput.toLowerCase() == 'null') {
      LauncherLog.info(
        'NetworkDetector',
        '[NetworkDetector] 注册表未返回代理配置，使用 DIRECT 直连',
      );
      return null;
    }

    final decoded = jsonDecode(rawOutput.replaceFirst('\uFEFF', ''));
    if (decoded is! Map) {
      LauncherLog.warning(
        'NetworkDetector',
        '[NetworkDetector] 注册表代理响应不是 JSON 对象，使用 DIRECT 直连: '
            '$rawOutput',
      );
      return null;
    }

    final enableRaw = decoded['ProxyEnable'];
    final proxyEnabled =
        enableRaw == true ||
        enableRaw == 1 ||
        enableRaw?.toString().trim() == '1';
    if (!proxyEnabled) {
      LauncherLog.info(
        'NetworkDetector',
        '[NetworkDetector] 注册表显示系统代理未启用，使用 DIRECT 直连',
      );
      return null;
    }

    final proxyServer = decoded['ProxyServer'];
    if (proxyServer is! String || proxyServer.trim().isEmpty) {
      LauncherLog.warning(
        'NetworkDetector',
        '[NetworkDetector] 系统代理已启用但 ProxyServer 为空，使用 DIRECT 直连',
      );
      return null;
    }

    final endpoint = _parseProxyEndpoint(proxyServer);
    if (endpoint == null) {
      LauncherLog.warning(
        'NetworkDetector',
        '[NetworkDetector] 无法解析 ProxyServer="$proxyServer"，使用 DIRECT 直连',
      );
      return null;
    }

    return endpoint;
  } on Object catch (error) {
    LauncherLog.warning(
      'NetworkDetector',
      '[NetworkDetector] 读取系统代理失败，回退 DIRECT 直连: $error',
    );
    return null;
  }
}

_ProxyEndpoint? _parseProxyEndpoint(String raw) {
  final parts = raw
      .split(';')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return null;

  String? selected;
  for (final protocol in const <String>['https', 'http']) {
    for (final part in parts) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      if (part.substring(0, separator).trim().toLowerCase() != protocol) {
        continue;
      }
      final candidate = part.substring(separator + 1).trim();
      if (candidate.isEmpty) continue;
      selected = candidate;
      break;
    }
    if (selected != null) break;
  }

  if (selected == null) {
    for (final part in parts) {
      if (part.toLowerCase().startsWith('socks')) {
        _logSocksProxyWarning();
        return null;
      }
    }
  }

  var value = (selected ?? parts.first).trim();
  final separator = value.indexOf('=');
  if (separator > 0 && !value.contains('://')) {
    final key = value.substring(0, separator).trim().toLowerCase();
    if (key == 'http' ||
        key == 'https' ||
        key == 'socks' ||
        key == 'socks5' ||
        key == 'all_proxy' ||
        key == 'ftp') {
      if (key.startsWith('socks')) {
        _logSocksProxyWarning();
        return null;
      }
      value = value.substring(separator + 1).trim();
    }
  }
  if (value.toLowerCase().startsWith('socks')) {
    _logSocksProxyWarning();
    return null;
  }
  value = value.replaceFirst(RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://'), '');
  final slash = value.indexOf('/');
  if (slash >= 0) value = value.substring(0, slash);
  if (value.isEmpty) return null;

  final uri = Uri.tryParse('http://$value');
  if (uri != null && uri.host.isNotEmpty && uri.hasPort) {
    final port = uri.port;
    if (port > 0 && port <= 65535) {
      return _ProxyEndpoint(uri.host, port);
    }
  }

  final ipv6 = RegExp(r'^\[([0-9A-Fa-f:]+)\]:(\d{1,5})$').firstMatch(value);
  final simple = RegExp(r'^([^\s:]+):(\d{1,5})$').firstMatch(value);
  final match = ipv6 ?? simple;
  if (match == null) return null;
  final port = int.tryParse(match.group(2)!);
  if (port == null || port <= 0 || port > 65535) return null;
  return _ProxyEndpoint(match.group(1)!, port);
}

class _RegionProbe {
  const _RegionProbe(this.url, this.parseCountry);

  final String url;
  final String? Function(String body) parseCountry;
}

String? _countryCodeFromJson(String body, String key) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final value = decoded[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
  } on Object {
    return null;
  }
  return null;
}

String? _countryCodeFromTrace(String body) {
  for (final line in body.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('loc=')) continue;
    final value = trimmed.substring(4).trim();
    if (value.isNotEmpty) return value;
  }
  return null;
}
