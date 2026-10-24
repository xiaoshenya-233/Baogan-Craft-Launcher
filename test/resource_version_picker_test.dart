import 'dart:async';

import 'package:baogan_craft_launcher/pages/downloads/resource_downloads_page.dart';
import 'package:baogan_craft_launcher/services/network/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _project = ModrinthProject(
  id: 'jei',
  title: 'JEI',
  description: 'Item viewer',
  category: DownloadCategory.mods,
  downloads: 1,
  followers: 1,
  versions: <ModrinthVersion>[],
  tags: <String>[],
);

Widget _sheet({required Future<ModrinthProject> Function() loadProject}) {
  return MaterialApp(
    home: Scaffold(
      body: ResourceVersionPickerSheet(
        project: _project,
        loadProject: loadProject,
        loadersFor: (_) => const <String>['neoforge'],
        gameVersionsFor: (_) => const <String>['1.21.1'],
        panelColor: Colors.white,
        accentColor: Colors.white,
        borderColor: Colors.grey,
        mutedColor: Colors.grey,
      ),
    ),
  );
}

ModrinthVersion _fileVersion(
  String filename,
  String gameVersion, {
  required String id,
  String loader = 'neoforge',
  String? name,
  int downloads = 0,
}) {
  return ModrinthVersion(
    name: name ?? filename,
    versionType: 'release',
    downloads: downloads,
    gameVersions: <String>[gameVersion],
    loaders: <String>[loader],
    files: <ModrinthFile>[
      ModrinthFile(filename: filename, url: 'https://example.invalid/$id.jar'),
    ],
    versionId: id,
  );
}

Widget _picker({
  required ModrinthProject project,
  required Future<ModrinthProject> Function() loadProject,
  required List<String> Function(ModrinthProject) gameVersionsFor,
  List<String> Function(ModrinthProject)? loadersFor,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ResourceVersionPickerSheet(
        project: project,
        loadProject: loadProject,
        loadersFor: loadersFor ?? (_) => const <String>['neoforge'],
        gameVersionsFor: gameVersionsFor,
        panelColor: Colors.white,
        accentColor: Colors.white,
        borderColor: Colors.grey,
        mutedColor: Colors.grey,
      ),
    ),
  );
}

