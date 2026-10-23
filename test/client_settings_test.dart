import 'dart:io';

import 'package:baogan_craft_launcher/services/installer/client_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client settings default to following the global configuration', () async {
    final directory = await Directory.systemTemp.createTemp('client-settings-');
    addTearDown(() => directory.delete(recursive: true));

    final loaded = await ClientLaunchSettings.load(directory.path);
    expect(loaded.java, ClientLaunchSettings.followGlobal);
    expect(loaded.usesOwnJava, isFalse);
    expect(loaded.ownMemoryGb, isNull);
    expect(loaded.isIndependent, isFalse);
  });

  test('client settings store an independent java and memory', () async {
    final directory = await Directory.systemTemp.createTemp('client-settings-');
    addTearDown(() => directory.delete(recursive: true));

    const settings = ClientLaunchSettings(
      java: r'C:\Java\bin\java.exe',
      memoryGb: 6,
    );
    await settings.save(directory.path);

    expect(await ClientLaunchSettings.fileFor(directory.path).exists(), isTrue);
    final loaded = await ClientLaunchSettings.load(directory.path);
    expect(loaded.usesOwnJava, isTrue);
    expect(loaded.ownMemoryGb, 6);
    expect(loaded.isIndependent, isTrue);

    // Switching Java back to "follow global" keeps the memory override.
    final back = loaded.copyWith(java: ClientLaunchSettings.followGlobal);
    expect(back.usesOwnJava, isFalse);
    expect(back.ownMemoryGb, 6);
    expect(back.isIndependent, isTrue);
  });
}
