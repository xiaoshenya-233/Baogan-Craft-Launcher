import 'package:baogan_craft_launcher/l10n/app_localizations.dart';
import 'package:baogan_craft_launcher/pages/downloads/widgets/target_client_picker.dart';
import 'package:baogan_craft_launcher/services/installer/version_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LauncherVersion _client(
  String name,
  String minecraftVersion,
  String? loaderType,
) {
  return LauncherVersion(
    name: name,
    path: '/clients/$name',
    kind: loaderType == null ? VersionKind.vanilla : VersionKind.modded,
    minecraftPath: '/clients',
    minecraftVersion: minecraftVersion,
    loaderType: loaderType,
    loaderVersion: loaderType == null ? null : '1.0',
  );
}

void main() {
  Widget wrapApp(Widget child) => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  testWidgets('preselects the first compatible client and returns it', (
    WidgetTester tester,
  ) async {
    TargetClientSelection? result;
    await tester.pumpWidget(
      wrapApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await TargetClientPicker.show(
                    context,
                    clients: [
                      _client('NeoForge 客户端', '1.21', 'NeoForge'),
                      _client('Fabric 客户端', '1.20.1', 'Fabric'),
                    ],
                    gameVersions: const ['1.20.1'],
                    loaders: const ['fabric'],
                    modTitle: 'Sodium',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('选择目标客户端'), findsOneWidget);
    expect(find.text('兼容'), findsOneWidget);
    expect(find.text('版本与加载器不匹配'), findsOneWidget);

    await tester.tap(find.text('确认安装'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.client?.name, 'Fabric 客户端');
    expect(result!.customPath, isNull);
  });

  testWidgets('allows manually choosing an incompatible client', (
    WidgetTester tester,
  ) async {
    TargetClientSelection? result;
    await tester.pumpWidget(
      wrapApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await TargetClientPicker.show(
                    context,
                    clients: [_client('NeoForge 客户端', '1.21', 'NeoForge')],
                    gameVersions: const ['1.20.1'],
                    loaders: const ['fabric'],
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Nothing compatible -> nothing preselected -> confirm disabled.
    var confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认安装'),
    );
    expect(confirm.onPressed, isNull);
    expect(find.text('版本与加载器不匹配'), findsOneWidget);

    // Manually selecting the incompatible client enables the button at once.
    await tester.tap(find.text('NeoForge 客户端'));
    await tester.pumpAndSettle();
    confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认安装'),
    );
    expect(confirm.onPressed, isNotNull);
    expect(
      find.textContaining('警告：该模组可能无法在此客户端中正常加载'),
      findsOneWidget,
    );

    await tester.tap(find.text('确认安装'));
    await tester.pumpAndSettle();
    expect(result?.client?.name, 'NeoForge 客户端');
  });

  testWidgets('prefers the current compatible client over the first', (
    WidgetTester tester,
  ) async {
    TargetClientSelection? result;
    await tester.pumpWidget(
      wrapApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await TargetClientPicker.show(
                    context,
                    clients: [
                      _client('Fabric A', '1.20.1', 'Fabric'),
                      _client('Fabric B', '1.20.1', 'Fabric'),
                    ],
                    gameVersions: const ['1.20.1'],
                    loaders: const ['fabric'],
                    preferredClientPath: r'\clients\Fabric B',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认安装'));
    await tester.pumpAndSettle();

    expect(result?.client?.name, 'Fabric B');
  });
}

