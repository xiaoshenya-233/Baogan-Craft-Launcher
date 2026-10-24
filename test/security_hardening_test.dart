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

    test('keeps ordinary log text untouched', () {
      const message = 'Launch · 工作目录 C:/games/mc · 内存：6 GB';
      expect(redactLogSecrets(message), message);
    });
  });
}
