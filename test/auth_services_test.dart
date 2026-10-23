import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:baogan_craft_launcher/services/network/auth_service.dart';

void main() {
  test('offline UUID is deterministic and has UUID v3 format', () {
    final first = OfflineProfileStore.uuidForName('TestPlayer');
    final second = OfflineProfileStore.uuidForName('TestPlayer');
    expect(first, second);
    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-3[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('offline authentication validates names and persists UUID', () async {
    final directory = await Directory.systemTemp.createTemp('launcher_auth_');
    addTearDown(() => directory.delete(recursive: true));
    final service = MinecraftAuthService(minecraftPath: directory.path);

    final identity = await service.authenticateOffline('TestPlayer');
    expect(identity.name, 'TestPlayer');
    expect(identity.accessToken, '0');
    expect(identity.userType, 'legacy');
    expect(identity.uuid, OfflineProfileStore.uuidForName('TestPlayer'));

    final profiles = File(
      '${directory.path}${Platform.pathSeparator}'
      'launcher_offline_profiles.json',
    );
    expect(await profiles.exists(), isTrue);
    expect(await profiles.readAsString(), contains('TestPlayer'));

    await expectLater(
      service.authenticateOffline('bad name'),
      throwsA(isA<FormatException>()),
    );
  });

  test('third-party setup validates and normalizes the API endpoint', () {
    final service = MinecraftAuthService(minecraftPath: '');

    final request = service.prepareThirdPartyAuth(
      server: 'https://littleskin.cn/api/yggdrasil/',
      username: ' player@example.com ',
      password: 'secret',
    );
    expect(request.server, 'https://littleskin.cn/api/yggdrasil');
    expect(request.username, 'player@example.com');
    expect(request.password, 'secret');

    for (final invalid in <String>[
      'http://littleskin.cn/api/yggdrasil',
      'https://littleskin.cn/api/yggdrasil?token=1',
      'https://littleskin.cn/api/yggdrasil#fragment',
      '',
    ]) {
      expect(
        () => service.prepareThirdPartyAuth(
          server: invalid,
          username: 'player',
          password: 'secret',
        ),
        throwsA(isA<FormatException>()),
      );
    }
    expect(
      () => service.prepareThirdPartyAuth(
        server: 'https://littleskin.cn/api/yggdrasil',
        username: ' ',
        password: '',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('third-party auth rejects a missing authlib-injector', () async {
    final service = MinecraftAuthService(minecraftPath: '');
    await expectLater(
      service.authenticateThirdParty(
        request: const ThirdPartyAuthRequest(
          server: 'https://example.com',
          username: 'player',
          password: 'secret',
        ),
        agentPath: 'missing-authlib-injector.jar',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('auth mode labels remain stable for persisted names', () {
    expect(AuthMode.offline.name, 'offline');
    expect(AuthMode.offline.label, '离线模式');
    expect(AuthMode.microsoft.name, 'microsoft');
    expect(AuthMode.thirdParty.name, 'thirdParty');
  });

  test('local profile login stays offline and never reuses a real token', () async {
    final directory = await Directory.systemTemp.createTemp('offline_profile');
    addTearDown(() => directory.delete(recursive: true));
    final service = MinecraftAuthService(
      minecraftPath: directory.path,
      httpClient: const _NetworkBlockingAuthClient(),
    );

    final identity = await service.authenticateOffline('LocalPlayer');

    expect(identity.name, 'LocalPlayer');
    expect(identity.uuid, OfflineProfileStore.uuidForName('LocalPlayer'));
    expect(identity.accessToken, '0');
    expect(identity.userType, 'legacy');
    expect(identity.xuid, isEmpty);
  });
}

/// Proves the local-profile path performs no HTTP work at all.
class _NetworkBlockingAuthClient extends AuthHttpClient {
  const _NetworkBlockingAuthClient();

  @override
  Future<Map<String, dynamic>> requestJson(
    Uri uri, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? form,
    String? bearerToken,
    bool acceptOAuthPending = false,
  }) {
    fail('local profile login must not reach the network: $uri');
  }
}
