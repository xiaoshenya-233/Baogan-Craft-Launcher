import 'dart:io';

import 'package:baogan_craft_launcher/core/launcher_log.dart';
import 'package:baogan_craft_launcher/core/path_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isPathInside', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('path-guard-');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('accepts strict children and rejects the root itself', () {
      final child = joinPath(root.path, '1.20.1');
      expect(isPathInside(child, root.path), isTrue);
      expect(isPathInside(root.path, root.path), isFalse);
    });

    test('rejects parents and escaped paths', () {
      final separator = Platform.pathSeparator;
      final escaped =
          '${root.path}$separator..$separator..$separator'
          'escape';
      expect(isPathInside(escaped, root.path), isFalse);
      expect(isPathInside(root.parent.path, root.path), isFalse);
    });
  });

  group('redactLogSecrets', () {
    test('masks passwords and OAuth secrets', () {
      final redacted = redactLogSecrets(
        'password=hunter2 refresh_token=refresh-abc '
        'client_secret=client-xyz --accessToken minecraft-token',
      );
      expect(redacted, isNot(contains('hunter2')));
      expect(redacted, isNot(contains('refresh-abc')));
      expect(redacted, isNot(contains('client-xyz')));
      expect(redacted, isNot(contains('minecraft-token')));
      expect(redacted, contains('password=***'));
      expect(redacted, contains('refresh_token=***'));
      expect(redacted, contains('client_secret=***'));
      expect(redacted, contains('--accessToken ***'));
    });

    test('masks player UUIDs', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      final redacted = redactLogSecrets('account=microsoft:$uuid');
      expect(redacted, isNot(contains(uuid)));
      expect(redacted, contains('microsoft:***'));
    });

    test('masks UUIDs and player names embedded in account URLs', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      final redacted = redactLogSecrets(
        '[INFO] [Auth] avatar=https://littleskin.cn/avatar/player/'
        'xiaoshenya114?size=100&username=xiaoshenya114 '
        'profile=https://littleskin.cn/sessionserver/session/minecraft/'
        'profile/$uuid',
      );
      expect(redacted, isNot(contains(uuid)));
      expect(redacted, isNot(contains('xiaoshenya114')));
      expect(redacted, contains('/avatar/player/xi***'));
      expect(redacted, contains('/profile/***'));
      expect(redacted, contains('username=xi***'));
    });

    test('masks compact third-party UUIDs', () {
      const uuid = '11689d2585de4df69773aeb05de5edd1';
      final redacted = redactLogSecrets('uuid=$uuid');
      expect(redacted, isNot(contains(uuid)));
      expect(redacted, contains('uuid=***'));
    });

    test('log viewer masks secrets in legacy log files', () async {
      final directory = await Directory.systemTemp.createTemp('log-redact-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}launcher.log',
      );
      await file.writeAsString(
        '[INFO] [Auth] avatar=https://littleskin.cn/avatar/player/'
        'xiaoshenya114 uuid=123e4567-e89b-12d3-a456-426614174000',
      );

      final tail = await readLogTail(file.path);
      expect(tail.content, isNot(contains('xiaoshenya114')));
      expect(
        tail.content,
        isNot(contains('123e4567-e89b-12d3-a456-426614174000')),
      );
      expect(tail.content, contains('/avatar/player/xi***'));
    });

    test('legacy log files are sanitized on disk', () async {
      final directory = await Directory.systemTemp.createTemp('log-sanitize-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}launcher.log',
      );
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      await file.writeAsString(
        '[INFO] [Auth] avatar=https://littleskin.cn/avatar/player/'
        'xiaoshenya114 uuid=$uuid',
      );

      expect(await sanitizeLogFileSecrets(file), isTrue);
      final content = await file.readAsString();
      expect(content, isNot(contains('xiaoshenya114')));
      expect(content, isNot(contains(uuid)));
      expect(content, contains('/avatar/player/xi***'));
    });

    test('keeps ordinary log text untouched', () {
      const message = 'Launch · 工作目录 C:/games/mc · 内存：6 GB';
      expect(redactLogSecrets(message), message);
    });
  });
}
