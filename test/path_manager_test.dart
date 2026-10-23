import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:baogan_craft_launcher/core/path_manager.dart';

void main() {
  test('launcher_config.json stays next to the executable', () {
    final executable = File(Platform.resolvedExecutable);
    final expected = File(
      '${executable.parent.path}${Platform.pathSeparator}'
      '${PathManager.launcherConfigFileName}',
    );

    expect(PathManager.instance.rootConfigFile.path, expected.path);
  });

  test('no data roots are exposed before the user selects a directory', () {
    expect(PathManager.instance.isConfigured, isFalse);
    expect(PathManager.instance.dataRoot, isNull);
    expect(PathManager.instance.gameRoot, isNull);
    expect(PathManager.instance.cacheDirectory, isNull);
    expect(PathManager.instance.logsDirectory, isNull);
  });
}
