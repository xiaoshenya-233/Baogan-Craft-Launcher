import 'dart:convert';
import 'dart:io';

import 'package:baogan_craft_launcher/core/preferences_store.dart';
import 'package:baogan_craft_launcher/services/network/account_manager.dart';
import 'package:baogan_craft_launcher/services/network/account_models.dart';
import 'package:baogan_craft_launcher/services/network/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryTokenStore implements SecureTokenStore {
  final Map<String, String> data = <String, String>{};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

void main() {
  late Directory directory;
  late File prefsFile;
  late PreferencesStore preferences;
  late _MemoryTokenStore tokens;
  late AccountManager manager;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('account-manager-');
    prefsFile = File('${directory.path}${Platform.pathSeparator}prefs.json');
    preferences = PreferencesStore(fileProvider: () => prefsFile);
    tokens = _MemoryTokenStore();
    manager = AccountManager(preferences: preferences, tokenStore: tokens);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('metadata JSON never contains the access token', () {
    const account = UserAccount(
      id: 'microsoft:abc',
      name: 'Steve',
      uuid: 'abc',
      type: AccountType.microsoft,
      accessToken: 'secret-token',
    );
    final json = account.toJson();
    expect(json.containsKey('accessToken'), isFalse);
    expect(json.containsKey('refreshToken'), isFalse);
    expect(json['type'], 'microsoft');
  });

  test('addAccount encrypts the token and sets the current account', () async {
    const account = UserAccount(
      id: 'microsoft:abc',
      name: 'Steve',
      uuid: 'abc',
      type: AccountType.microsoft,
    );
    await manager.addAccount(account, 'secret-token', refreshToken: 'refresh');

    final raw = await prefsFile.readAsString();
    expect(raw.contains('secret-token'), isFalse);
    expect(raw.contains('refresh'), isFalse);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded[AccountManager.accountsKey], isA<List<dynamic>>());
    expect(tokens.data['account_token_microsoft:abc'], 'secret-token');
    expect(tokens.data['account_refresh_microsoft:abc'], 'refresh');
    expect(await manager.currentAccountId(), 'microsoft:abc');
  });

  test(
    'loadAccounts restores tokens and getCurrentAccount returns it',
    () async {
      const account = UserAccount(
        id: 'offline:steve',
        name: 'Steve',
        uuid: 'steve',
        type: AccountType.offline,
      );
      await manager.addAccount(account, 'secret-token');

      final loaded = await manager.loadAccounts();
      expect(loaded, hasLength(1));
      expect(loaded.single.accessToken, 'secret-token');
      final current = await manager.getCurrentAccount();
      expect(current?.name, 'Steve');
      expect(current?.type, AccountType.offline);
      expect(current?.toIdentity().userType, 'legacy');
    },
  );

  test('updateName renames an account and keeps its token', () async {
    const account = UserAccount(
      id: 'offline:steve',
      name: 'Steve',
      uuid: 'steve',
      type: AccountType.offline,
    );
    await manager.addAccount(account, 'secret-token');

    final updated = await manager.updateName(account.id, '  Alex_01  ');
    expect(updated?.name, 'Alex_01');
    final loaded = await manager.loadAccounts();
    expect(loaded.single.name, 'Alex_01');
    expect(loaded.single.accessToken, 'secret-token');
    expect(await manager.currentAccountId(), account.id);

    expect(await manager.updateName(account.id, '   '), isNull);
    expect((await manager.loadAccounts()).single.name, 'Alex_01');
  });

  test('removeAccount clears tokens and moves the current id', () async {
    const first = UserAccount(
      id: 'microsoft:first',
      name: 'Alex',
      uuid: 'first',
      type: AccountType.microsoft,
    );
    const second = UserAccount(
      id: 'microsoft:second',
      name: 'Steve',
      uuid: 'second',
      type: AccountType.microsoft,
    );
    await manager.addAccount(first, 'token-one');
    await manager.addAccount(second, 'token-two');
    await manager.setCurrentAccount(first.id);

    await manager.removeAccount(first.id);

    expect(tokens.data.containsKey('account_token_microsoft:first'), isFalse);
    final remaining = await manager.loadAccounts();
    expect(remaining.map((account) => account.id), [second.id]);
    expect(await manager.currentAccountId(), second.id);
  });

  test(
    'third-party account keeps its token and agent for the next session',
    () async {
      final identity = AuthIdentity(
        name: 'Alex',
        uuid: 'third-uuid',
        accessToken: 'ygg-token',
        userType: 'mojang',
        javaAgent: 'authlib-injector.jar=https://littleskin.cn/api/yggdrasil',
      );
      final account = UserAccount.fromIdentity(identity);
      await manager.addAccount(
        account,
        identity.accessToken,
        refreshToken: 'refresh-token',
      );

      final loaded = await manager.loadAccounts();
      expect(loaded.single.type, AccountType.thirdParty);
      expect(loaded.single.accessToken, 'ygg-token');
      expect(loaded.single.refreshToken, 'refresh-token');
      expect(loaded.single.javaAgent, contains('littleskin.cn'));

      final current = await manager.getCurrentAccount();
      expect(current?.id, account.id);
      expect(current?.toIdentity().userType, 'mojang');
      expect(current?.toIdentity().accessToken, 'ygg-token');
      expect(current?.toIdentity().javaAgent, contains('littleskin.cn'));
    },
  );
}
