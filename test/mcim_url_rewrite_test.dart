import 'dart:convert';
import 'dart:typed_data';

import 'package:baogan_craft_launcher/services/network/models.dart';
import 'package:baogan_craft_launcher/services/network/modrinth_version_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(Object payload) =>
    Uint8List.fromList(utf8.encode(jsonEncode(payload)));

void main() {
  test('MCIM base URLs match the documented prefixes', () {
    expect(mcimCurseForgeBase, 'https://mod.mcimirror.top/curseforge');
    expect(mcimModrinthBase, 'https://mod.mcimirror.top/modrinth');
  });

  test('rewrites only the documented CDN hosts', () {
    expect(
      mcimMirrorUrl('https://cdn.modrinth.com/data/AABB/jei.jar?x=1'),
      'https://mod.mcimirror.top/data/AABB/jei.jar?x=1',
    );
    expect(
      mcimMirrorUrl('https://edge.forgecdn.net/files/123/456/jei.jar'),
      'https://mod.mcimirror.top/files/123/456/jei.jar',
    );
    expect(
      mcimMirrorUrl('https://mediafilez.forgecdn.net/files/123/456/jei.jar'),
      'https://mediafilez.forgecdn.net/files/123/456/jei.jar',
    );
    expect(
      mcimMirrorUrl('https://example.invalid/jei.jar'),
      'https://example.invalid/jei.jar',
    );
  });

  test('isolate parser rewrites file URLs before returning models', () {
    final versions = parseModrinthVersionPage(
      _bytes(<Object>[
        <String, Object?>{
          'id': 'version-1',
          'name': 'JEI',
          'version_type': 'release',
          'downloads': 1,
          'game_versions': <String>['1.21.1'],
          'loaders': <String>['neoforge'],
          'files': <Object>[
            <String, Object?>{
              'filename': 'jei.jar',
              'url': 'https://cdn.modrinth.com/data/AABB/jei.jar',
            },
          ],
        },
      ]),
    );
    expect(versions.single.files.single.url, contains(mcimApiHost));
    expect(versions.single.files.single.url, contains('/data/AABB/jei.jar'));
  });

  test('mirror host is trusted for downloads', () {
    expect(
      isTrustedResourceHost(
        Uri.parse('https://mod.mcimirror.top/files/123/456/jei.jar'),
      ),
      isTrue,
    );
  });
}
