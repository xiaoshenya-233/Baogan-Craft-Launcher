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
  testWidgets('preselects the first compatible client and returns it', (
    WidgetTester tester,
  ) async {
    TargetClientSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
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
    expect(find.text('版本不符'), findsOneWidget);

    await tester.tap(find.text('确认安装'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.client?.name, 'Fabric 客户端');
    expect(result!.customPath, isNull);
  });

  testWidgets('leaves nothing selected when no client matches', (
    WidgetTester tester,
  ) async {
    TargetClientSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
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

    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认安装'),
    );
    expect(confirm.onPressed, isNull);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
