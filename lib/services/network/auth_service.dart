import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Authentication modes exposed by the launcher UI and auth services.
enum AuthMode {
  offline('离线模式'),
  microsoft('Microsoft 正版'),
  thirdParty('第三方验证');

  const AuthMode(this.label);

  final String label;
}

/// Identity passed to [MinecraftLaunchService] when building launch arguments.
class AuthIdentity {
  const AuthIdentity({
    required this.name,
    required this.uuid,
    required this.accessToken,
    required this.userType,
    this.xuid = '',
    this.javaAgent,
  });

  final String name;
  final String uuid;
  final String accessToken;
  final String userType;
  final String xuid;
  final String? javaAgent;
}

/// Values collected by the generic launch setup dialog.
class AuthSetup {
  const AuthSetup({
    required this.first,
    required this.second,
    required this.third,
  });

  final String first;
  final String second;
  final String third;
}

/// Validated third-party Yggdrasil credentials.
class ThirdPartyAuthRequest {
  const ThirdPartyAuthRequest({
    required this.server,
    required this.username,
    required this.password,
  });

  final String server;
  final String username;
  final String password;
}

/// JSON HTTP client used by Minecraft authentication providers.
class AuthHttpClient {
  const AuthHttpClient();

  Future<Map<String, dynamic>> requestJson(
    Uri uri, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? form,
    String? bearerToken,
    bool acceptOAuthPending = false,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request =
          await (method == 'POST' ? client.postUrl(uri) : client.getUrl(uri))
              .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (bearerToken != null) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $bearerToken',
        );
      }
      if (form != null) {
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
        );
        request.write(Uri(queryParameters: form).query);
      } else if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('认证服务器返回了无效的 JSON 数据。');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (acceptOAuthPending && decoded['error'] is String) return decoded;
        final description =
            decoded['errorMessage'] ??
            decoded['error_description'] ??
            decoded['error'] ??
            'HTTP ${response.statusCode}';
        throw HttpException(
          'HTTP ${response.statusCode}：$description',
          uri: uri,
        );
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }
}

/// Persists deterministic offline player UUIDs per Minecraft directory.
class OfflineProfileStore {
  const OfflineProfileStore({required this.minecraftPath});

  final String minecraftPath;

  Future<String> uuidFor(String playerName) async {
    final profilesFile = File(
      '$minecraftPath${Platform.pathSeparator}launcher_offline_profiles.json',
    );
    final profiles = <String, dynamic>{};
    if (await profilesFile.exists()) {
      final decoded = jsonDecode(await profilesFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('本地档案配置文件格式无效。');
      }
      profiles.addAll(decoded);
    }
    final uuid = uuidForName(playerName);
    profiles[playerName] = uuid;
    await profilesFile.writeAsString(jsonEncode(profiles), flush: true);
    return uuid;
  }

