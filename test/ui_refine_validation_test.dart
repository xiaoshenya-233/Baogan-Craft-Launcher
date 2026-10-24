import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baogan_craft_launcher/core/launcher_log.dart';
import 'package:baogan_craft_launcher/main.dart';

Future<void> _finishPageTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled Source Han Sans font is registered', () async {
    final manifest = await rootBundle.loadString('FontManifest.json');
    expect(manifest, contains('SourceHanSansSC'));
    expect(manifest, contains('assets/fonts/SourceHanSansSC-Regular.otf'));
  });

  test('client names and download cancellation helpers enforce safety', () {
    expect(isValidMinecraftClientName('生存客户端'), isTrue);
    expect(isValidMinecraftClientName('My Client 1.20'), isTrue);
    expect(isValidMinecraftClientName('bad/name'), isFalse);
    expect(isValidMinecraftClientName('CON'), isFalse);
    expect(isValidMinecraftClientName('name.'), isFalse);
    expect(isValidMinecraftClientName(''), isFalse);

    final token = DownloadCancellationToken();
    var notified = 0;
    token.addListener(() => notified++);
    expect(token.isCancelled, isFalse);
    token.cancel();
    token.cancel();
    expect(token.isCancelled, isTrue);
    expect(notified, 1);
    expect(() => token.throwIfCancelled(), throwsA(isA<Exception>()));
  });

  test('loader tag colors keep Forge white and Fabric readable', () {
    final forgeLight = resourceTagAppearance('Forge 47.2.0', dark: false);
    final forgeDark = resourceTagAppearance('Forge 47.2.0', dark: true);
    expect(forgeLight.foreground, Colors.white);
    expect(forgeDark.foreground, Colors.white);

    final fabricLight = resourceTagAppearance('Fabric 0.15.11', dark: false);
    final fabricDark = resourceTagAppearance('Fabric 0.15.11', dark: true);
    expect(fabricLight.foreground, Colors.black);
    expect(fabricDark.foreground, Colors.white);

    final neoForge = resourceTagAppearance('NeoForge 21.1', dark: false);
    expect(neoForge.foreground, Colors.white);
  });
  test('resource loader tags are separated from version families', () {
    expect(resourceLoaderKey('Fabric'), 'fabric');
    expect(resourceLoaderKey('Forge'), 'forge');
    expect(resourceLoaderKey('NeoForge'), 'neoforge');
    expect(resourceLoaderKey('Quilt'), '');
    expect(resourceTagsWithoutLoaders(['fabric', 'technology', 'forge']), [
      'technology',
    ]);

    final versions = [
      '1.21.1',
      '1.21',
      '1.20.1',
      '24w14a',
      '1.21.2-pre1',
      '26.3',
      '26.3-rc1',
      '26.3-rc-2',
      '26.3-snapshot',
    ];
    expect(resourceVersionFamilies(versions), [
      '26.3',
      '1.21.2',
      '1.21.1',
      '1.21',
      '1.20.1',
    ]);
    final gameFamilies = resourceVersionsInFamily(versions, '26.3');
    expect(gameFamilies.first, '26.3');
    expect(
      gameFamilies,
      containsAll(['26.3-rc1', '26.3-rc-2', '26.3-snapshot']),
    );
    expect(resourceVersionsInFamily(versions, '1.21'), ['1.21']);
    expect(resourceVersionsInFamily(versions, '1.21.1'), ['1.21.1']);
    expect(resourceVersionsInFamily(versions, '1.21.2'), ['1.21.2-pre1']);
    expect(resourceVersionsInFamily(versions, '快照'), isEmpty);
    expect(resourceVersionFamily('24w14a'), '');
    expect(resourceVersionFamily('26.3-rc-2'), '26.3');
    expect(resourceVersionFamily('26.3-snapshot'), '26.3');
    expect(resourceVersionFamily('1.21-rc1'), '1.21');
    expect(resourceVersionFamily('1.21.1-pre2'), '1.21.1');
    expect(resourceVersionFamily('1.21_snapshot'), '1.21');
    expect(resourceVersionFamily('1.21.4'), '1.21.4');
    expect(resourceVersionMajorFamily('1.21.4'), '1.21');
    expect(resourceVersionGroups(['1.21', '1.21.1', '1.21.2', '1.20.1']), {
      '1.21': ['1.21.2', '1.21.1', '1.21'],
      '1.20': ['1.20.1'],
    });
    expect(
      normalizeResourceGameVersions([
        '1.21-rc1',
        '1.21',
        '24w14a',
        'fabric',
        '1.21.1-pre2',
        '1.21_snapshot',
      ]),
      ['1.21', '1.21.1'],
    );
    expect(inferMinecraftVersions('jei-1.20.1-15.2.0.27.jar'), ['1.20.1']);
    expect(inferMinecraftVersions('sodium-fabric-0.6.13+mc1.21.11.jar'), [
      '1.21.11',
    ]);
    expect(inferMinecraftVersions('neoforge-21.1.80'), isEmpty);
    expect(inferMinecraftVersions('forge-47.2.0'), isEmpty);
  });

  test('mod tags normalize across CurseForge and Modrinth spellings', () {
    expect(normalizeModTag('Adventure and RPG'), 'adventure');
    expect(normalizeModTag('adventure'), 'adventure');
    expect(knownModTagTranslation('Adventure and RPG'), '冒险');
    expect(knownModTagTranslation('adventure'), '冒险');
    expect(normalizeModTag('World Generation'), 'worldgen');
    expect(knownModTagTranslation('World Gen'), '世界生成');
    expect(normalizeModTag('API and Library'), 'library');
    expect(knownModTagTranslation('API and Library'), '前置库');
    expect(normalizeModTag('  Game-Mechanics  '), 'game mechanics');
    expect(knownModTagTranslation('Armor, Tools, and Weapons'), '装备');
    expect(knownModTagTranslation('Utility & QoL'), '实用工具与生活质量');
    expect(knownModTagTranslation('Applied Energistics 2'), '应用能源 2');
    expect(knownModTagTranslation('Tinker\'s Construct'), '匠魂');
  });

  test('mcmod API titles are cleaned and matched exactly', () {
    final response = jsonEncode([
      {
        'title': '钠 (Sodium)',
        'data': {'chinese_name': '钠', 'sub_name': 'Sodium'},
      },
      {
        'title': '[JEI] JEI物品管理器 (Just Enough Items)',
        'data': {'chinese_name': 'JEI物品管理器', 'sub_name': 'Just Enough Items'},
      },
    ]);
    expect(cleanChineseTitle('钠 (Sodium)'), '钠');
    expect(chineseTitleFromApiResponse(response, 'Sodium'), '钠');
    expect(
      chineseTitleFromApiResponse(response, 'Just Enough Items'),
      'JEI物品管理器',
    );
    expect(
      chineseTitleFromApiResponse(response, 'Just Enough Items (JEI)'),
      'JEI物品管理器',
    );
    expect(
      chineseTitleFromApiResponse(response, 'Just Enough Items [Fabric]'),
      'JEI物品管理器',
    );
    expect(chineseTitleFromApiResponse(response, 'JEI'), 'JEI物品管理器');
    expect(chineseTitleFromApiResponse(response, 'Create'), isNull);
    expect(normalizeMcmodTitleKey('  Just Enough Items '), 'just enough items');

    final lookup = chineseTitleLookupFromApiResponse(response, 'Sodium');
    expect(lookup?.chinese, '钠');
    expect(lookup?.aliases['sodium'], '钠');
    expect(lookup?.aliases['just enough items'], 'JEI物品管理器');
  });

  test('mcmod item entries are rejected or reduced to the mod name', () {
    const scrapedItemTitle = '(物品/方块) Meka工具 (Meka-Tool) - [Mek] 通用机械';

    expect(cleanChineseTitle(scrapedItemTitle), '通用机械');
    expect(cleanChineseTitle('[Mek] 通用机械'), '通用机械');
    expect(cleanChineseTitle('钠 (Sodium)'), '钠');

    // Pure wiki entry pages have no mod name to recover.
    expect(cleanChineseTitle('(物品/方块) Meka工具'), '');
    expect(cleanChineseTitle('(物品/方块) 富集铀锭 (Enriched Uranium Ingot)'), '');
    expect(cleanChineseTitle('(多方块结构) 聚变反应堆'), '');
    expect(cleanChineseTitle('(教程) 通用机械入门'), '');
    expect(cleanChineseTitle('（物品/方块）Meka工具'), '');
    expect(isValidChineseModTitle('(物品/方块) Meka工具'), isFalse);
    expect(isValidChineseModTitle('通用机械'), isTrue);
    expect(cleanChineseTitle('模' * 21), '');

    final lookup = chineseTitleLookupFromApiResponse(
      jsonEncode([
        {
          'title': scrapedItemTitle,
          'data': {
            'chinese_name': scrapedItemTitle,
            'sub_name': 'Mekanism',
            'abbr': 'Mek',
          },
        },
      ]),
      'Mekanism',
    );
    expect(lookup?.chinese, '通用机械');

    final itemOnly = jsonEncode([
      {
        'title': '(物品/方块) 富集铀锭 (Enriched Uranium Ingot)',
        'data': {
          'chinese_name': '(物品/方块) 富集铀锭',
          'sub_name': 'Enriched Uranium Ingot',
        },
      },
    ]);
    expect(
      chineseTitleFromApiResponse(itemOnly, 'Enriched Uranium Ingot'),
      isNull,
    );
  });

  test('mcmod semaphore caps concurrent requests at two', () async {
    final semaphore = AsyncSemaphore(2);
    var active = 0;
    var maximum = 0;
    Future<void> work() => semaphore.withPermit(() async {
      active++;
      maximum = active > maximum ? active : maximum;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      active--;
    });
    await Future.wait(List<Future<void>>.generate(8, (_) => work()));
    expect(maximum, 2);
  });

  test('java version failures are recognized from launch output', () {
    expect(
      looksLikeJavaVersionFailure(
        'java.lang.UnsupportedClassVersionError: class file version',
      ),
      isTrue,
    );
    expect(
      looksLikeJavaVersionFailure("Unrecognized VM option 'UseBiasedLocking'"),
      isTrue,
    );
    expect(
      looksLikeJavaVersionFailure('Minecraft crashed because of a mod'),
      isFalse,
    );
  });

  test('client delete stays inside the versions directory', () async {
    final root =
        '${Directory.systemTemp.path}${Platform.pathSeparator}versions';
    expect(
      isPathInsideDirectory('$root${Platform.pathSeparator}MyClient', root),
      isTrue,
    );
    expect(isPathInsideDirectory(root, root), isFalse);
    expect(
      isPathInsideDirectory(
        '${root}_backup${Platform.pathSeparator}MyClient',
        root,
      ),
      isFalse,
    );

    final temporary = await Directory.systemTemp.createTemp('launcher-delete-');
    addTearDown(() => temporary.delete(recursive: true));
    final minecraft = Directory(
      '${temporary.path}${Platform.pathSeparator}.minecraft',
    );
    final versions = Directory(
      '${minecraft.path}${Platform.pathSeparator}versions',
    );
    final target = Directory(
      '${versions.path}${Platform.pathSeparator}DeleteProbe',
    );
    final sibling = Directory(
      '${versions.path}${Platform.pathSeparator}KeepProbe',
    );
    await target.create(recursive: true);
    await sibling.create(recursive: true);
    await File('${target.path}${Platform.pathSeparator}client.jar')
        .writeAsBytes(const [1, 2, 3]);

    await deleteMinecraftClientDirectory(
      minecraftPath: minecraft.path,
      clientPath: target.path,
    );
    expect(await target.exists(), isFalse);
    expect(await sibling.exists(), isTrue);
    await expectLater(
      deleteMinecraftClientDirectory(
        minecraftPath: minecraft.path,
        clientPath: temporary.path,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('missing mandatory mod dependencies are extracted from logs', () {
    final dependencies = missingModDependencies(
      "Mod ID: 'kotlinforforge', Requested by: 'combine', "
      "Expected range: ' ', Actual version: '[MISSING]'\n"
      "Mod ID: 'anothermod', Requested by: 'x', "
      "Expected range: ' ', Actual version: '[MISSING]'",
    );
    expect(dependencies, containsAll(['kotlinforforge', 'anothermod']));
    expect(missingModDependencies('no missing deps'), isEmpty);
  });

  test('minecraft UTF-8 output keeps the NeoForge token mask readable', () {
    final decoded = decodeMinecraftProcessOutput(
      utf8.encode('--accessToken, ❄❄❄❄❄❄❄❄'),
    );
    expect(decoded, contains('❄❄❄❄❄❄❄❄'));
    expect(decoded, isNot(contains('鉂')));
    expect(decoded, isNot(contains('�')));
  });

  test('Iris and Sodium class mismatches produce an actionable hint', () {
    final hint = modCompatibilityIssue(
      "java.lang.ClassNotFoundException: "
      "net.caffeinemc.mods.sodium.client.gui.SodiumGameOptions\$PerformanceSettings "
      "org.spongepowered.asm.mixin.transformer.throwables."
      "MixinPreProcessorException: Attach error for "
      "mixins.iris.compat.sodium.json:MixinRenderSectionManager",
    );
    expect(hint, isNotNull);
    expect(hint, contains('Sodium 0.6.13'));
    expect(hint, contains('Iris'));
    expect(modCompatibilityIssue('Minecraft exited normally'), isNull);
  });

  test('classpath deduplication prevents NeoForge duplicate-key crashes', () {
    final unique = deduplicateClassPathEntries([
      r'D:\PCL\.minecraft\libraries\gson.jar',
      r'D:\PCL\.minecraft\libraries\gson.jar',
      r'D:\PCL\.minecraft\libraries\guava.jar',
    ]);
    expect(unique, hasLength(2));
    expect(unique.first, endsWith('gson.jar'));
    expect(unique.last, endsWith('guava.jar'));
  });

  test('debug log window arguments and token redaction', () {
    expect(
      debugLogWindowPathFromArgs(['--debug-log-window=C:\\logs\\launcher.log']),
      r'C:\logs\launcher.log',
    );
    expect(
      debugLogWindowPathFromArgs(['--debug-log-window', r'C:\logs\l.log']),
      r'C:\logs\l.log',
    );
    final redacted = redactLogSecrets(
      '--accessToken abcdef --access_token=xyz '
      'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature12345',
    );
    expect(redacted, isNot(contains('abcdef')));
    expect(redacted, isNot(contains('xyz')));
    expect(redacted, contains('--accessToken ***'));
  });

  test('inherited client JAR is used in the NeoForge ignore list', () {
    expect(
      replaceIgnoreListClientJar(
        argument: r'-DignoreList=client-extra,NeoForgeTest.jar',
        versionName: 'NeoForgeTest',
        clientJarName: '1.21.1.jar',
      ),
      r'-DignoreList=client-extra,1.21.1.jar',
    );
    expect(
      replaceIgnoreListClientJar(
        argument: '--username',
        versionName: 'NeoForgeTest',
        clientJarName: '1.21.1.jar',
      ),
      '--username',
    );
  });

  test('NeoForge installer metadata is rewritten to the Forge CDN', () async {
    final temporary = await Directory.systemTemp.createTemp('neoforge-cdn-');
    addTearDown(() => temporary.delete(recursive: true));
    final source = File(
      '${temporary.path}${Platform.pathSeparator}neoforge-installer.jar',
    );
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'install_profile.json',
          '{"url":"https://maven.neoforged.net/releases/'
              'net/neoforged/neoforge/21.1.262/x.jar"}',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'META-INF/MANIFEST.MF',
          'Manifest-Version: 1.0\nMain-Class: cpw.mods.installer.Main\n',
        ),
      )
      ..addFile(ArchiveFile('data/binary.bin', 3, const [0xff, 0x00, 0x6d]));
    await source.writeAsBytes(ZipEncoder().encode(archive)!);

    final mirrored = await applyNeoForgeCdnMirror(source);
    expect(mirrored.path, endsWith('-cdn.jar'));
    final decoded = ZipDecoder().decodeBytes(await mirrored.readAsBytes());
    final profile = decoded.files.firstWhere(
      (file) => file.name == 'install_profile.json',
    );
    final text = utf8.decode(profile.content as List<int>);
    expect(text, contains('https://neoforged.forgecdn.net/releases/'));
    expect(text, isNot(contains('maven.neoforged.net')));
    expect(
      decoded.files.any((file) => file.name == 'META-INF/MANIFEST.MF'),
      isTrue,
    );
    final binary = decoded.files.firstWhere(
      (file) => file.name == 'data/binary.bin',
    );
    expect(binary.content, const [0xff, 0x00, 0x6d]);
  });

  test('standalone log tail shows the end of the file', () async {
    final temporary = await Directory.systemTemp.createTemp('launcher-tail-');
    addTearDown(() => temporary.delete(recursive: true));
    final file = File('${temporary.path}${Platform.pathSeparator}launcher.log');
    await file.writeAsString('old line\nnew line');
    final tail = await readLogTail(file.path, maxBytes: 8);
    expect(tail.truncated, isTrue);
    expect(tail.content, contains('new line'));
  });

  test('installer output tolerates non-UTF8 and split byte chunks', () async {
    final output = await readProcessOutput(
      Stream<List<int>>.fromIterable([
        [0x81, 0x40],
        [0xC3, 0x28],
      ]),
    );
    expect(output, isA<String>());
  });

  test('latest game log is read from the client logs folder', () async {
    final temporary = await Directory.systemTemp.createTemp('launcher-log-');
    addTearDown(() => temporary.delete(recursive: true));
    final logs = Directory('${temporary.path}${Platform.pathSeparator}logs');
    await logs.create(recursive: true);
    await File('${logs.path}${Platform.pathSeparator}latest.log')
        .writeAsString('first line\nsecond line\n');

    final snapshot = await readMinecraftLatestLog(temporary.path);
    expect(snapshot.path, endsWith('latest.log'));
    expect(snapshot.content, contains('first line'));
    expect(snapshot.content, contains('second line'));
    expect(snapshot.truncated, isFalse);
  });

  test(
    'DownloadManager keeps eight active jobs and drains its queue',
    () async {
      final manager = DownloadManager();
      addTearDown(manager.dispose);
      var running = 0;
      var peak = 0;
      var completed = 0;
      final futures = <Future<void>>[];
      for (var index = 0; index < 20; index++) {
        final job = DownloadJob(
          id: 'job-$index',
          label: 'file-$index.jar',
          groupLabel: 'Test client',
          kind: '游戏版本',
          path: '/tmp/file-$index.jar',
          totalBytes: 100,
        );
        futures.add(
          manager.enqueue(job, (job) async {
            running++;
            if (running > peak) peak = running;
            expect(manager.activeCount, lessThanOrEqualTo(8));
            await Future<void>.delayed(const Duration(milliseconds: 15));
            running--;
            completed++;
          }),
        );
      }
      await Future.wait(futures);
      expect(peak, 8);
      expect(completed, 20);
      expect(manager.activeCount, 0);
      expect(manager.queuedCount, 0);
      final group = manager.groups.single;
      expect(group.totalJobs, 20);
      expect(group.completedJobs, 20);
      expect(group.totalBytes, 2000);
      expect(group.receivedBytes, 2000);
      expect(group.progress, 1.0);
    },
  );
  test('mod search keeps results with at least 50 percent relevance', () {
    expect(resourceSearchMatchesQuery('fabric api', 'Fabric API', ''), isTrue);
    expect(
      resourceSearchMatchesQuery('fabric api', 'Fabric', 'API utilities'),
      isTrue,
    );
    expect(
      resourceSearchMatchesQuery('fabric api', 'Unrelated Mod', 'API helper'),
      isFalse,
    );
    expect(resourceSearchMatchesQuery('', 'Anything', ''), isTrue);
    expect(
      resourceSearchMatchesQuery('farmers delight', "Farmer's Delight", ''),
      isTrue,
    );
    expect(
      resourceSearchMatchesQuery('farmers delight', 'Farmer', ''),
      isFalse,
    );
  });
  test('version inference never trusts the folder name', () async {
    final temporary = await Directory.systemTemp.createTemp('launcher-folder-');
    addTearDown(() => temporary.delete(recursive: true));
    final root = Directory(
      '${temporary.path}${Platform.pathSeparator}.minecraft',
    );
    final versionDirectory = Directory(
      '${root.path}${Platform.pathSeparator}versions'
      '${Platform.pathSeparator}1.20.1',
    );
    await versionDirectory.create(recursive: true);
    await File(
      '${versionDirectory.path}${Platform.pathSeparator}1.20.1.json',
    ).writeAsString(jsonEncode({'id': 'modpack-custom-id', 'type': 'release'}));

    final versions = await getLocalVersions(root.path);
    expect(versions, hasLength(1));
    expect(versions.single.id, 'modpack-custom-id');
    expect(versions.single.minecraftVersion, isNull);
    expect(versions.single.loaderVersion, isNull);
  });

  test('client title stays the folder name while Minecraft stays a tag', () {
    const version = LauncherVersion(
      name: '1.21.1-NeoForge_21.1.234',
      path: r'C:\games\.minecraft\versions\1.21.1-NeoForge_21.1.234',
      kind: VersionKind.modded,
      minecraftPath: r'C:\games\.minecraft',
      minecraftVersion: '1.21.1',
    );
    expect(version.name, '1.21.1-NeoForge_21.1.234');
    expect(version.minecraftVersion, '1.21.1');
    expect(lastPathSegment(version.path), version.name);
  });

  test('version scanning keeps the source root and jar lookup tolerates folder/id mismatch', () async {
    final temporary = await Directory.systemTemp.createTemp('launcher-source-');
    addTearDown(() => temporary.delete(recursive: true));
    final root = Directory(
      '${temporary.path}${Platform.pathSeparator}.minecraft',
    );
    final versionDirectory = Directory(
      '${root.path}${Platform.pathSeparator}versions'
      '${Platform.pathSeparator}MyClient',
    );
    await versionDirectory.create(recursive: true);
    await File(
      '${versionDirectory.path}${Platform.pathSeparator}MyClient.json',
    ).writeAsString(
      jsonEncode({'id': 'custom-id', 'type': 'release', 'assets': 'legacy'}),
    );
    await File('${versionDirectory.path}${Platform.pathSeparator}MyClient.jar')
        .writeAsBytes(const [0]);

    final versions = await getLocalVersions(root.path);
    expect(versions, hasLength(1));
    expect(
      Platform.isWindows
          ? versions.single.minecraftPath.toLowerCase()
          : versions.single.minecraftPath,
      Platform.isWindows ? root.path.toLowerCase() : root.path,
    );

    final candidates = minecraftClientJarCandidates(
      versionDirectory: versions.single.directoryPath,
      minecraftPath: versions.single.minecraftPath,
      versionId: versions.single.id,
      config: {'id': 'custom-id', 'inheritsFrom': '1.20.1'},
    );
    final normalized = candidates
        .map((path) => path.replaceAll('/', Platform.pathSeparator))
        .toList();
    expect(
      normalized.any(
        (path) =>
            path.endsWith('MyClient${Platform.pathSeparator}MyClient.jar'),
      ),
      isTrue,
    );
    expect(
      normalized.any(
        (path) => path.endsWith(
          'versions${Platform.pathSeparator}1.20.1'
          '${Platform.pathSeparator}1.20.1.jar',
        ),
      ),
      isTrue,
    );
  });

  test('custom names resolve loader and Minecraft versions from inheritance, libraries and arguments', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'launcher-identity-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final root = Directory(
      '${temporary.path}${Platform.pathSeparator}.minecraft',
    );
    final versionsDirectory = Directory(
      '${root.path}${Platform.pathSeparator}versions',
    );
    await versionsDirectory.create(recursive: true);

    Future<void> writeVersion(
      String folderName,
      Map<String, dynamic> config,
    ) async {
      final directory = Directory(
        '${versionsDirectory.path}${Platform.pathSeparator}$folderName',
      );
      await directory.create(recursive: true);
      await File('${directory.path}${Platform.pathSeparator}$folderName.json')
          .writeAsString(jsonEncode(config));
    }

    await writeVersion('1.21.1', {
      'id': '1.21.1',
      'type': 'release',
      'libraries': <Object>[],
    });
    await writeVersion('CustomNeo', {
      'id': 'CustomNeo',
      'type': 'release',
      'inheritsFrom': '1.21.1',
      'mainClass': 'cpw.mods.bootstraplauncher.BootstrapLauncher',
      'arguments': {
        'game': [
          '--fml.neoForgeVersion',
          '21.1.262',
          '--fml.mcVersion',
          '1.21.1',
        ],
      },
    });
    await writeVersion('CustomNeoLib', {
      'id': 'CustomNeoLib',
      'type': 'release',
      'inheritsFrom': '1.21.1',
      'libraries': [
        {'name': 'net.neoforged:neoforge:21.1.262'},
      ],
    });
    await writeVersion('1.20.1-forge-47.2.0', {
      'id': '1.20.1-forge-47.2.0',
      'type': 'release',
      'libraries': [
        {'name': 'net.minecraftforge:forge:1.20.1-47.2.0'},
      ],
      'arguments': {
        'game': ['--fml.forgeVersion', '47.2.0', '--fml.mcVersion', '1.20.1'],
      },
    });
    await writeVersion('CustomForge', {
      'id': 'CustomForge',
      'type': 'release',
      'inheritsFrom': '1.20.1-forge-47.2.0',
    });
    // A modpack patch id (1.5.4) must not win over the Forge 47.2.0 artifact
    // line, which identifies Minecraft 1.20.1.
    await writeVersion('1.5.4', {
      'id': '1.5.4',
      'type': 'release',
      'libraries': [
        {'name': 'net.minecraftforge:forge:47.2.0'},
      ],
    });
    await writeVersion('InheritsOverride', {
      'id': 'InheritsOverride',
      'type': 'release',
      'inheritsFrom': '1.20.1',
      'libraries': [
        {'name': 'net.minecraftforge:forge:47.2.0'},
      ],
    });
    await writeVersion('fabric-loader-0.16.9-1.21.1', {
      'id': 'fabric-loader-0.16.9-1.21.1',
      'type': 'release',
      'libraries': [
        {'name': 'net.fabricmc:fabric-loader:0.16.9'},
      ],
    });
    await writeVersion('CustomFabric', {
      'id': 'CustomFabric',
      'type': 'release',
      'inheritsFrom': 'fabric-loader-0.16.9-1.21.1',
    });
    await writeVersion('MysteryClient', {
      'id': 'MysteryClient',
      'type': 'release',
    });

    final versions = await getLocalVersions(root.path);
    MinecraftVersion find(String id) =>
        versions.firstWhere((version) => version.id == id);

    final neo = find('CustomNeo');
    expect(neo.minecraftVersion, '1.21.1');
    expect(neo.loaderType, 'NeoForge');
    expect(neo.loaderVersion, '21.1.262');

    final neoLib = find('CustomNeoLib');
    expect(neoLib.minecraftVersion, '1.21.1');
    expect(neoLib.loaderType, 'NeoForge');
    expect(neoLib.loaderVersion, '21.1.262');

    final forge = find('CustomForge');
    expect(forge.minecraftVersion, '1.20.1');
    expect(forge.loaderType, 'Forge');
    expect(forge.loaderVersion, '47.2.0');

    final patchPack = find('1.5.4');
    expect(patchPack.minecraftVersion, '1.20.1');
    expect(patchPack.loaderType, 'Forge');
    expect(patchPack.loaderVersion, '47.2.0');

    final inheritsOverride = find('InheritsOverride');
    expect(inheritsOverride.minecraftVersion, '1.20.1');

    final fabric = find('CustomFabric');
    expect(fabric.minecraftVersion, '1.21.1');
    expect(fabric.loaderType, 'Fabric');
    expect(fabric.loaderVersion, '0.16.9');

    // A renamed folder with no metadata must not be reported as a Minecraft
    // version named after the folder.
    expect(find('MysteryClient').minecraftVersion, isNull);
  });

  test('only the active .minecraft source is scanned', () async {
    final temporary = await Directory.systemTemp.createTemp('launcher-active-');
    addTearDown(() => temporary.delete(recursive: true));
    Future<String> createRoot(String folder, String versionId) async {
      final root = Directory(
        '${temporary.path}${Platform.pathSeparator}$folder',
      );
      final versionDirectory = Directory(
        '${root.path}${Platform.pathSeparator}versions'
        '${Platform.pathSeparator}$versionId',
      );
      await versionDirectory.create(recursive: true);
      await File(
        '${versionDirectory.path}${Platform.pathSeparator}$versionId.json',
      ).writeAsString(jsonEncode({'id': versionId, 'type': 'release'}));
      return root.path;
    }

    final first = await createRoot('first', 'FirstClient');
    final second = await createRoot('second', 'SecondClient');
    final versions = await loadActiveMinecraftVersions(
      minecraftPath: second,
      sources: [first, second],
    );
    expect(versions.map((version) => version.id), ['SecondClient']);
    expect(resolveActiveMinecraftSource('', [first, second]), first);
    expect(resolveActiveMinecraftSource('', const []), isNull);
  });

  testWidgets('home keeps client name and switcher without a config card', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BlockLauncherApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('当前客户端'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('当前客户端')))
          .textTheme
          .bodyMedium
          ?.fontFamily,
      'SourceHanSansSC',
    );
    expect(find.text('尚未选择客户端'), findsOneWidget);
    expect(find.text('选择客户端'), findsOneWidget);
    expect(find.text('开始游戏'), findsOneWidget);
    expect(find.text('切换'), findsOneWidget);
    expect(find.text('游戏配置'), findsNothing);
    expect(find.byTooltip('查看客户端配置'), findsOneWidget);
    expect(find.text('登录方式'), findsOneWidget);
    expect(find.text('本地档案'), findsOneWidget);
    expect(find.text('玩家：Player'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('登录方式'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('账号管理'), findsOneWidget);
    expect(find.text('账号列表'), findsOneWidget);
    expect(find.text('添加账户'), findsOneWidget);

    await tester.tap(find.text('添加账户'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('本地档案'), findsOneWidget);
    expect(find.text('Microsoft 登录'), findsOneWidget);
    expect(find.text('第三方验证'), findsOneWidget);
    expect(find.textContaining('设备码'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('取消'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('返回'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('选择客户端'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('切换客户端'), findsOneWidget);
    expect(find.text('游戏配置'), findsNothing);
    expect(find.text('下载 Minecraft'), findsOneWidget);
    expect(find.text('账号'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home compact layout keeps switcher and config button', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BlockLauncherApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('选择客户端'), findsOneWidget);
    expect(find.text('切换'), findsOneWidget);
    expect(find.byTooltip('查看客户端配置'), findsOneWidget);
    expect(find.text('登录方式'), findsOneWidget);
    expect(find.text('游戏配置'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings no longer contains launch configuration', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BlockLauncherApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('设置'));
    await _finishPageTransition(tester);

    expect(find.text('Java 管理'), findsNWidgets(2));
    expect(find.text('启动配置'), findsNothing);
    expect(find.text('登录方式'), findsNothing);
    expect(find.text('选择启动版本'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('download task page opens from the sidebar', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BlockLauncherApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('下载任务'));
    await _finishPageTransition(tester);

    expect(find.text('当前没有下载任务'), findsOneWidget);
    expect(find.text('客户端与资源文件按任务分组显示；每组包含总进度与速度，文件进度在组内展开。'), findsOneWidget);
    expect(find.text('取消当前下载'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('version management shows only the current source entry', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BlockLauncherApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('版本管理'));
    await _finishPageTransition(tester);

    expect(find.text('客户端来源'), findsNWidgets(2));
    expect(find.text('尚未选择 .minecraft 文件夹'), findsOneWidget);
    expect(find.text('点击添加文件夹'), findsOneWidget);
    expect(find.text('添加来源'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('java management opens inside the settings tab', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const BlockLauncherApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('设置'));
    await _finishPageTransition(tester);

    await tester.ensureVisible(find.text('管理 Java'));
    await tester.pump();
    await tester.tap(find.text('管理 Java'));
    await tester.pumpAndSettle();

    // The embedded page keeps the launcher shell: sidebar entries stay visible.
    expect(find.text('Java 管理'), findsOneWidget);
    expect(find.text('下载任务'), findsOneWidget);
    expect(find.text('版本管理'), findsOneWidget);
    expect(find.byTooltip('返回设置'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('返回设置'));
    await tester.pumpAndSettle();
    expect(find.text('全局游戏默认设置'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
