import 'package:flutter/foundation.dart';

import '../../../services/download/download_service.dart';
import '../../../services/network/api_service.dart';

/// Tracks the single foreground download task and its cancellation token.
class DownloadActivityController extends ChangeNotifier {
  DownloadActivityController({required this.manager});

  /// Shared download service injected by the launcher shell.
  final DownloadManager manager;

  String? _activeTask;
  DownloadCancellationToken? _cancellationToken;

  String? get activeTask => _activeTask;
  DownloadCancellationToken? get cancellationToken => _cancellationToken;
  bool get canCancel =>
      _cancellationToken != null && !_cancellationToken!.isCancelled;

  void start({required String task, DownloadCancellationToken? cancellation}) {
    _activeTask = task;
    if (cancellation != null) _cancellationToken = cancellation;
    notifyListeners();
  }

  void updateTask(String? task) {
    if (_activeTask == task) return;
    _activeTask = task;
    notifyListeners();
  }

  void setCancellation(DownloadCancellationToken? cancellation) {
    if (identical(_cancellationToken, cancellation)) return;
    _cancellationToken = cancellation;
    notifyListeners();
  }

  void clearCancellationIfIdentical(DownloadCancellationToken cancellation) {
    if (!identical(_cancellationToken, cancellation)) return;
    _cancellationToken = null;
    notifyListeners();
  }

  void finish() {
    if (_activeTask == null && _cancellationToken == null) return;
    _activeTask = null;
    _cancellationToken = null;
    notifyListeners();
  }

  bool cancel() {
    final token = _cancellationToken;
    if (token == null || token.isCancelled) return false;
    token.cancel();
    _activeTask = '正在取消下载并清理临时文件…';
    notifyListeners();
    return true;
  }
}