  /// Generates the same offline UUID as Minecraft's `OfflinePlayer:<name>`.
  static String uuidForName(String playerName) {
    const mask = 0xffffffff;
    const shifts = [
      7,
      12,
      17,
      22,
      7,
      12,
      17,
      22,
      7,
      12,
      17,
      22,
      7,
      12,
      17,
      22,
      5,
      9,
      14,
      20,
      5,
      9,
      14,
      20,
      5,
      9,
      14,
      20,
      5,
      9,
      14,
      20,
      4,
      11,
      16,
      23,
      4,
      11,
      16,
      23,
      4,
      11,
      16,
      23,
      4,
      11,
      16,
      23,
      6,
      10,
      15,
      21,
      6,
      10,
      15,
      21,
      6,
      10,
      15,
      21,
      6,
      10,
      15,
      21,
    ];
    final message = <int>[...utf8.encode('OfflinePlayer:$playerName'), 0x80];
    while (message.length % 64 != 56) {
      message.add(0);
    }
    final bitLength = utf8.encode('OfflinePlayer:$playerName').length * 8;
    for (var index = 0; index < 8; index++) {
      message.add((bitLength >> (index * 8)) & 0xff);
    }

    var a0 = 0x67452301;
    var b0 = 0xefcdab89;
    var c0 = 0x98badcfe;
    var d0 = 0x10325476;
    final constants = List<int>.generate(
      64,
      (index) => (math.sin(index + 1).abs() * 4294967296).floor(),
      growable: false,
    );

    for (var offset = 0; offset < message.length; offset += 64) {
      final words = List<int>.generate(16, (wordIndex) {
        final start = offset + wordIndex * 4;
        return message[start] |
            (message[start + 1] << 8) |
            (message[start + 2] << 16) |
            (message[start + 3] << 24);
      }, growable: false);
      var a = a0;
      var b = b0;
      var c = c0;
      var d = d0;

      for (var index = 0; index < 64; index++) {
        late int function;
        late int wordIndex;
        if (index < 16) {
          function = (b & c) | (~b & d);
          wordIndex = index;
        } else if (index < 32) {
          function = (d & b) | (~d & c);
          wordIndex = (5 * index + 1) % 16;
        } else if (index < 48) {
          function = b ^ c ^ d;
          wordIndex = (3 * index + 5) % 16;
        } else {
          function = c ^ (b | ~d);
          wordIndex = (7 * index) % 16;
        }

        final sum = (a + function + constants[index] + words[wordIndex]) & mask;
        final shift = shifts[index];
        final rotated = ((sum << shift) | (sum >> (32 - shift))) & mask;
        final previousD = d;
        d = c;
        c = b;
        b = (b + rotated) & mask;
        a = previousD;
      }

      a0 = (a0 + a) & mask;
      b0 = (b0 + b) & mask;
      c0 = (c0 + c) & mask;
      d0 = (d0 + d) & mask;
    }

    final bytes = <int>[
      for (final word in [a0, b0, c0, d0])
        for (var index = 0; index < 4; index++) (word >> (index * 8)) & 0xff,
    ];
    bytes[6] = (bytes[6] & 0x0f) | 0x30;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

/// Offline and third-party (Yggdrasil) authentication flows.
class MinecraftAuthService {
  MinecraftAuthService({
    required this.minecraftPath,
    AuthHttpClient? httpClient,
    OfflineProfileStore? offlineProfileStore,
  }) : _httpClient = httpClient ?? const AuthHttpClient(),
       _offlineProfiles =
           offlineProfileStore ??
           OfflineProfileStore(minecraftPath: minecraftPath);

  final String minecraftPath;
  final AuthHttpClient _httpClient;
  final OfflineProfileStore _offlineProfiles;

  static final RegExp _playerNamePattern = RegExp(r'^[A-Za-z0-9_]{3,16}$');

  /// Resolves a local profile: the UUID is derived offline and the token is a
  /// placeholder, so this method never talks to Microsoft or Mojang services.
  Future<AuthIdentity> authenticateOffline(String playerName) async {
    final name = playerName.trim();
    if (!_playerNamePattern.hasMatch(name)) {
      throw const FormatException('本地档案名称必须为 3 至 16 位字母、数字或下划线。');
    }
    final uuid = await _offlineProfiles.uuidFor(name);
    return AuthIdentity(
      name: name,
      uuid: uuid,
      // Placeholder only: local profiles must never present a real session
      // token to Mojang APIs.
      accessToken: '0',
      userType: 'legacy',
    );
  }

  /// Validates the server/credentials before the UI picks authlib-injector.
  ThirdPartyAuthRequest prepareThirdPartyAuth({
    required String server,
    required String username,
    required String password,
  }) {
    final endpoint = Uri.tryParse(server.trim());
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment) {
      throw const FormatException('第三方认证服务器必须是有效的 HTTPS API 地址。');
    }
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw const FormatException('请输入第三方账号和密码。');
    }
    return ThirdPartyAuthRequest(
      server: endpoint.toString().replaceFirst(RegExp(r'/$'), ''),
      username: normalizedUsername,
      password: password,
    );
  }

