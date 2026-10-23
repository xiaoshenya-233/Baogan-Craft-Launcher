import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/preferences_store.dart';
import '../../../services/network/account_manager.dart';
import '../../../services/network/account_models.dart';
import '../../../services/network/auth_service.dart';

const String defaultThirdPartyAuthServer =
    'https://littleskin.cn/api/yggdrasil';

/// Owns launch authentication settings persisted between sessions.
class AuthController extends ChangeNotifier {
  AuthController({
    required this.preferences,
    this.onError,
    AccountManager? accountManager,
  }) : accountManager =
           accountManager ?? AccountManager(preferences: preferences);

  final PreferencesStore preferences;
  final void Function(String message)? onError;

  /// Encrypted multi-account storage.
  final AccountManager accountManager;

  AuthMode _mode = AuthMode.offline;
  String _offlinePlayerName = 'Player';
  String _thirdPartyAuthServer = defaultThirdPartyAuthServer;
  List<UserAccount> _accounts = const <UserAccount>[];
  UserAccount? _currentAccount;

  AuthMode get mode => _mode;
  String get offlinePlayerName => _offlinePlayerName;
  String get thirdPartyAuthServer => _thirdPartyAuthServer;

  /// All stored accounts (metadata + decrypted tokens).
  List<UserAccount> get accounts => List.unmodifiable(_accounts);

  /// Account used for the next launch.
  UserAccount? get currentAccount => _currentAccount;

  void applyPreferences({
    String? modeName,
    String? offlinePlayerName,
    String? thirdPartyAuthServer,
  }) {
    _mode = AuthMode.values.firstWhere(
      (mode) => mode.name == modeName,
      orElse: () => AuthMode.offline,
    );
    if (offlinePlayerName != null &&
        RegExp(r'^[A-Za-z0-9_]{3,16}$').hasMatch(offlinePlayerName)) {
      _offlinePlayerName = offlinePlayerName;
    }
    if (thirdPartyAuthServer != null &&
        thirdPartyAuthServer.trim().isNotEmpty) {
      _thirdPartyAuthServer = thirdPartyAuthServer.trim();
    }
    notifyListeners();
  }

  Future<void> updateMode(AuthMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _write('launchAuthMode', mode.name);
  }

  Future<void> updateOfflinePlayerName(String name) async {
    if (_offlinePlayerName == name) return;
    _offlinePlayerName = name;
    notifyListeners();
    await _write('offlinePlayerName', name);
  }

  Future<void> updateThirdPartyAuthServer(String server) async {
    final normalized = server.trim();
    if (_thirdPartyAuthServer == normalized) return;
    _thirdPartyAuthServer = normalized;
    notifyListeners();
    await _write('thirdPartyAuthServer', normalized);
  }

  /// Reloads the account list and re-attaches encrypted tokens.
  Future<void> loadAccounts() async {
    try {
      _accounts = await accountManager.loadAccounts();
      _currentAccount = await accountManager.getCurrentAccount();
      notifyListeners();
    } on Object catch (error) {
      onError?.call('读取账号列表失败：$error');
    }
  }

  /// Stores a freshly authenticated identity and makes it the active account.
  Future<UserAccount?> rememberAccount(
    AuthIdentity identity, {
    String? refreshToken,
  }) async {
    try {
      final account = UserAccount.fromIdentity(identity);
      await accountManager.addAccount(
        account,
        identity.accessToken,
        refreshToken: refreshToken,
      );
      _accounts = await accountManager.loadAccounts();
      _currentAccount = await accountManager.getCurrentAccount();
      notifyListeners();
      return _currentAccount;
    } on Object catch (error) {
      onError?.call('保存账号失败：$error');
      return null;
    }
  }

  /// Switches the active account immediately; persistence runs in background.
  Future<void> selectAccount(String id) async {
    UserAccount? target;
    for (final account in _accounts) {
      if (account.id == id) {
        target = account;
        break;
      }
    }
    if (target == null) return;
    _currentAccount = target;
    notifyListeners();
    await _persistCurrentAccount(id);
  }

  Future<void> _persistCurrentAccount(String id) async {
    try {
      await accountManager.setCurrentAccount(id);
    } on Object catch (error) {
      onError?.call('切换账号失败：$error');
    }
  }

  /// Removes an account from the UI at once and purges its tokens afterwards.
  Future<void> removeAccount(String id) async {
    final remaining = _accounts.where((account) => account.id != id).toList();
    if (remaining.length == _accounts.length) return;
    _accounts = remaining;
    if (_currentAccount?.id == id) {
      _currentAccount = remaining.firstOrNull;
    }
    notifyListeners();
    await _purgeAccount(id);
  }

  Future<void> _purgeAccount(String id) async {
    try {
      await accountManager.removeAccount(id);
    } on Object catch (error) {
      onError?.call('移除账号失败：$error');
    }
  }

  Future<void> _write(String key, Object? value) async {
    try {
      await preferences.write(key, value);
    } on FormatException catch (error) {
      onError?.call('保存认证设置失败：${error.message}');
    } on FileSystemException catch (error) {
      onError?.call('保存认证设置失败：${error.message}');
    }
  }
}
