import 'dart:io';

import 'package:baogan_craft_launcher/core/preferences_store.dart';
import 'package:baogan_craft_launcher/l10n/app_localizations.dart';
import 'package:baogan_craft_launcher/pages/home/widgets/account_manager_sheet.dart';
import 'package:baogan_craft_launcher/pages/launcher/controllers/auth_controller.dart';
import 'package:baogan_craft_launcher/services/network/account_manager.dart';
import 'package:baogan_craft_launcher/services/network/auth_service.dart';
import 'package:flutter/material.dart';
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
  late AuthController auth;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('account-sheet-');
    final preferences = PreferencesStore(
      fileProvider: () => File('${directory.path}/prefs.json'),
    );
    auth = AuthController(
      preferences: preferences,
      accountManager: AccountManager(
        preferences: preferences,
        tokenStore: _MemoryTokenStore(),
      ),
    );
    await auth.rememberAccount(
      const AuthIdentity(
        name: 'Steve',
        uuid: 'uuid-steve',
        accessToken: 'token-steve',
        userType: 'msa',
      ),
    );
    await auth.rememberAccount(
      const AuthIdentity(
        name: 'Alex',
        uuid: 'uuid-alex',
        accessToken: '0',
        userType: 'legacy',
      ),
    );
  });

  tearDown(() async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      // Pending preference writes may still hold a handle; the OS cleans up.
    }
  });

  testWidgets('lists accounts, switches and removes them', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AccountManagerSheet(auth: auth, onAddAccount: () async {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('账号管理'), findsOneWidget);
    expect(find.text('共 2 个账号'), findsOneWidget);
    expect(find.text('Steve'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('当前使用'), findsOneWidget);
    expect(auth.currentAccount?.name, 'Alex');

    // Tapping another card switches the active account.
    await tester.tap(find.text('Steve'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(auth.currentAccount?.name, 'Steve');
    expect(find.text('当前使用'), findsOneWidget);

    // Deleting asks for confirmation first.
    await tester.tap(find.byTooltip('移除账号').at(1));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('移除账号'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '移除'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Alex'), findsNothing);
    expect(auth.accounts, hasLength(1));
    expect(auth.accounts.single.name, 'Steve');
  });
}