  Future<AuthIdentity> authenticateThirdParty({
    required ThirdPartyAuthRequest request,
    required String agentPath,
  }) async {
    if (!await File(agentPath).exists()) {
      throw const FormatException('找不到所选 authlib-injector.jar 文件。');
    }
    final endpoint = Uri.parse(request.server);
    final authUri = endpoint.replace(
      path:
          '${endpoint.path.replaceFirst(RegExp(r'/$'), '')}/authserver/authenticate',
    );
    final response = await _httpClient.requestJson(
      authUri,
      method: 'POST',
      body: {
        'agent': {'name': 'Minecraft', 'version': 1},
        'username': request.username,
        'password': request.password,
        'requestUser': true,
      },
    );
    final selectedProfile = response['selectedProfile'];
    if (response['accessToken'] is! String ||
        selectedProfile is! Map<String, dynamic> ||
        selectedProfile['id'] is! String ||
        selectedProfile['name'] is! String) {
      throw const FormatException('认证服务未返回有效的 Minecraft 玩家档案。');
    }
    return AuthIdentity(
      name: selectedProfile['name'] as String,
      uuid: selectedProfile['id'] as String,
      accessToken: response['accessToken'] as String,
      userType: 'mojang',
      javaAgent: '$agentPath=${request.server}',
    );
  }
}

