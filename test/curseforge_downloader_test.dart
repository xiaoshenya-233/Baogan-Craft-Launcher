import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baogan_craft_launcher/services/download/download_service.dart';
import 'package:baogan_craft_launcher/services/installer/game_installer.dart';

void main() {
  test('resolves tasks with pool concurrency and collects failures', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var active = 0;
    var maximumActive = 0;
    final requests = <String>[];

    server.listen((request) async {
      active++;
      maximumActive = active > maximumActive ? active : maximumActive;
      requests.add(request.uri.path);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final segments = request.uri.pathSegments;
      final projectId = int.tryParse(segments[2]);
      final fileId = int.tryParse(segments[4]);
      request.response.headers.contentType = ContentType.json;
      if (projectId == 2) {
        request.response.write(
          jsonEncode({
            'data': {
              'id': fileId,
              'fileName': 'disabled.jar',
              'downloadUrl': null,
            },
          }),
        );
      } else if (projectId == 3) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({'error': 'server error'}));
      } else {
        request.response.write(
          jsonEncode({
            'data': {
              'id': fileId,
              'fileName': 'project-$projectId.jar',
              'downloadUrl': 'https://example.com/project-$projectId.jar',
            },
          }),
        );
      }
      await request.response.close();
      active--;
    });

    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://${server.address.host}:${server.port}',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    final downloader = CurseForgeDownloader(dio: dio, maxConcurrent: 4);
    final files = [
      for (var index = 1; index <= 10; index++)
        CurseForgeManifestFile(
          projectId: index == 2
              ? 2
              : index == 3
              ? 3
              : index,
          fileId: 1000 + index,
          required: true,
        ),
    ];

    final result = await downloader.fetchAll(files);
    expect(maximumActive, lessThanOrEqualTo(4));
    expect(maximumActive, greaterThan(1));
    expect(result.tasks, hasLength(8));
    expect(result.failures, hasLength(2));
    expect(
      result.failures.any((failure) => failure.reason.contains('downloadUrl')),
      isTrue,
    );
    expect(result.tasks.first.url, 'https://example.com/project-1.jar');
    expect(result.tasks.first.fileName, 'project-1.jar');
    expect(result.tasks.first.projectId, 1);
    expect(result.tasks.first.fileId, 1001);
    expect(requests, hasLength(10));

    downloader.close();
    await server.close(force: true);
  });
}
