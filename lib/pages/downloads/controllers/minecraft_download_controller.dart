import 'package:flutter/foundation.dart';

import '../../../services/installer/game_installer.dart';
import '../../../services/network/api_service.dart';
import 'minecraft_download_types.dart';

/// State for the Minecraft client download and loader selection flow.
class MinecraftDownloadController extends ChangeNotifier {
  MinecraftReleaseCategory releaseCategory = MinecraftReleaseCategory.release;
  MinecraftLoader? selectedLoader;
  String? selectedVersion;
  List<MinecraftCatalogVersion> catalog = [];
  bool isLoadingCatalog = false;
  String? catalogError;
  final Map<MinecraftLoader, List<String>> loaderVersions = {};
  final Set<MinecraftLoader> loadingLoaderVersions = {};
  final Map<MinecraftLoader, String> loaderVersionErrors = {};
  int catalogRequestId = 0;
  final Map<MinecraftLoader, int> loaderRequestIds = {};
  MinecraftDownloadSource downloadSource = MinecraftDownloadSource.mojang;
  bool isInstalling = false;
  String? installStatus;
  String? installError;
  String? selectedLoaderVersion;
  String clientName = '';

  int beginCatalogRequest() {
    final requestId = ++catalogRequestId;
    isLoadingCatalog = true;
    catalogError = null;
    notifyListeners();
    return requestId;
  }

  bool isCurrentCatalogRequest(int requestId) =>
      requestId == catalogRequestId;

  void applyCatalog(
    List<MinecraftCatalogVersion> versions, {
    String? nextVersion,
  }) {
    catalog = versions;
    selectedVersion = nextVersion;
    isLoadingCatalog = false;
    catalogError = null;
    notifyListeners();
  }

  void failCatalog(String message) {
    catalogError = message;
    isLoadingCatalog = false;
    notifyListeners();
  }

  int beginLoaderRequest(MinecraftLoader loader) {
    final requestId = (loaderRequestIds[loader] ?? 0) + 1;
    loaderRequestIds[loader] = requestId;
    loadingLoaderVersions.add(loader);
    loaderVersionErrors.remove(loader);
    notifyListeners();
    return requestId;
  }

  bool isCurrentLoaderRequest(MinecraftLoader loader, int requestId) =>
      loaderRequestIds[loader] == requestId;

  void applyLoaderVersions(MinecraftLoader loader, List<String> versions) {
    loaderVersions[loader] = versions;
    loadingLoaderVersions.remove(loader);
    selectedLoaderVersion = versions.firstOrNull;
    notifyListeners();
  }

  void failLoader(MinecraftLoader loader, String message) {
    loadingLoaderVersions.remove(loader);
    loaderVersionErrors[loader] = message;
    notifyListeners();
  }

  void selectVersion(String? version) {
    if (version == selectedVersion) return;
    selectedVersion = version;
    selectedLoaderVersion = null;
    loaderVersions.clear();
    loaderVersionErrors.clear();
    loadingLoaderVersions.clear();
    for (final loader in MinecraftLoader.values) {
      loaderRequestIds[loader] = (loaderRequestIds[loader] ?? 0) + 1;
    }
    notifyListeners();
  }

  void selectLoader(MinecraftLoader? loader) {
    selectedLoader = loader;
    selectedLoaderVersion = null;
    notifyListeners();
  }

  void selectLoaderVersion(String? version) {
    selectedLoaderVersion = version;
    notifyListeners();
  }

  void selectDownloadSource(MinecraftDownloadSource source) {
    downloadSource = source;
    notifyListeners();
  }

  void beginInstall(String status) {
    isInstalling = true;
    installStatus = status;
    installError = null;
    notifyListeners();
  }

  void updateInstallStatus(String? status) {
    installStatus = status;
    notifyListeners();
  }

  void finishInstall({String? status}) {
    isInstalling = false;
    installStatus = status;
    notifyListeners();
  }

  void failInstall(String message) {
    isInstalling = false;
    installStatus = null;
    installError = message;
    notifyListeners();
  }

  void reset() {
    catalog = [];
    selectedVersion = null;
    selectedLoader = null;
    selectedLoaderVersion = null;
    catalogError = null;
    isLoadingCatalog = false;
    loaderVersions.clear();
    loadingLoaderVersions.clear();
    loaderVersionErrors.clear();
    notifyListeners();
  }
}
