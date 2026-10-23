import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:baogan_craft_launcher/core/preferences_store.dart';

void main() {
  test('concurrent writes keep every key', () async {
    final directory = await Directory.systemTemp.createTemp('launcher-prefs-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}launcher.json',
    );
    final store = PreferencesStore(fileProvider: () => file);

    // Controllers save independently, so all of these run at the same time.
    await Future.wait([
      store.write('launchAuthMode', 'offline'),
      store.write('offlinePlayerName', 'Steve'),
      store.write('preferredDownloadVersionId', '1.21.1'),
      store.write('minecraftSources', ['C:/mc']),
    ]);

    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(decoded['launchAuthMode'], 'offline');
    expect(decoded['offlinePlayerName'], 'Steve');
    expect(decoded['preferredDownloadVersionId'], '1.21.1');
    expect(decoded['minecraftSources'], ['C:/mc']);
  });

  test('later writes still run after an unreadable config', () async {
    final directory = await Directory.systemTemp.createTemp('launcher-prefs-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}launcher.json',
    );
    await file.writeAsString('not json');
    final store = PreferencesStore(fileProvider: () => file);

    await expectLater(
      store.write('launchAuthMode', 'offline'),
      throwsA(isA<FormatException>()),
    );

    await file.writeAsString('{}');
    await store.write('launchAuthMode', 'microsoft');
    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(decoded['launchAuthMode'], 'microsoft');
  });
}
