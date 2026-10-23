//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baogan_craft_launcher/main.dart';

class _FakeMinecraftCatalogService extends MinecraftCatalogService {
  @override
  Future<List<MinecraftCatalogVersion>> fetchMinecraftVersions() async => [
    const MinecraftCatalogVersion(id: '1.21.1', type: 'release'),
    const MinecraftCatalogVersion(id: '1.20.4', type: 'release'),
    const MinecraftCatalogVersion(id: '25w41a', type: 'snapshot'),
    const MinecraftCatalogVersion(id: 'b1.7.3', type: 'old_beta'),
    const MinecraftCatalogVersion(id: '24w14potato', type: 'snapshot'),
    const MinecraftCatalogVersion(id: '23w13a_or_b', type: 'snapshot'),
  ];

  @override
  Future<List<String>> fetchLoaderVersions(
    String loader,
    String minecraftVersion,
  ) async => switch (loader) {
    'forge' => ['47.3.0', '47.2.0'],
    'neoforge' => ['21.1.172'],
    'fabric' => ['0.16.14'],
    'optifine' => ['HD_U_I6'],
    _ => [],
  };
}

Future<void> _finishPageTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  test(
    'each client keeps its own sub-folders inside the version directory',
    () {
      final vanilla = minecraftVersionSubfolder(
        r'C:\.minecraft\versions\1.21.1',
        'mods',
      );
      final fabric = minecraftVersionSubfolder(
        r'C:\.minecraft\versions\fabric-loader-0.16.14-1.21.1',
        'mods',
      );

      expect(vanilla, isNot(fabric));
      expect(
        vanilla,
        endsWith(
          '${Platform.pathSeparator}versions${Platform.pathSeparator}1.21.1'
          '${Platform.pathSeparator}mods',
        ),
      );
      expect(
        fabric,
        endsWith(
          '${Platform.pathSeparator}versions'
          '${Platform.pathSeparator}fabric-loader-0.16.14-1.21.1'
          '${Platform.pathSeparator}mods',
        ),
      );
    },
  );

  test('parseJavaMajorVersion reads legacy and modern version formats', () {
    expect(parseJavaMajorVersion('java version "1.8.0_265"'), 8);
    expect(parseJavaMajorVersion('openjdk version "17.0.1" 2021-10-19'), 17);
    expect(parseJavaMajorVersion('openjdk version "11" 2018-09-25'), 11);
    expect(parseJavaMajorVersion('java version "21.0.2" 2024-01-16'), 21);
    expect(parseJavaMajorVersion('no version here'), 0);
  });

  test('parseJavaRuntimeDetails extracts vendor, bitness and version', () {
    final temurin = parseJavaRuntimeDetails(
      'openjdk version "17.0.1" 2021-10-19\n'
      'OpenJDK Runtime Environment Temurin-17.0.1+12 (build 17.0.1+12)\n'
      'OpenJDK 64-Bit Server VM Temurin-17.0.1+12 (build 17.0.1+12, mixed mode)',
    );
    expect(temurin.vendor, 'Temurin');
    expect(temurin.bitness, 64);
    expect(temurin.fullVersion, '17.0.1');

    final oracle = parseJavaRuntimeDetails(
      'java version "1.8.0_265"\n'
      'Java(TM) SE Runtime Environment (build 1.8.0_265-b01)\n'
      'Java HotSpot(TM) 64-Bit Server VM (build 25.265-b01, mixed mode)',
    );
    expect(oracle.vendor, 'Oracle');
    expect(oracle.bitness, 64);
    expect(oracle.fullVersion, '1.8.0_265');
  });

  test('download count formatting keeps the requested thousand groups', () {
    expect(formatDownloadCount(999), '999');
    expect(formatDownloadCount(1000), '1K');
    expect(formatDownloadCount(542113), '54.2.1K');
  });

  testWidgets(
    'version management starts without preset client and supports search',
    (WidgetTester tester) async {
      await tester.pumpWidget(const BlockLauncherApp());

      expect(find.text('Baogan Craft Launcher'), findsOneWidget);
      expect(find.text('主页'), findsOneWidget);
      expect(find.text('版本管理'), findsOneWidget);
      expect(find.text('资源下载'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('资源中心'), findsNothing);
      expect(find.text('当前客户端'), findsOneWidget);
      expect(find.text('欢迎回来，冒险者'), findsNothing);
      expect(find.text('开始游戏'), findsOneWidget);

      await tester.tap(find.text('版本管理'));
      await _finishPageTransition(tester);
      expect(find.text('游戏版本'), findsOneWidget);
      expect(find.byType(ClipOval), findsOneWidget);
      final iconButtonShape = tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.refresh_rounded),
              matching: find.byType(IconButton),
            ),
          )
          .style
          ?.shape
          ?.resolve({});
      expect(iconButtonShape, isA<CircleBorder>());
      expect(find.textContaining('模组版'), findsOneWidget);
      expect(find.textContaining('原版'), findsOneWidget);
      expect(find.text('尚未选择 .minecraft 文件夹'), findsOneWidget);
      expect(find.text('前往下载 Minecraft'), findsOneWidget);
      expect(find.text('导入整合包'), findsOneWidget);
      expect(find.text('添加已有文件夹'), findsOneWidget);
      // The floating capsule navigation adds exactly one blurred layer.
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('开始游戏'), findsNothing);
      expect(find.text('BGUC'), findsNothing);
      expect(find.text('Minecraft 1.21.1'), findsNothing);
      expect(find.text('NeoForge 版本未知'), findsNothing);
      expect(find.text('检索客户端名称、Minecraft 版本或加载器'), findsOneWidget);
      expect(find.text('可导入'), findsNothing);

      await tester.tap(find.text('主页'));
      await _finishPageTransition(tester);
      expect(find.text('当前客户端'), findsOneWidget);
      expect(find.text('开始游戏'), findsOneWidget);
    },
  );

  testWidgets('settings tab provides wallpaper controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BlockLauncherApp());

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('自定义启动器外观与使用体验。'), findsOneWidget);
    expect(find.text('全局游戏默认设置'), findsNWidgets(2));
    expect(find.text('游戏资源获取渠道'), findsNWidgets(2));
    expect(find.text('个性化与主题'), findsNWidgets(2));
    expect(find.text('Java 管理'), findsNWidgets(2));
    expect(find.text('客户端下载源'), findsOneWidget);
    expect(find.text('模组资源源'), findsOneWidget);
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('壁纸'), findsOneWidget);
    expect(find.text('亮色模式壁纸'), findsOneWidget);
    expect(find.text('深色模式壁纸'), findsOneWidget);
    expect(find.text('选择图片'), findsNWidgets(2));
    expect(find.text('恢复默认'), findsNothing);

    await tester.tap(find.text('主页'));
    await _finishPageTransition(tester);
    expect(find.text('开始游戏'), findsOneWidget);
  });

  testWidgets('settings can switch between light and dark themes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BlockLauncherApp());
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      isIn([ThemeMode.dark, ThemeMode.light]),
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '日出日落自动'))
          .selected,
      isTrue,
    );
    expect(find.text('日出日落自动'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '亮色'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, '亮色'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(
      tester.widget<Text>(find.text('Baogan Craft Launcher')).style?.color,
      const Color(0xFF26351F),
    );

    await tester.tap(find.text('资源下载').first);
    await _finishPageTransition(tester);
    final minecraftEntrySurfaces = tester.widgetList<Container>(
      find.ancestor(
        of: find.text('Minecraft 游戏本体'),
        matching: find.byType(Container),
      ),
    );
    expect(
      minecraftEntrySurfaces.any(
        (container) =>
            container.decoration is BoxDecoration &&
            (container.decoration as BoxDecoration).color ==
                const Color(0xD9F8FAF6),
      ),
      isTrue,
    );

    await tester.tap(find.text('设置'));
    await _finishPageTransition(tester);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '深色'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, '深色'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets('resource downloads page exposes remote search and categories', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BlockLauncherApp());

    await tester.tap(find.text('资源下载').first);
    await tester.pump();
    expect(find.byType(FadeTransition), findsAtLeastNWidgets(1));
    await _finishPageTransition(tester);

    expect(find.text('浏览游戏模组、材质包、光影与地图资源。'), findsOneWidget);
    expect(find.text('全部'), findsNothing);
    expect(find.text('模组'), findsOneWidget);
    expect(find.text('光影'), findsOneWidget);
    expect(find.text('材质包'), findsOneWidget);
    expect(find.text('数据包/地图'), findsOneWidget);
    expect(find.byKey(const ValueKey('modrinth-search')), findsOneWidget);
    expect(find.textContaining('数据来源：'), findsOneWidget);
    expect(find.textContaining('最近'), findsNothing);

    await tester.tap(find.text('光影'));
    await tester.pump();
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '光影')).selected,
      isTrue,
    );
    expect(find.text('全部'), findsNothing);
  });

  testWidgets('resource downloads page fits wide and narrow windows', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in [const Size(1600, 1000), const Size(600, 900)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const BlockLauncherApp());
      await tester.tap(find.text('资源下载').first);
      await _finishPageTransition(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Minecraft 游戏本体'), findsOneWidget);
      expect(find.text('全部'), findsNothing);
      expect(find.byKey(const ValueKey('modrinth-search')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('下载 Minecraft').first);
      await _finishPageTransition(tester);
      expect(find.text('Minecraft 版本'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Minecraft download page exposes compatible loader options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      BlockLauncherApp(minecraftCatalogService: _FakeMinecraftCatalogService()),
    );

    await tester.tap(find.text('资源下载'));
    await _finishPageTransition(tester);
    await tester.tap(find.text('下载 Minecraft'));
    await _finishPageTransition(tester);

    expect(find.text('下载 Minecraft'), findsOneWidget);
    expect(find.text('Minecraft 版本'), findsOneWidget);
    expect(find.text('版本分类'), findsNothing);
    expect(find.text('正式版'), findsOneWidget);
    expect(find.text('预览版'), findsOneWidget);
    expect(find.text('远古版'), findsOneWidget);
    expect(find.text('愚人节版'), findsOneWidget);
    expect(find.text('1.21.1'), findsOneWidget);
    expect(find.text('Forge'), findsOneWidget);
    expect(find.text('NeoForge'), findsOneWidget);
    expect(find.text('Fabric'), findsOneWidget);
    expect(find.text('版本数据与加速 API 由 BMCLAPI 提供。'), findsOneWidget);
    expect(find.text('OptiFine'), findsOneWidget);
    expect(find.text('Fabric API'), findsNothing);

    await tester.ensureVisible(find.text('Forge'));
    await tester.pump();
    await tester.tap(find.text('Forge'));
    await tester.pumpAndSettle();
    expect(find.text('47.3.0'), findsOneWidget);
    expect(find.text('Fabric API'), findsNothing);

    await tester.ensureVisible(find.text('Fabric'));
    await tester.pump();
    await tester.tap(find.text('Fabric'));
    await tester.pumpAndSettle();
    expect(find.text('0.16.14'), findsOneWidget);
    expect(find.text('同时安装 OptiFine'), findsNothing);
    expect(find.textContaining('Fabric API'), findsAtLeastNWidgets(1));

    await tester.ensureVisible(find.text('OptiFine'));
    await tester.pump();
    await tester.tap(find.text('OptiFine'));
    await tester.pumpAndSettle();
    expect(find.text('HD_U_I6'), findsOneWidget);
    expect(find.textContaining('OptiFine HD_U_I6'), findsOneWidget);

    await tester.ensureVisible(find.text('愚人节版'));
    await tester.pump();
    await tester.tap(find.text('愚人节版'));
    await tester.pumpAndSettle();
    expect(find.text('24w14potato'), findsOneWidget);
  });

  test('Minecraft download source maps artifact URLs correctly', () {
    const downloader = MinecraftDownloadService();
    expect(
      downloader.resolveDownloadUri(
        Uri.https('piston-data.mojang.com', '/v1/objects/abc/client.jar'),
        source: MinecraftDownloadSource.mojang,
        versionId: '1.21.1',
        clientArtifact: true,
      ),
      Uri.https('piston-data.mojang.com', '/v1/objects/abc/client.jar'),
    );
    expect(
      downloader.resolveDownloadUri(
        Uri.https('piston-data.mojang.com', '/v1/objects/abc/client.jar'),
        source: MinecraftDownloadSource.bmclapi,
        versionId: '1.21.1',
        clientArtifact: true,
      ),
      Uri.https('bmclapi2.bangbang93.com', '/version/1.21.1/client'),
    );
    expect(
      downloader.resolveDownloadUri(
        Uri.https('libraries.minecraft.net', '/com/example/library/1.0/a.jar'),
        source: MinecraftDownloadSource.bmclapi,
        versionId: '1.21.1',
      ),
      Uri.https(
        'bmclapi2.bangbang93.com',
        '/maven/com/example/library/1.0/a.jar',
      ),
    );
    expect(
      downloader.resolveDownloadUri(
        Uri.https('resources.download.minecraft.net', '/ab/abcdef'),
        source: MinecraftDownloadSource.bmclapi,
        versionId: '1.21.1',
      ),
      Uri.https('bmclapi2.bangbang93.com', '/assets/ab/abcdef'),
    );
  });
}