class MicrosoftDeviceCode {
  const MicrosoftDeviceCode({
    required this.userCode,
    required this.deviceCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  final String userCode;
  final String deviceCode;
  final String verificationUri;
  final int expiresIn;
  final int interval;
}

/// Legacy Microsoft OAuth device-code helper.
///
/// The UI signs in through `MicrosoftConnectService` (public client id), so this
/// class only remains for protocol-level reuse. It also falls back to the same
/// public id instead of asking the player for one.
class MicrosoftAuthService {
  const MicrosoftAuthService({AuthHttpClient? httpClient})
    : _httpClient = httpClient ?? const AuthHttpClient();

  static const String defaultClientId = 'fcb9776-0d60-4879-984b-bb833bd55152';

  final AuthHttpClient _httpClient;

  Future<MicrosoftDeviceCode> requestDeviceCode(String rawClientId) async {
    final trimmed = rawClientId.trim();
    final clientId = trimmed.isEmpty ? defaultClientId : trimmed;
    final deviceCode = await _httpClient.requestJson(
      Uri.https(
        'login.microsoftonline.com',
        '/consumers/oauth2/v2.0/devicecode',
      ),
      method: 'POST',
      form: {'client_id': clientId, 'scope': 'XboxLive.signin offline_access'},
    );
    final userCode = deviceCode['user_code'];
    final deviceCodeValue = deviceCode['device_code'];
    final verificationUri =
        deviceCode['verification_uri'] ?? deviceCode['verification_url'];
    if (userCode is! String ||
        deviceCodeValue is! String ||
        verificationUri is! String) {
      throw const FormatException('Microsoft 未返回有效的设备登录信息。');
    }
    return MicrosoftDeviceCode(
      userCode: userCode,
      deviceCode: deviceCodeValue,
      verificationUri: verificationUri,
      expiresIn: deviceCode['expires_in'] is int
          ? deviceCode['expires_in'] as int
          : 900,
      interval: deviceCode['interval'] is int
          ? math.max(5, deviceCode['interval'] as int)
          : 5,
    );
  }

  Future<AuthIdentity> completeDeviceCodeLogin({
    required String rawClientId,
    required MicrosoftDeviceCode deviceCode,
  }) async {
    final trimmed = rawClientId.trim();
    final clientId = trimmed.isEmpty ? defaultClientId : trimmed;
    final deadline = DateTime.now().add(
      Duration(seconds: deviceCode.expiresIn),
    );
    Map<String, dynamic>? microsoftToken;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(Duration(seconds: deviceCode.interval));
      final pollResponse = await _httpClient.requestJson(
        Uri.https('login.microsoftonline.com', '/consumers/oauth2/v2.0/token'),
        method: 'POST',
        form: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'client_id': clientId,
          'device_code': deviceCode.deviceCode,
        },
        acceptOAuthPending: true,
      );
      if (pollResponse['access_token'] is String) {
        microsoftToken = pollResponse;
        break;
      }
      final error = pollResponse['error'];
      if (error == 'authorization_pending') continue;
      if (error == 'slow_down') {
        await Future<void>.delayed(const Duration(seconds: 5));
        continue;
      }
      if (error == 'authorization_declined' || error == 'expired_token') {
        throw FormatException(
          error == 'expired_token'
              ? 'Microsoft 登录代码已过期，请重试。'
              : 'Microsoft 登录已取消。',
        );
      }
      throw FormatException(
        'Microsoft 登录失败：${pollResponse['error_description'] ?? error ?? '未知错误'}',
      );
    }
    if (microsoftToken == null) {
      throw const FormatException('Microsoft 登录超时，请重新开始。');
    }
    final xboxResponse = await _httpClient.requestJson(
      Uri.https('user.auth.xboxlive.com', '/user/authenticate'),
      method: 'POST',
      body: {
        'Properties': {
          'AuthMethod': 'RPS',
          'SiteName': 'user.auth.xboxlive.com',
          'RpsTicket': 'd=${microsoftToken['access_token']}',
        },
        'RelyingParty': 'http://auth.xboxlive.com',
        'TokenType': 'JWT',
      },
    );
    final xboxToken = xboxResponse['Token'];
    if (xboxToken is! String) {
      throw const FormatException('Xbox Live 未返回授权令牌。');
    }
    final xstsResponse = await _httpClient.requestJson(
      Uri.https('xsts.auth.xboxlive.com', '/xsts/authorize'),
      method: 'POST',
      body: {
        'Properties': {
          'SandboxId': 'RETAIL',
          'UserTokens': [xboxToken],
        },
        'RelyingParty': 'rp://api.minecraftservices.com/',
        'TokenType': 'JWT',
      },
    );
    final xstsToken = xstsResponse['Token'];
    final claims = xstsResponse['DisplayClaims'];
    final xui = claims is Map<String, dynamic> ? claims['xui'] : null;
    final xuiProfile = xui is List && xui.isNotEmpty && xui.first is Map
        ? xui.first as Map
        : null;
    final userHash = xuiProfile?['uhs'];
    final xuid = xuiProfile?['xid'];
    if (xstsToken is! String || userHash is! String) {
      throw const FormatException('Xbox XSTS 未返回有效的玩家授权信息。');
    }
    final minecraftResponse = await _httpClient.requestJson(
      Uri.https('api.minecraftservices.com', '/authentication/login_with_xbox'),
      method: 'POST',
      body: {
        'identityToken': 'XBL3.0 x=$userHash;$xstsToken',
        'ensureLegacyEnabled': true,
      },
    );
    final minecraftToken = minecraftResponse['access_token'];
    if (minecraftToken is! String) {
      throw const FormatException('Minecraft 服务未返回游戏访问令牌。');
    }
    final profile = await _httpClient.requestJson(
      Uri.https('api.minecraftservices.com', '/minecraft/profile'),
      bearerToken: minecraftToken,
    );
    if (profile['id'] is! String || profile['name'] is! String) {
      throw const FormatException('该 Microsoft 账号没有可用的 Minecraft Java 版档案。');
    }
    return AuthIdentity(
      name: profile['name'] as String,
      uuid: profile['id'] as String,
      accessToken: minecraftToken,
      userType: 'msa',
      xuid: xuid is String ? xuid : '',
    );
  }
}
