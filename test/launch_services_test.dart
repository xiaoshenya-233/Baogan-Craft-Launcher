import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:baogan_craft_launcher/services/java/java_service.dart';
import 'package:baogan_craft_launcher/services/launcher/game_launcher.dart';

void main() {
  const diagnostics = MinecraftLaunchDiagnostics();

  test('diagnoses missing mod dependencies', () async {
    final diagnosis = await diagnostics.diagnose(
      versionId: '1.21.1',
      exitCode: 1,
      output:
          "Mod ID: 'kotlinforforge' requested by mod create [MISSING]\n"
          'Some other output',
      javaRuntime: null,
      loadRequiredJavaMajor: () async => null,
    );
    expect(diagnosis.kind, LaunchFailureKind.missingMods);
    expect(diagnosis.missingDependencies, ['kotlinforforge']);
    expect(diagnosis.snippet, isNotEmpty);
  });

  test('diagnoses known Iris and Sodium incompatibility', () async {
    final diagnosis = await diagnostics.diagnose(
      versionId: '1.21.1',
      exitCode: 1,
      output:
          'java.lang.ClassNotFoundException: '
          'net.caffeinemc.mods.sodium.client.gui.options.storage.'
          'SodiumGameOptions\$PerformanceSettings\n'
          'MixinRenderSectionManager failed\n'
          'mixins.iris.json',
      javaRuntime: null,
      loadRequiredJavaMajor: () async => null,
    );
    expect(diagnosis.kind, LaunchFailureKind.incompatibleMods);
    expect(diagnosis.compatibilityIssue, contains('Iris 与 Sodium 版本不兼容'));
  });

  test('diagnoses Java version failures from output', () async {
    final diagnosis = await diagnostics.diagnose(
      versionId: '1.20.4',
      exitCode: 1,
      output:
          'UnsupportedClassVersionError: net/minecraft/client/main/Main '
          'has been compiled by a more recent version of the Java Runtime',
      javaRuntime: null,
      loadRequiredJavaMajor: () async => null,
    );
    expect(diagnosis.kind, LaunchFailureKind.javaVersion);
    expect(diagnosis.javaIssue, isTrue);
  });

  test('detects required/actual Java major mismatch', () async {
    const runtime = JavaRuntime(
      executable: r'C:\Java\bin\java.exe',
      majorVersion: 8,
      displayName: 'Java 8',
    );
    expect(
      await diagnostics.isLikelyJavaVersionFailure(
        output: '',
        javaRuntime: runtime,
        loadRequiredJavaMajor: () async => 17,
      ),
      isTrue,
    );
    expect(
      await diagnostics.isLikelyJavaVersionFailure(
        output: 'Minecraft crashed with an exception',
        javaRuntime: runtime,
        loadRequiredJavaMajor: () async => 17,
      ),
      isTrue,
    );
    expect(
      await diagnostics.isLikelyJavaVersionFailure(
        output: 'Minecraft exited normally',
        javaRuntime: runtime,
        loadRequiredJavaMajor: () async => 17,
      ),
      isFalse,
    );
  });

  test('falls back to an unknown diagnosis when no rule matches', () async {
    final diagnosis = await diagnostics.diagnose(
      versionId: '1.21.1',
      exitCode: 2,
      output: 'A generic crash without a known signature',
      javaRuntime: null,
      loadRequiredJavaMajor: () async => null,
    );
    expect(diagnosis.kind, LaunchFailureKind.unknown);
    expect(diagnosis.javaIssue, isFalse);
  });

  test('runner removes temporary natives and reports cleanup errors', () async {
    const runner = MinecraftLaunchRunner();
    final directory = await Directory.systemTemp.createTemp('launch_natives_');
    expect(await directory.exists(), isTrue);

    final error = await runner.cleanupNatives(directory);
    expect(error, isNull);
    expect(await directory.exists(), isFalse);
  });
}
