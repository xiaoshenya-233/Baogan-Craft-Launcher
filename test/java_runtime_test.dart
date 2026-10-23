import 'package:flutter_test/flutter_test.dart';
import 'package:baogan_craft_launcher/services/java/java_service.dart';

void main() {
  test('parses legacy and modern Java major versions', () {
    expect(parseJavaMajorVersion('java version "1.8.0_265"'), 8);
    expect(parseJavaMajorVersion('openjdk version "17.0.1" 2021-10-19'), 17);
    expect(parseJavaMajorVersion('openjdk version "11" 2018-09-25'), 11);
    expect(parseJavaMajorVersion('java version "21.0.2" 2024-01-16'), 21);
    expect(parseJavaMajorVersion('no version here'), 0);
  });

  test('parses bare version strings from release files', () {
    expect(parseJavaVersionNumber('17.0.10'), 17);
    expect(parseJavaVersionNumber('1.8.0_402'), 8);
    expect(parseJavaVersionNumber('21'), 21);
    expect(parseJavaVersionNumber('invalid'), 0);
  });

  test('extracts runtime details from java -version output', () {
    final temurin = parseJavaRuntimeDetails(
      'openjdk version "17.0.1" 2021-10-19\n'
      'OpenJDK Runtime Environment Temurin-17.0.1+12 (build 17.0.1+12)\n'
      'OpenJDK 64-Bit Server VM Temurin-17.0.1+12 (build 17.0.1+12, mixed mode)',
    );
    expect(temurin.vendor, 'Temurin');
    expect(temurin.bitness, 64);
    expect(temurin.fullVersion, '17.0.1');
    expect(temurin.arch, 'x86_64');

    final oracle = parseJavaRuntimeDetails(
      'java version "1.8.0_265"\n'
      'Java(TM) SE Runtime Environment (build 1.8.0_265-b01)\n'
      'Java HotSpot(TM) 64-Bit Server VM (build 25.265-b01, mixed mode)',
    );
    expect(oracle.vendor, 'Oracle');
    expect(oracle.bitness, 64);
    expect(oracle.fullVersion, '1.8.0_265');
  });

  test('parses quoted JDK release contents', () {
    final release = parseJavaReleaseContents(
      'IMPLEMENTOR="Eclipse Adoptium"\n'
      'JAVA_VERSION="17.0.10"\n'
      'OS_ARCH="x86_64"\n',
    );
    expect(release, isNotNull);
    expect(release!.majorVersion, 17);
    expect(release.vendor, 'Eclipse Adoptium');
    expect(release.bitness, 64);
    expect(release.fullVersion, '17.0.10');
    expect(release.arch, 'x86_64');
  });

  test('JavaRuntime JSON round-trip keeps runtime metadata', () {
    const runtime = JavaRuntime(
      executable: r'C:\Java\bin\java.exe',
      majorVersion: 21,
      displayName: 'Java 21',
      vendor: 'Temurin',
      bitness: 64,
      fullVersion: '21.0.2',
      isJdk: true,
      arch: 'x86_64',
      source: 'PATH',
    );
    final restored = JavaRuntime.fromJson(runtime.toJson());
    expect(restored, isNotNull);
    expect(restored!.executable, runtime.executable);
    expect(restored.majorVersion, 21);
    expect(restored.vendor, 'Temurin');
    expect(restored.bitness, 64);
    expect(restored.isJdk, isTrue);
    expect(restored.source, 'PATH');
    expect(restored.fromCache, isTrue);
    expect(restored.detailsLabel, 'Temurin · 64 位 · 完整 JDK');
  });

  test('sorts runtimes by descending major version then path', () {
    const service = JavaRuntimeService();
    final sorted = service.sort(const [
      JavaRuntime(executable: 'b-java8', majorVersion: 8, displayName: '8'),
      JavaRuntime(executable: 'a-java21', majorVersion: 21, displayName: '21'),
      JavaRuntime(executable: 'a-java17', majorVersion: 17, displayName: '17'),
    ]);
    expect(sorted.map((runtime) => runtime.majorVersion), [21, 17, 8]);
  });

  test('finds a runtime by executable with normalized path', () {
    const service = JavaRuntimeService();
    const runtime = JavaRuntime(
      executable: r'C:\Java\bin\java.exe',
      majorVersion: 17,
      displayName: 'Java 17',
    );
    final found = service.runtimeForExecutable(r'C:\Java\bin\java.exe', const [
      runtime,
    ]);
    expect(found, same(runtime));
  });
}
