import 'package:flutter/foundation.dart';

import '../../pages/launcher/controllers/launcher_shell_controller.dart';
import 'plugin_manager.dart';

/// Keeps track of the active launcher tab and exposes the floating plugin UIs
/// whose `visibility` block matches it.
///
/// The manager does not poll: the shell calls [updateTab] whenever the tab
/// changes, and `PluginManager` scans trigger [refresh].
class PluginOverlayManager extends ChangeNotifier {
  PluginOverlayManager._();

  static final PluginOverlayManager instance = PluginOverlayManager._();

  static const Map<LauncherTab, String> _pageIds = <LauncherTab, String>{
    LauncherTab.home: 'home',
    LauncherTab.versions: 'versions',
    LauncherTab.downloads: 'downloads',
    LauncherTab.downloadTasks: 'download_tasks',
    LauncherTab.settings: 'settings',
    LauncherTab.workbench: 'workbench',
  };

  LauncherTab _tab = LauncherTab.home;
  List<PluginFloatingUi> _visible = const <PluginFloatingUi>[];

  LauncherTab get currentTab => _tab;
  List<PluginFloatingUi> get visible =>
      List<PluginFloatingUi>.unmodifiable(_visible);

  /// JSON page id for a shell tab (`downloadTasks` → `download_tasks`).
  static String pageIdFor(LauncherTab tab) => _pageIds[tab] ?? 'home';

  void updateTab(LauncherTab tab) {
    final changed = tab != _tab;
    _tab = tab;
    _recompute(notify: changed);
  }

  /// Re-evaluates visibility after plugins finish scanning/loading.
  void refresh() => _recompute(notify: true);

  void _recompute({required bool notify}) {
    final pageId = pageIdFor(_tab);
    final next = PluginManager.instance.floatingUis
        .where((ui) => ui.config.isVisibleOn(pageId))
        .toList(growable: false);
    final unchanged = listEquals(_visible, next);
    _visible = next;
    if (notify || !unchanged) notifyListeners();
  }
}
