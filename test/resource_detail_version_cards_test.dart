import 'package:baogan_craft_launcher/core/preferences_store.dart';
import 'package:baogan_craft_launcher/pages/downloads/controllers/resource_download_controller.dart';
import 'package:baogan_craft_launcher/pages/downloads/resource_downloads_page.dart';
import 'package:baogan_craft_launcher/pages/launcher/controllers/download_activity_controller.dart';
import 'package:baogan_craft_launcher/pages/launcher/launcher_palette.dart';
import 'package:baogan_craft_launcher/pages/versions/controllers/version_catalog_controller.dart';
import 'package:baogan_craft_launcher/services/download/download_service.dart';
import 'package:baogan_craft_launcher/services/network/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ModrinthVersion _forgeVersion(int index) {
  return ModrinthVersion(
    name: 'mod-$index',
    versionType: 'release',
    downloads: 1000 - index,
    gameVersions: const <String>['1.21.1'],
    loaders: const <String>['forge'],
    files: <ModrinthFile>[
      ModrinthFile(
        filename: 'mod-$index.jar',
        url: 'https://example.invalid/mod-$index.jar',
      ),
    ],
    versionId: 'forge-$index',
  );
}

void main() {
  testWidgets('detail cards count all files and page 20 rows inside the card', (
    tester,
  ) async {
    final manager = DownloadManager();
    final activity = DownloadActivityController(manager: manager);
    final catalog = VersionCatalogController(
      preferences: PreferencesStore(),
      sourcesProvider: () => const <String>[],
      minecraftPathProvider: () => '',
    );
    final resource = ResourceDownloadController();
    final project = ModrinthProject(
      id: 'detail-paging',
      title: 'Detail Paging',
      description: 'Version card paging test',
      category: DownloadCategory.mods,
      downloads: 1,
      followers: 1,
      versions: <ModrinthVersion>[
        for (var index = 0; index < 45; index++) _forgeVersion(index),
      ],
      tags: const <String>['forge'],
    );
    resource.detailProject = project;
    resource.selectDefaultResourceVersion(project);
    resource.selectedLoader = 'forge';

    addTearDown(() {
      resource.dispose();
      catalog.dispose();
      activity.dispose();
      manager.dispose();
    });

    Future<void> noop() async {}
    Future<void> noopProject(ModrinthProject _) async {}

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResourceDownloadsPage(
            resource: resource,
            activity: activity,
            catalog: catalog,
            palette: LauncherPalette.fromDark(false),
            isDark: false,
            isDownloadLocked: false,
            minecraftEntryBuilder: (_) => const SizedBox.shrink(),
            onLoadResults: noop,
            onScheduleSearch: () {},
            onToggleCandidate: noopProject,
            onOpenProject: noopProject,
            onBackToList: () {},
            onInstallProject: (_, _) async {},
            onDownloadCandidates: noop,
            onToggleVersionCandidate: (_, _) {},
            onOpenDownloadTasks: () {},
            onCancelActiveDownload: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('45 个可下载文件'), findsOneWidget);
    expect(find.text('Minecraft 1.21.1'), findsOneWidget);

    await tester.tap(find.text('Minecraft 1.21.1'));
    await tester.pumpAndSettle();

    expect(find.text('mod-0'), findsOneWidget);
    expect(find.text('mod-19'), findsOneWidget);
    expect(find.text('mod-20'), findsNothing);
    expect(find.text('加载更多文件（25 个剩余）'), findsOneWidget);

    await tester.ensureVisible(find.text('加载更多文件（25 个剩余）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载更多文件（25 个剩余）'));
    await tester.pumpAndSettle();

    expect(find.text('mod-39'), findsOneWidget);
    expect(find.text('mod-40'), findsNothing);
    expect(find.text('加载更多文件（5 个剩余）'), findsOneWidget);

    await tester.ensureVisible(find.text('加载更多文件（5 个剩余）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载更多文件（5 个剩余）'));
    await tester.pumpAndSettle();

    expect(find.text('mod-44'), findsOneWidget);
    expect(find.textContaining('加载更多文件'), findsNothing);
  });
}
