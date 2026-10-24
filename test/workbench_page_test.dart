import 'package:baogan_craft_launcher/l10n/app_localizations.dart';
import 'package:baogan_craft_launcher/pages/launcher/launcher_palette.dart';
import 'package:baogan_craft_launcher/pages/workbench/workbench_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('workbench hub shows feature cards and placeholder back flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WorkbenchPage(
            palette: LauncherPalette.fromDark(false),
            onNavigate: (_) {},
            onLaunchGame: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('功能中枢'), findsOneWidget);
    for (final title in <String>['插件中心', '系统监控', 'NBT 查看器', '存档备份中心']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('开发中'), findsNWidgets(3));

    await tester.tap(find.text('系统监控'));
    await tester.pumpAndSettle();

    expect(find.text('功能中枢'), findsNothing);
    expect(find.text('未来将在此显示 Windows 内存/CPU 状态。'), findsOneWidget);
    expect(find.text('系统监控'), findsOneWidget);

    await tester.tap(find.byTooltip('返回功能中枢'));
    await tester.pumpAndSettle();

    expect(find.text('功能中枢'), findsOneWidget);
    expect(find.text('未来将在此显示 Windows 内存/CPU 状态。'), findsNothing);
  });

  testWidgets('workbench switches between two placeholder features', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WorkbenchPage(
            palette: LauncherPalette.fromDark(true),
            onNavigate: (_) {},
            onLaunchGame: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('NBT 查看器'));
    await tester.pumpAndSettle();
    expect(find.text('未来将在此浏览与编辑 NBT 数据。'), findsOneWidget);

    await tester.tap(find.byTooltip('返回功能中枢'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('存档备份中心'));
    await tester.pumpAndSettle();
    expect(find.text('未来将在此支持一键打包备份存档，防止心血丢失。'), findsOneWidget);
  });
}
