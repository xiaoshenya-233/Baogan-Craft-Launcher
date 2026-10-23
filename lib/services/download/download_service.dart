import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pool/pool.dart';

import '../../core/format_utils.dart';
import '../../core/launcher_log.dart';
import '../installer/game_installer.dart';
import '../network/api_service.dart';

enum DownloadJobState { queued, downloading, completed, failed, cancelled }

/// Aggregate state for all files that belong to one client or resource task.
class DownloadGroupStats {
  DownloadGroupStats(this.label);

  final String label;
  String kind = '';
  int totalJobs = 0;
  int completedJobs = 0;
  int failedJobs = 0;
  int cancelledJobs = 0;
  int totalBytes = 0;
  int receivedBytes = 0;
  final Set<String> pendingJobIds = <String>{};

  bool get hasPending => pendingJobIds.isNotEmpty;

  double? get progress {
    if (totalBytes <= 0) return null;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  void reset() {
    kind = '';
    totalJobs = 0;
    completedJobs = 0;
    failedJobs = 0;
    cancelledJobs = 0;
    totalBytes = 0;
    receivedBytes = 0;
    pendingJobIds.clear();
  }
}

class DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}

class DownloadJob {
  DownloadJob({
    required this.id,
    required this.label,
    required this.groupLabel,
    required this.kind,
    required this.path,
    this.totalBytes,
    this.cancellation,
  });

  final String id;
  final String label;
  final String groupLabel;
  final String kind;
  final String path;
  final DownloadCancellationToken? cancellation;
  int receivedBytes = 0;
  int? totalBytes;
  DownloadJobState state = DownloadJobState.queued;
  String? error;

  DateTime _lastProgressNotify = DateTime.fromMillisecondsSinceEpoch(0);
  void Function()? onChanged;

  double? get progress {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }

  void updateProgress(int received, {int? totalBytes}) {
    receivedBytes = received;
    if (totalBytes != null && totalBytes > 0) {
      this.totalBytes = totalBytes;
    }
    final now = DateTime.now();
    if (now.difference(_lastProgressNotify) <
        const Duration(milliseconds: 120)) {
      return;
    }
    _lastProgressNotify = now;
    onChanged?.call();
  }
}

class DownloadManager extends ChangeNotifier {
  static const int maxConcurrent = 8;

  final List<DownloadJob> _queue = [];
  final Map<String, DownloadJob> _active = {};
  final Map<String, Future<void> Function(DownloadJob)> _runners = {};
  final Map<String, Completer<void>> _completers = {};
  final Map<String, DownloadGroupStats> _groups = {};
  final Map<String, int> _jobReportedBytes = {};
  final Set<String> _jobTotalsCounted = {};
  final Map<String, int> _lastGroupBytes = {};
  final Map<String, int> _groupSpeeds = {};
  Timer? _speedTimer;
  DateTime? _speedSampledAt;
  int _nextId = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _speedTimer?.cancel();
    _speedTimer = null;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  int get activeCount => _active.length;
  int get queuedCount => _queue.length;
  List<DownloadJob> get activeJobs =>
      List<DownloadJob>.unmodifiable(_active.values);
  List<DownloadGroupStats> get groups {
    final result = _groups.values.toList();
    result.sort((left, right) {
      final byPending = (right.hasPending ? 1 : 0) - (left.hasPending ? 1 : 0);
      if (byPending != 0) return byPending;
      return left.label.compareTo(right.label);
    });
    return List<DownloadGroupStats>.unmodifiable(result);
  }

  List<DownloadJob> jobsForGroup(String label) {
    return List<DownloadJob>.unmodifiable([
      ..._active.values.where((job) => job.groupLabel == label),
      ..._queue.where((job) => job.groupLabel == label),
    ]);
  }

  int groupSpeed(String label) => _groupSpeeds[label] ?? 0;

  int get totalSpeed => _groups.values
      .where((group) => group.hasPending)
      .fold(0, (sum, group) => sum + groupSpeed(group.label));

  String createJobId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';

  Future<void> enqueue(
    DownloadJob job,
    Future<void> Function(DownloadJob) runner,
  ) {
    final completer = Completer<void>();
    _runners[job.id] = runner;
    _completers[job.id] = completer;
    final group = _groups.putIfAbsent(
      job.groupLabel,
      () => DownloadGroupStats(job.groupLabel),
    );
    if (group.pendingJobIds.isEmpty && group.totalJobs > 0) {
      group.reset();
      _lastGroupBytes.remove(job.groupLabel);
      _groupSpeeds.remove(job.groupLabel);
    }
    group.totalJobs++;
    if (group.kind.isEmpty) group.kind = job.kind;
    group.pendingJobIds.add(job.id);
    _jobReportedBytes[job.id] = 0;
    if (job.totalBytes != null) {
      group.totalBytes += job.totalBytes!;
      _jobTotalsCounted.add(job.id);
    }
    job.onChanged = () {
      _updateGroupProgress(job);
      _notify();
    };
    _queue.add(job);
    _ensureSpeedTimer();
    LauncherLog.info(
      'Download',
      '加入队列：${job.kind} / ${job.groupLabel} / ${job.label} -> ${job.path}',
    );
    scheduleMicrotask(_pump);
    return completer.future;
  }

