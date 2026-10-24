import 'package:baogan_craft_launcher/services/download/download_service.dart';
import 'package:baogan_craft_launcher/services/task/task_activity_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => TaskActivityController.instance.reset());

  test('DownloadManager coalesces rapid progress notifications', () async {
    final manager = DownloadManager();
    var notifications = 0;
    manager.addListener(() => notifications++);

    final job = DownloadJob(
      id: 'job-1',
      label: 'file.bin',
      groupLabel: 'group',
      kind: 'test',
      path: 'file.bin',
    );
    final done = manager.enqueue(job, (current) async {
      for (var i = 1; i <= 200; i++) {
        current.updateProgress(i * 10, totalBytes: 2000);
      }
      await Future<void>.delayed(const Duration(milliseconds: 1800));
    });

    await Future<void>.delayed(const Duration(milliseconds: 100));
    final task = TaskActivityController.instance.taskById(
      DownloadManager.taskId,
    );
    expect(task, isNotNull);
    expect(task!.title, '正在下载 file.bin');
    expect(task.subText, contains('group: 0/1'));
    expect(task.subText, contains('1 个下载中'));

    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(
      notifications,
      lessThan(8),
      reason: '200 progress updates must not produce 200 notifications',
    );

    await done;
    await Future<void>.delayed(Duration.zero);
    expect(
      TaskActivityController.instance.taskById(DownloadManager.taskId),
      isNull,
    );
    manager.dispose();
  });

  test('DownloadJob revision only advances on throttled progress', () async {
    final job = DownloadJob(
      id: 'job-2',
      label: 'file.bin',
      groupLabel: 'group',
      kind: 'test',
      path: 'file.bin',
    );
    var changes = 0;
    job.revision.addListener(() => changes++);

    for (var i = 1; i <= 100; i++) {
      job.updateProgress(i * 10, totalBytes: 1000);
    }
    expect(changes, lessThan(5));
  });
}
