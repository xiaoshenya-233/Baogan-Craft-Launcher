import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/launcher_log.dart';
import '../../core/preferences_store.dart';
import 'account_models.dart';

/// Minimal secret store so tests can swap the platform plugin out.
abstract class SecureTokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Default store backed by `flutter_secure_storage` (DPAPI on Windows).
class FlutterSecureTokenStore implements SecureTokenStore {
  const FlutterSecureTokenStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Multi-account storage: metadata in [PreferencesStore], tokens encrypted.
///
/// Sensitive values never touch the JSON preferences file; they are written to
/// `flutter_secure_storage` (DPAPI on Windows) under `account_token_<id>` and
/// `account_refresh_<id>`.
class AccountManager {
  AccountManager({
    required this.preferences,
    SecureTokenStore? tokenStore,
  }) : _tokens = tokenStore ?? const FlutterSecureTokenStore();

  static const String accountsKey = 'userAccounts';
  static const String currentAccountKey = 'currentAccountId';
  static const String tokenKeyPrefix = 'account_token_';
  static const String refreshKeyPrefix = 'account_refresh_';

  final PreferencesStore preferences;
  final SecureTokenStore _tokens;

  Future<String?> _readSecret(String key) async {
    try {
      return await _tokens.read(key);
    } on Object catch (error) {
      // Missing plugin / locked keychain: keep going without a token.
      LauncherLog.warning('Accounts', '读取加密凭据失败：$error');
      return null;
    }
  }

  Future<void> _writeSecret(String key, String value) async {
    try {
      await _tokens.write(key, value);
    } on Object catch (error) {
      LauncherLog.warning('Accounts', '保存加密凭据失败：$error');
    }
  }

  Future<void> _deleteSecret(String key) async {
    try {
      await _tokens.delete(key);
    } on Object catch (error) {
      LauncherLog.warning('Accounts', '清理加密凭据失败：$error');
    }
  }

  /// Reads the metadata list and re-attaches the decrypted tokens.
  Future<List<UserAccount>> loadAccounts() async {
    final decoded = await preferences.readAll();
    final rawList = decoded[accountsKey];
    if (rawList is! List) return const <UserAccount>[];
    final accounts = <UserAccount>[];
    for (final row in rawList) {
      final account = UserAccount.fromJson(row);
      if (account == null) continue;
      final token = await _readSecret('$tokenKeyPrefix${account.id}') ?? '';
      final refresh = await _readSecret('$refreshKeyPrefix${account.id}') ?? '';
      accounts.add(
        account.copyWith(accessToken: token, refreshToken: refresh),
      );
    }
    return accounts;
  }

  /// Adds or replaces an account and marks it as the active one.
  Future<UserAccount> addAccount(
    UserAccount account,
    String accessToken, {
    String? refreshToken,
  }) async {
    final stored = account.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    if (accessToken.trim().isNotEmpty) {
      await _writeSecret('$tokenKeyPrefix${stored.id}', accessToken.trim());
    }
    final refresh = refreshToken?.trim() ?? '';
    if (refresh.isNotEmpty) {
      await _writeSecret('$refreshKeyPrefix${stored.id}', refresh);
    }
    final existing = await loadAccounts();
    final next = <UserAccount>[
      for (final item in existing)
        if (item.id != stored.id) item,
      stored,
    ];
    await _saveMetadata(next);
    await setCurrentAccount(stored.id);
    LauncherLog.info('Accounts', '已保存账号：${stored.name}（${stored.type.name}）');
    return stored;
  }

  /// Removes the account and wipes both encrypted tokens.
  Future<void> removeAccount(String id) async {
    final existing = await loadAccounts();
    final next = existing.where((item) => item.id != id).toList();
    await _saveMetadata(next);
    await _deleteSecret('$tokenKeyPrefix$id');
    await _deleteSecret('$refreshKeyPrefix$id');
    final current = await currentAccountId();
    if (current == id) {
      await setCurrentAccount(next.isEmpty ? '' : next.first.id);
    }
    LauncherLog.info('Accounts', '已移除账号：$id');
  }

  Future<String> currentAccountId() async {
    final decoded = await preferences.readAll();
    final value = decoded[currentAccountKey];
    return value is String ? value : '';
  }

  Future<void> setCurrentAccount(String id) =>
      preferences.write(currentAccountKey, id);

  /// Returns the active account, falling back to the first stored entry.
  Future<UserAccount?> getCurrentAccount() async {
    final accounts = await loadAccounts();
    if (accounts.isEmpty) return null;
    final id = await currentAccountId();
    if (id.isEmpty) return accounts.first;
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return accounts.first;
  }

  Future<void> _saveMetadata(List<UserAccount> accounts) => preferences.write(
    accountsKey,
    accounts.map((account) => account.toJson()).toList(),
  );
}