  void _updateGroupProgress(DownloadJob job) {
    final group = _groups[job.groupLabel];
    if (group == null) return;
    if (job.totalBytes != null && _jobTotalsCounted.add(job.id)) {
      group.totalBytes += job.totalBytes!;
    }
    final previous = _jobReportedBytes[job.id] ?? 0;
    final current = job.receivedBytes;
    if (current > previous) {
      group.receivedBytes += current - previous;
    }
    _jobReportedBytes[job.id] = current;
  }

  void _finishGroupJob(DownloadJob job, DownloadJobState state) {
    _updateGroupProgress(job);
    final group = _groups[job.groupLabel];
    if (group == null) return;
    group.pendingJobIds.remove(job.id);
    switch (state) {
      case DownloadJobState.completed:
        group.completedJobs++;
        break;
      case DownloadJobState.failed:
        group.failedJobs++;
        break;
      case DownloadJobState.cancelled:
        group.cancelledJobs++;
        break;
      case DownloadJobState.queued:
      case DownloadJobState.downloading:
        break;
    }
    _jobReportedBytes.remove(job.id);
  }

  void _ensureSpeedTimer() {
    _speedSampledAt ??= DateTime.now();
    for (final group in _groups.values) {
      _lastGroupBytes.putIfAbsent(group.label, () => group.receivedBytes);
    }
    _speedTimer ??= Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _sampleSpeed(),
    );
  }

  void _sampleSpeed() {
    final sampledAt = _speedSampledAt;
    if (sampledAt == null) return;
    final now = DateTime.now();
    final elapsed = now.difference(sampledAt).inMilliseconds / 1000;
    if (elapsed <= 0) return;
    for (final group in _groups.values) {
      final previous = _lastGroupBytes[group.label] ?? group.receivedBytes;
      final delta = group.receivedBytes - previous;
      _groupSpeeds[group.label] = delta > 0 ? (delta / elapsed).round() : 0;
      _lastGroupBytes[group.label] = group.receivedBytes;
    }
    _speedSampledAt = now;
    _notify();
    if (_active.isEmpty && _queue.isEmpty) {
      _speedTimer?.cancel();
      _speedTimer = null;
      _speedSampledAt = null;
    }
  }

  void _pump() {
    var started = false;
    while (_active.length < maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      if (job.cancellation?.isCancelled ?? false) {
        job.state = DownloadJobState.cancelled;
        _finishGroupJob(job, DownloadJobState.cancelled);
        _runners.remove(job.id);
        _completers
            .remove(job.id)
            ?.completeError(const DownloadCancelledException());
        continue;
      }
      _active[job.id] = job;
      job.state = DownloadJobState.downloading;
      started = true;
      unawaited(_run(job));
    }
    if (started) _notify();
  }

  Future<void> _run(DownloadJob job) async {
    final runner = _runners.remove(job.id);
    final completer = _completers.remove(job.id);
    LauncherLog.info('Download', '开始下载：${job.kind} / ${job.label}');
    try {
      job.cancellation?.throwIfCancelled();
      await runner!(job);
      job.cancellation?.throwIfCancelled();
      job.state = DownloadJobState.completed;
      if (job.totalBytes != null) {
        job.receivedBytes = job.totalBytes!;
      }
      _finishGroupJob(job, DownloadJobState.completed);
      LauncherLog.info(
        'Download',
        '下载完成：${job.label}'
            '${job.totalBytes == null ? '' : '（${formatByteSize(job.totalBytes!)}）'}',
      );
      completer?.complete();
    } on DownloadCancelledException catch (error, stackTrace) {
      job.state = DownloadJobState.cancelled;
      _finishGroupJob(job, DownloadJobState.cancelled);
      LauncherLog.warning('Download', '下载已取消：${job.label}');
      completer?.completeError(error, stackTrace);
    } catch (error, stackTrace) {
      job.state = DownloadJobState.failed;
      job.error = '$error';
      _finishGroupJob(job, DownloadJobState.failed);
      LauncherLog.error('Download', '下载失败：${job.label}：$error', stackTrace);
      completer?.completeError(error, stackTrace);
    } finally {
      _active.remove(job.id);
      job.onChanged = null;
      _notify();
      _pump();
    }
  }
}

/// A successfully resolved CurseForge file.
class DownloadTask {
  const DownloadTask({
    required this.url,
    required this.fileName,
    required this.projectId,
    required this.fileId,
  });

  final String url;
  final String fileName;
  final int projectId;
  final int fileId;
}

/// A file that could not be resolved. Failures are collected instead of
/// throwing, so one disabled third-party download does not abort a modpack.
class CurseForgeDownloadFailure {
  const CurseForgeDownloadFailure({
    required this.projectId,
    required this.fileId,
    required this.reason,
  });

  final int projectId;
  final int fileId;
  final String reason;
}

class CurseForgeDownloadCancelledException implements Exception {
  const CurseForgeDownloadCancelledException();

  @override
  String toString() => 'CurseForge 文件信息获取已取消。';
}

