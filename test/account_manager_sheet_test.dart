import 'dart:io';

import 'package:baogan_craft_launcher/core/preferences_store.dart';
import 'package:baogan_craft_launcher/l10n/app_localizations.dart';
import 'package:baogan_craft_launcher/pages/accounts/account_management_page.dart';
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

Widget _accountPage(
  AuthController auth, {
  OfflineAccountCreator? onCreateOffline,
  ThirdPartyAccountCreator? onCreateThirdParty,
  MicrosoftAccountCreator? onCreateMicrosoft,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: AccountManagementPage(
        auth: auth,
        onBack: () {},
        onCreateOffline: onCreateOffline ?? (_) async => null,
        onCreateThirdParty: onCreateThirdParty ?? (_, _, _) async => null,
        onCreateMicrosoft: onCreateMicrosoft ?? () async => null,
      ),
    ),
  );
}

/// Waits until the page's busy spinner clears, which also means every queued
/// preference write for that action has completed.
Future<void> _waitForBusy(WidgetTester tester) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    final busy = find.byType(CircularProgressIndicator).evaluate();
    if (busy.isEmpty) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
  fail('account page stayed busy');
}

void main() {
  late Directory directory;
  late AuthController auth;

  setUp(() async {
    PreferencesStore.resetWriteQueueForTest();
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
    await tester.pumpWidget(_accountPage(auth));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('账号管理'), findsOneWidget);
    expect(find.text('共 2 个账号'), findsOneWidget);
    expect(find.text('Steve'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('当前使用'), findsOneWidget);
    expect(auth.currentAccount?.name, 'Alex');

    // Tapping another card switches the active account.
    await tester.tap(find.text('Steve'));
    await _waitForBusy(tester);
    await tester.pump(const Duration(milliseconds: 350));
    expect(auth.currentAccount?.name, 'Steve');
    expect(find.text('当前使用'), findsOneWidget);

    // Deleting asks for confirmation first.
    await tester.tap(find.byTooltip('移除账号').at(1));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('移除账号'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '移除'));
    await _waitForBusy(tester);
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Alex'), findsNothing);
    expect(auth.accounts, hasLength(1));
    expect(auth.accounts.single.name, 'Steve');
  });

  testWidgets('offline account dialog blocks invalid names', (tester) async {
    String? created;
    await tester.pumpWidget(
      _accountPage(
        auth,
        onCreateOffline: (name) async {
          created = name;
          return null;
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('添加账户'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.widgetWithText(ListTile, '本地档案'));
    await tester.pump(const Duration(milliseconds: 350));

    final field = find.byType(TextField);
    expect(field, findsOneWidget);

    await tester.enterText(field, 'ab');
    await tester.pump();
    expect(find.text('必须为纯英文且至少3位字符'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '添加'))
          .onPressed,
      isNull,
    );

    await tester.enterText(field, '中文名');
    await tester.pump();
    expect(find.text('必须为纯英文且至少3位字符'), findsOneWidget);

    await tester.enterText(field, 'Steve123');
    await tester.pump();
    expect(find.text('必须为纯英文且至少3位字符'), findsNothing);
    final addButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '添加'),
    );
    expect(addButton.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(created, 'Steve123');
  });

  testWidgets('third-party dialog forwards credentials to the creator', (
    tester,
  ) async {
    String? server;
    String? username;
    String? password;
    await tester.pumpWidget(
      _accountPage(
        auth,
        onCreateThirdParty: (s, u, p) async {
          server = s;
          username = u;
          password = p;
          return null;
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('添加账户'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.widgetWithText(ListTile, '第三方验证'));
    await tester.pump(const Duration(milliseconds: 350));

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'https://example.com/api/yggdrasil');
    await tester.enterText(fields.at(1), 'alex@example.com');
    await tester.enterText(fields.at(2), 'secret');
    await tester.pump();

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '登录并保存'),
    );
    expect(saveButton.onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, '登录并保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(server, 'https://example.com/api/yggdrasil');
    expect(username, 'alex@example.com');
    expect(password, 'secret');
  });

  testWidgets('account page keeps a 300px skin preview on the right', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_accountPage(auth));
    await tester.pump(const Duration(milliseconds: 350));

    final listRect = tester.getRect(
      find.byKey(const ValueKey('account-list-panel')),
    );
    final previewRect = tester.getRect(
      find.byKey(const ValueKey('account-skin-preview')),
    );
    expect(previewRect.width, 300);
    expect(previewRect.left, greaterThan(listRect.right));
    expect(listRect.width, greaterThan(previewRect.width));
    expect(find.text('皮肤预览'), findsOneWidget);
    expect(find.text('开发中'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
