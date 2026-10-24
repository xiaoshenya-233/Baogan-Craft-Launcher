import 'package:baogan_craft_launcher/services/plugin/plugin_audio_service.dart';
import 'package:baogan_craft_launcher/services/task/java_scan_task_service.dart';
import 'package:baogan_craft_launcher/services/task/launcher_task.dart';
import 'package:baogan_craft_launcher/services/task/task_activity_controller.dart';
import 'package:baogan_craft_launcher/widgets/launcher/activity_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _BannerAudioBackend implements PluginAudioBackend {
  @override
  Future<void> play(String source, {required bool isUrl}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Stream<Duration> get durationStream => const Stream<Duration>.empty();

  @override
  Stream<void> get completionStream => const Stream<void>.empty();
}

void main() {
  setUp(() => TaskActivityController.instance.reset());
  tearDown(() => TaskActivityController.instance.reset());

  test('add, update, switch and remove tasks', () {
    final controller = TaskActivityController.instance;
    controller.addTask(
      const LauncherTask(
        id: 'downloads',
        title: '正在下载资源',
        icon: Icons.download_rounded,
      ),
    );
    controller.addTask(
      const LauncherTask(
        id: 'launch',
        title: '正在启动 Minecraft',
        icon: Icons.grass,
      ),
    );
    expect(controller.tasks, hasLength(2));
    expect(controller.activeTaskId, 'launch');

    controller.updateTask('downloads', progress: 0.5, subText: '2 个下载中');
    expect(controller.taskById('downloads')!.progress, 0.5);
    expect(controller.taskById('downloads')!.subText, '2 个下载中');

    controller.setActive('downloads');
    expect(controller.activeTaskId, 'downloads');

    controller.removeTask('downloads');
    expect(controller.activeTaskId, 'launch');
    controller.removeTask('launch');
    expect(controller.tasks, isEmpty);
    expect(controller.activeTaskId, isNull);
  });

  test('java scan task runs only when no cache exists', () async {
    var scans = 0;
    String? taskDuringScan;
    final ran = await JavaScanTaskService.runIfNeeded(
      hasCachedRuntimes: false,
      discover: () async {
        scans++;
        taskDuringScan = TaskActivityController.instance.activeTaskId;
      },
    );
    expect(ran, isTrue);
    expect(scans, 1);
    expect(taskDuringScan, JavaScanTaskService.taskId);
    expect(
      TaskActivityController.instance.taskById(JavaScanTaskService.taskId),
      isNull,
    );

    final skipped = await JavaScanTaskService.runIfNeeded(
      hasCachedRuntimes: true,
      discover: () async {
        scans++;
      },
    );
    expect(skipped, isFalse);
    expect(scans, 1);
  });

  testWidgets('banner switches active task and hides when empty', (
    WidgetTester tester,
  ) async {
    var launchTapped = 0;
    var stopTapped = 0;
    final controller = TaskActivityController.instance;
    controller.addTask(
      const LauncherTask(
        id: 'downloads',
        title: '正在下载资源',
        icon: Icons.download_rounded,
        progress: 0.4,
        subText: '1 个下载中',
      ),
    );
    controller.addTask(
      LauncherTask(
        id: 'launch',
        title: '正在启动 Minecraft',
        icon: Icons.grass,
        onTap: () => launchTapped++,
        actions: <LauncherTaskAction>[
          LauncherTaskAction(
            icon: 'stop',
            tooltip: '停止启动',
            onPressed: () => stopTapped++,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 72,
            child: Align(
              alignment: Alignment.centerRight,
              child: ActivityBanner(onOpenDownloads: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('正在启动 Minecraft'), findsOneWidget);
    expect(find.byTooltip('正在下载资源'), findsOneWidget);
    expect(find.byTooltip('停止启动'), findsOneWidget);

    await tester.tap(find.byTooltip('停止启动'));
    expect(stopTapped, 1);

    await tester.tap(find.byTooltip('正在下载资源'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('正在下载资源'), findsOneWidget);
    expect(find.textContaining('1 个下载中'), findsOneWidget);
    final progressBar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progressBar.value, closeTo(0.4, 0.001));
    expect(find.byTooltip('正在启动 Minecraft'), findsOneWidget);
    expect(find.byTooltip('停止启动'), findsNothing);

    await tester.tap(find.byTooltip('正在启动 Minecraft'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('正在启动 Minecraft'));
    expect(launchTapped, 1);

    controller.reset();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('正在启动 Minecraft'), findsNothing);
    expect(find.textContaining('正在下载资源'), findsNothing);
  });

  testWidgets('audio_toggle icon follows playback state', (
    WidgetTester tester,
  ) async {
    final audio = PluginAudioService.instance;
    audio.backend = _BannerAudioBackend();
    addTearDown(audio.resetForTest);
    await audio.play('https://example.com/song.mp3');

    TaskActivityController.instance.addTask(
      LauncherTask(
        id: 'audio',
        title: '正在播放音乐',
        icon: Icons.music_note,
        actions: <LauncherTaskAction>[
          LauncherTaskAction(
            icon: 'pause',
            tooltip: '播放/暂停',
            action: 'audio_toggle',
            onPressed: () {},
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 72,
            child: Align(
              alignment: Alignment.centerRight,
              child: ActivityBanner(onOpenDownloads: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await audio.pause();
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await audio.resume();
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('audio capsule with progress never renders a download icon', (
    WidgetTester tester,
  ) async {
    TaskActivityController.instance.addTask(
      LauncherTask(
        id: 'plugin-audio',
        title: '正在播放: Song',
        icon: Icons.music_note_rounded,
        progress: 0.42,
        actions: <LauncherTaskAction>[
          LauncherTaskAction(
            icon: 'skip_previous',
            tooltip: '上一首',
            action: 'audio_prev',
            onPressed: () {},
          ),
          LauncherTaskAction(
            icon: 'pause',
            tooltip: '播放/暂停',
            action: 'audio_toggle',
            onPressed: () {},
          ),
          LauncherTaskAction(
            icon: 'skip_next',
            tooltip: '下一首',
            action: 'audio_next',
            onPressed: () {},
          ),
          LauncherTaskAction(
            icon: 'stop',
            tooltip: '停止',
            action: 'audio_stop',
            onPressed: () {},
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 72,
            child: Align(
              alignment: Alignment.centerRight,
              child: ActivityBanner(onOpenDownloads: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final capsuleSize = tester.getSize(
      find.byKey(const ValueKey('task-capsule-plugin-audio')),
    );
    expect(capsuleSize.height, 48);
    expect(capsuleSize.width, lessThanOrEqualTo(420));
    expect(find.byIcon(Icons.downloading_rounded), findsNothing);
    expect(find.byIcon(Icons.download), findsNothing);
    expect(find.byIcon(Icons.download_rounded), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final progressBar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progressBar.value, closeTo(0.42, 0.001));
    final capsule = find.byKey(const ValueKey('task-capsule-plugin-audio'));
    expect(
      find.descendant(of: capsule, matching: find.byType(Positioned)),
      findsNothing,
    );
    final iconRect = tester.getRect(find.byIcon(Icons.music_note_rounded));
    final barRect = tester.getRect(find.byType(LinearProgressIndicator));
    final firstActionRect = tester.getRect(
      find.byKey(const ValueKey('task-action-plugin-audio-0-audio_prev')),
    );
    // The bar lives inside the Expanded column, so it can never cross the
    // leading icon or the trailing action buttons.
    expect(barRect.left, greaterThan(iconRect.right));
    expect(barRect.right, lessThan(firstActionRect.left));
    expect(barRect.height, lessThanOrEqualTo(4));
    expect(find.byType(IconButton), findsNWidgets(4));
    const actions = <String>[
      'audio_prev',
      'audio_toggle',
      'audio_next',
      'audio_stop',
    ];
    for (var index = 0; index < actions.length; index++) {
      expect(
        find.byKey(
          ValueKey('task-action-plugin-audio-$index-${actions[index]}'),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('capsule height stays 48px with long text and many actions', (
    WidgetTester tester,
  ) async {
    TaskActivityController.instance.addTask(
      LauncherTask(
        id: 'plugin-long',
        title: List<String>.filled(200, '超长插件任务标题').join(),
        icon: Icons.extension,
        progress: 0.5,
        subText: List<String>.filled(100, '超长副标题').join(),
        actions: List<LauncherTaskAction>.generate(
          12,
          (index) => LauncherTaskAction(
            icon: 'home',
            tooltip: '动作$index',
            action: 'plugin_action_$index',
            onPressed: () {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 72,
            child: Align(
              alignment: Alignment.centerRight,
              child: ActivityBanner(onOpenDownloads: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    final size = tester.getSize(
      find.byKey(const ValueKey('task-capsule-plugin-long')),
    );
    expect(size.height, 48);
    expect(size.width, lessThanOrEqualTo(420));
    // The capsule renders at most six actions, so 12 plugin actions cannot
    // stretch it beyond the fixed width/height budget.
    expect(find.byType(IconButton), findsNWidgets(6));
  });
}