class CurseForgeDownloadResult {
  const CurseForgeDownloadResult({required this.tasks, required this.failures});

  final List<DownloadTask> tasks;
  final List<CurseForgeDownloadFailure> failures;

  List<DownloadTask> get successful => tasks;
}

/// Resolves CurseForge manifest file IDs into downloadable file metadata.
///
/// Requests go through the self-hosted Cloudflare Worker proxy, which injects
/// the CurseForge API key server-side, so no `x-api-key` header is sent here.
/// At most [maxConcurrent] requests are active at any time.
class CurseForgeDownloader {
  CurseForgeDownloader({
    Dio? dio,
    String baseUrl = 'https://cf-api-proxy.xiaoshenya233.workers.dev',
    int maxConcurrent = 4,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl.replaceFirst(RegExp(r'/+$'), ''),
               connectTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(seconds: 30),
               sendTimeout: const Duration(seconds: 20),
               headers: const {
                 'Accept': 'application/json',
                 'User-Agent': 'BlockLauncher/1.0.0 (modpack resolver)',
               },
             ),
           ),
       _pool = Pool(maxConcurrent),
       _maxConcurrent = maxConcurrent;

  final Dio _dio;
  final Pool _pool;
  final int _maxConcurrent;

  int get maxConcurrent => _maxConcurrent;

  /// Convenience API returning only successful tasks.
  Future<List<DownloadTask>> fetchDownloadTasks(
    Iterable<CurseForgeManifestFile> files,
  ) async {
    return (await fetchAll(files)).tasks;
  }

  /// Resolves all files and returns both successes and failures.
  Future<CurseForgeDownloadResult> fetchAll(
    Iterable<CurseForgeManifestFile> files, {
    void Function(int completed, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final entries = files.toList(growable: false);
    if (entries.isEmpty) {
      return const CurseForgeDownloadResult(
        tasks: <DownloadTask>[],
        failures: <CurseForgeDownloadFailure>[],
      );
    }

    var completed = 0;
    final resolved = await Future.wait(
      entries.map(
        (file) => _pool.withResource(() async {
          if (isCancelled?.call() ?? false) {
            throw const CurseForgeDownloadCancelledException();
          }
          final item = await _fetchOne(file);
          if (isCancelled?.call() ?? false) {
            throw const CurseForgeDownloadCancelledException();
          }
          completed++;
          onProgress?.call(completed, entries.length);
          return item;
        }),
      ),
    );
    final tasks = <DownloadTask>[];
    final failures = <CurseForgeDownloadFailure>[];
    for (final item in resolved) {
      if (item.task != null) {
        tasks.add(item.task!);
      } else if (item.failure != null) {
        failures.add(item.failure!);
      }
    }
    return CurseForgeDownloadResult(tasks: tasks, failures: failures);
  }

  Future<({DownloadTask? task, CurseForgeDownloadFailure? failure})> _fetchOne(
    CurseForgeManifestFile file,
  ) async {
    try {
      final response = await _dio.get<dynamic>(
        '/v1/mods/${file.projectId}/files/${file.fileId}',
      );
      final raw = response.data;
      final responseMap = raw is Map<String, dynamic>
          ? raw
          : raw is Map
          ? Map<String, dynamic>.from(raw)
          : null;
      if (responseMap == null) {
        return _failure(file, '接口返回的数据不是 JSON 对象');
      }
      final rawData = responseMap['data'];
      final data = rawData is Map<String, dynamic>
          ? rawData
          : rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : null;
      if (data == null) {
        return _failure(file, '接口响应缺少 data 对象');
      }
      final fileName = data['fileName'];
      if (fileName is! String || fileName.trim().isEmpty) {
        return _failure(file, '接口响应缺少 fileName');
      }
      final downloadUrl = data['downloadUrl'];
      if (downloadUrl is! String || downloadUrl.trim().isEmpty) {
        return _failure(file, '作者已禁用第三方下载（downloadUrl 为 null）');
      }
      return (
        task: DownloadTask(
          url: downloadUrl.trim(),
          fileName: fileName.trim(),
          projectId: file.projectId,
          fileId: file.fileId,
        ),
        failure: null,
      );
    } on DioException catch (error) {
      return _failure(file, _describeDioError(error));
    } on Object catch (error) {
      return _failure(file, error.toString());
    }
  }

  ({DownloadTask? task, CurseForgeDownloadFailure? failure}) _failure(
    CurseForgeManifestFile file,
    String reason,
  ) {
    return (
      task: null,
      failure: CurseForgeDownloadFailure(
        projectId: file.projectId,
        fileId: file.fileId,
        reason: reason,
      ),
    );
  }

  String _describeDioError(DioException error) {
    final response = error.response;
    if (response != null) {
      final status = response.statusCode;
      final message = response.statusMessage;
      return 'HTTP ${status ?? '未知'}'
          '${message == null || message.isEmpty ? '' : '：$message'}';
    }
    return error.message ?? error.type.name;
  }

  /// Releases the underlying request pool.
  void close() {
    _pool.close();
    _dio.close(force: true);
  }
}
