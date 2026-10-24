import 'package:baogan_craft_launcher/pages/downloads/controllers/resource_download_controller.dart';
import 'package:baogan_craft_launcher/services/installer/version_models.dart';
import 'package:baogan_craft_launcher/services/network/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

ModrinthVersion _version({
  required String id,
  required String gameVersion,
  required String loader,
  required int downloads,
  bool withFile = true,
}) {
  return ModrinthVersion(
    name: '$id-$loader',
    versionType: 'release',
    downloads: downloads,
    gameVersions: <String>[gameVersion],
    loaders: <String>[loader],
    files: withFile
        ? <ModrinthFile>[
            ModrinthFile(
              filename: '$id.jar',
              url: 'https://example.invalid/$id.jar',
            ),
          ]
        : const <ModrinthFile>[],
    versionId: id,
  );
}

void main() {
  final project = ModrinthProject(
    id: 'jei',
    title: 'JEI',
    description: 'Item viewer',
    category: DownloadCategory.mods,
    downloads: 1,
    followers: 1,
    versions: <ModrinthVersion>[
      _version(
        id: 'forge-1201',
        gameVersion: '1.20.1',
        loader: 'forge',
        downloads: 10,
      ),
      _version(
        id: 'neoforge-1211',
        gameVersion: '1.21.1',
        loader: 'neoforge',
        downloads: 20,
      ),
      _version(
        id: 'fabric-1211',
        gameVersion: '1.21.1',
        loader: 'fabric',
        downloads: 30,
      ),
      _version(
        id: 'neoforge-no-file',
        gameVersion: '1.21.1',
        loader: 'neoforge',
        downloads: 40,
        withFile: false,
      ),
    ],
    tags: const <String>[],
  );

  const neoClient = MinecraftVersion(
    id: 'NeoClient',
    type: 'release',
    directoryPath: r'C:\clients\NeoClient',
    minecraftPath: r'C:\clients',
    minecraftVersion: '1.21.1',
    loaderType: 'NeoForge',
  );

  test('matches game version, loader and a real downloadable file', () {
    final controller = ResourceDownloadController();
    addTearDown(controller.dispose);

    final matched = controller.matchVersionForClient(project, neoClient);

    expect(matched?.versionId, 'neoforge-1211');
    expect(matched?.files.single.url, contains('neoforge-1211.jar'));
  });

  test('preferred version is only used when it matches the client', () {
    final controller = ResourceDownloadController();
    addTearDown(controller.dispose);
    final fabric = project.versions.firstWhere(
      (version) => version.versionId == 'fabric-1211',
    );

    final matched = controller.matchVersionForClient(
      project,
      neoClient,
      preferred: fabric,
    );

    expect(matched?.versionId, 'neoforge-1211');
  });

  test('returns null when no file supports the selected client', () {
    final controller = ResourceDownloadController();
    addTearDown(controller.dispose);
    const other = MinecraftVersion(
      id: 'Other',
      type: 'release',
      directoryPath: r'C:\clients\Other',
      minecraftPath: r'C:\clients',
      minecraftVersion: '1.21.1',
      loaderType: 'Quilt',
    );
    expect(controller.matchVersionForClient(project, other), isNull);
  });
}