void main() {
  testWidgets('shows the loading sheet before the version request finishes', (
    tester,
  ) async {
    final pending = Completer<ModrinthProject>();

    await tester.pumpWidget(_sheet(loadProject: () => pending.future));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(
      _project.withVersions(const <ModrinthVersion>[
        ModrinthVersion(
          name: 'JEI 1.21.1',
          versionType: 'release',
          downloads: 1,
          gameVersions: <String>['1.21.1'],
          loaders: <String>['neoforge'],
          files: <ModrinthFile>[
            ModrinthFile(
              filename: 'jei.jar',
              url: 'https://example.invalid/jei.jar',
            ),
          ],
          versionId: 'jei-1',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('timeout shows an in-sheet retry action', (tester) async {
    await tester.pumpWidget(
      _sheet(loadProject: () async => throw TimeoutException('slow')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('major and loader chips drive the concrete version cards', (
    tester,
  ) async {
    final versions = <ModrinthVersion>[
      _fileVersion('A.jar', '1.21.1', id: 'a'),
      _fileVersion('B.jar', '1.21', id: 'b', loader: 'forge'),
      _fileVersion('C.jar', '1.20.1', id: 'c', loader: 'forge'),
    ];
    final project = _project.withVersions(versions);

    await tester.pumpWidget(
      _picker(
        project: project,
        loadProject: () async => project,
        loadersFor: (_) => const <String>['neoforge', 'forge'],
        gameVersionsFor: (_) => const <String>['1.21.1', '1.21', '1.20.1'],
      ),
    );
    await tester.pumpAndSettle();

    // View A is the default: two filter rows and version cards.
    expect(find.text('Minecraft 大版本'), findsOneWidget);
    expect(find.text('模组加载器'), findsOneWidget);
    expect(find.text('具体版本'), findsNothing);
    expect(find.byKey(const ValueKey('picker-major-1.21')), findsOneWidget);
    expect(find.byKey(const ValueKey('picker-major-1.20')), findsOneWidget);
    expect(find.byKey(const ValueKey('version-card-1.21.1')), findsOneWidget);
    expect(find.byKey(const ValueKey('version-card-1.21')), findsOneWidget);
    expect(find.text('1 个可下载文件'), findsNWidgets(2));

    // Major chip: cards refresh to the new major.
    await tester.tap(find.byKey(const ValueKey('picker-major-1.20')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('version-card-1.20.1')), findsOneWidget);
    expect(find.byKey(const ValueKey('version-card-1.21.1')), findsNothing);

    // Loader chip: counts refresh for the same major.
    await tester.tap(find.byKey(const ValueKey('picker-loader-forge')));
    await tester.pumpAndSettle();
    expect(find.text('1 个可下载文件'), findsOneWidget);

    // Tapping a card switches to the file list.
    await tester.tap(find.byKey(const ValueKey('version-card-1.20.1')));
    await tester.pumpAndSettle();
    expect(find.text('C.jar'), findsOneWidget);
    expect(find.byKey(const ValueKey('version-card-1.20.1')), findsNothing);
    expect(find.byKey(const ValueKey('version-picker-back')), findsOneWidget);

    // Back returns to the version cards.
    await tester.tap(find.byKey(const ValueKey('version-picker-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('version-card-1.20.1')), findsOneWidget);

    // A concrete version without files for the loader is disabled.
    await tester.tap(find.byKey(const ValueKey('picker-major-1.21')));
    await tester.pumpAndSettle();
    expect(find.text('该版本没有可下载文件'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('version-card-1.21.1')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('version-card-1.21.1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('version-card-1.21')));
    await tester.pumpAndSettle();
    expect(find.text('B.jar'), findsOneWidget);
  });

  testWidgets('chips stay tappable inside a modal bottom sheet', (
    tester,
  ) async {
    final versions = <ModrinthVersion>[
      _fileVersion('A.jar', '1.21.1', id: 'a'),
      _fileVersion('C.jar', '1.20.1', id: 'c', loader: 'forge'),
    ];
    final project = _project.withVersions(versions);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ResourceVersionPickerSheet(
                  project: project,
                  loadProject: () async => project,
                  loadersFor: (_) => const <String>['neoforge', 'forge'],
                  gameVersionsFor: (_) => const <String>['1.21.1', '1.20.1'],
                  panelColor: Colors.white,
                  accentColor: Colors.white,
                  borderColor: Colors.grey,
                  mutedColor: Colors.grey,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('picker-major-1.20')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('version-card-1.20.1')), findsOneWidget);
    expect(find.byKey(const ValueKey('version-card-1.21.1')), findsNothing);
  });

  testWidgets('load more appends 20 files and drops duplicate ids', (
    tester,
  ) async {
    final firstPage = List<ModrinthVersion>.generate(
      20,
      (index) => _fileVersion(
        'Mod-$index.jar',
        '1.21.1',
        id: 'v$index',
        downloads: 20 - index,
      ),
    );
    final duplicate = _fileVersion(
      'Mod-19.jar',
      '1.21.1',
      id: 'v19',
      downloads: -1,
    );
    final extra = _fileVersion(
      'Mod-20.jar',
      '1.21.1',
      id: 'v20',
      downloads: -2,
    );
    final all = <ModrinthVersion>[...firstPage, duplicate, extra];

    await tester.pumpWidget(
      _picker(
        project: _project.withVersions(all),
        loadProject: () async => _project.withVersions(all),
        gameVersionsFor: (_) => const <String>['1.21.1'],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('version-card-1.21.1')));
    await tester.pumpAndSettle();

    final listFinder = find.byKey(const ValueKey('resource-version-file-list'));
    final scrollable = find
        .descendant(of: listFinder, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.text('加载更多文件'),
      400,
      scrollable: scrollable,
    );
    await tester.tap(find.text('加载更多文件'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('已加载全部 21 个文件'),
      400,
      scrollable: scrollable,
    );
    expect(find.text('Mod-20.jar'), findsOneWidget);
  });

  testWidgets('card count matches files stored at the end of the index', (
    tester,
  ) async {
    final versions = <ModrinthVersion>[
      for (var index = 0; index < 25; index++)
        _fileVersion(
          'Old-$index.jar',
          '1.20.1',
          id: 'old-$index',
          downloads: 100 - index,
        ),
      for (var index = 0; index < 3; index++)
        _fileVersion(
          'Target-$index.jar',
          '1.21.1',
          id: 'target-$index',
          downloads: 3 - index,
        ),
    ];
    final project = _project.withVersions(versions);

    await tester.pumpWidget(
      _picker(
        project: project,
        loadProject: () async => project,
        gameVersionsFor: (_) => const <String>['1.21.1', '1.20.1'],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 个可下载文件'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('version-card-1.21.1')));
    await tester.pumpAndSettle();

    expect(find.text('Target-0.jar'), findsOneWidget);
    expect(find.text('Target-1.jar'), findsOneWidget);
    expect(find.text('Target-2.jar'), findsOneWidget);
    expect(find.text('当前筛选条件下没有可下载文件。'), findsNothing);

    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('resource-version-file-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('已加载全部 3 个文件'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('已加载全部 3 个文件'), findsOneWidget);
  });
}
