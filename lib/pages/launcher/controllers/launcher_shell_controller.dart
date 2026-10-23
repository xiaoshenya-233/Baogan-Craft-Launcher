import 'package:flutter/foundation.dart';

enum LauncherTab {
  home,
  versions,
  downloads,
  downloadTasks,
  settings,
  workbench,
}

/// Owns shell navigation and window-chrome state.
class LauncherShellController extends ChangeNotifier {
  LauncherTab _selectedTab = LauncherTab.home;
  bool _showVersionDetails = false;
  bool _showMinecraftDownload = false;
  bool _isWindowMaximized = false;

  LauncherTab get selectedTab => _selectedTab;
  bool get showVersionDetails => _showVersionDetails;
  bool get showMinecraftDownload => _showMinecraftDownload;
  bool get isWindowMaximized => _isWindowMaximized;

  void selectTab(LauncherTab tab) {
    if (_selectedTab == tab &&
        !_showVersionDetails &&
        !_showMinecraftDownload) {
      return;
    }
    _selectedTab = tab;
    _showVersionDetails = false;
    _showMinecraftDownload = false;
    notifyListeners();
  }

  void showDownloads() {
    if (_selectedTab == LauncherTab.downloads &&
        !_showVersionDetails &&
        !_showMinecraftDownload) {
      return;
    }
    _selectedTab = LauncherTab.downloads;
    _showVersionDetails = false;
    _showMinecraftDownload = false;
    notifyListeners();
  }

  void openVersionDetails() {
    if (_selectedTab == LauncherTab.versions && _showVersionDetails) return;
    _selectedTab = LauncherTab.versions;
    _showVersionDetails = true;
    _showMinecraftDownload = false;
    notifyListeners();
  }

  void closeVersionDetails() {
    if (!_showVersionDetails) return;
    _showVersionDetails = false;
    notifyListeners();
  }

  void openMinecraftDownload() {
    if (_selectedTab == LauncherTab.downloads && _showMinecraftDownload) {
      return;
    }
    _selectedTab = LauncherTab.downloads;
    _showMinecraftDownload = true;
    _showVersionDetails = false;
    notifyListeners();
  }

  void closeMinecraftDownload() {
    if (!_showMinecraftDownload) return;
    _showMinecraftDownload = false;
    notifyListeners();
  }

  void setWindowMaximized(bool value) {
    if (_isWindowMaximized == value) return;
    _isWindowMaximized = value;
    notifyListeners();
  }
}
