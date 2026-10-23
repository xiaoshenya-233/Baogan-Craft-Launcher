part of '../launcher_home_page.dart';

extension _HomeViewActions on _LauncherHomePageState {
  Widget _buildHomeContent() {
    final selectedVersion = _localVersions
        .where((version) => version.directoryPath == _selectedLaunchVersionId)
        .firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final horizontalPadding = compact ? 18.0 : 36.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  compact ? 20 : 32,
                  horizontalPadding,
                  12,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: double.infinity,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _l10n.homeCurrentClient,
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.4,
                                      color: _muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedVersion?.id ??
                                        (_isLoadingVersions
                                            ? _l10n.homeScanningClients
                                            : _l10n.homeNoClientSelected),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: compact ? 26 : 36,
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    selectedVersion == null
                                        ? _l10n.homeSelectClientHint
                                        : '${_homeLoaderLabel(selectedVersion)}'
                                              ' · Minecraft ${selectedVersion.minecraftVersion ?? _l10n.commonUnknown}'
                                              ' · ${lastPathSegment(selectedVersion.minecraftPath)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!compact) ...[
                              const SizedBox(width: 24),
                              _buildHomeAccountEntry(),
                            ],
                          ],
                        ),
                        if (compact) ...[
                          const SizedBox(height: 18),
                          _buildHomeAccountEntry(compact: true),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                22,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: compact
                      ? Column(
                          children: [
                            _buildClientPickerBar(selectedVersion),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: _buildLaunchButton(),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _buildClientPickerBar(selectedVersion),
                            ),
                            const SizedBox(width: 12),
                            _buildLaunchButton(),
                          ],
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHomeAccountEntry({bool compact = false}) {
    return AnimatedBuilder(
      animation: _auth,
      builder: (context, _) {
        final account = _auth.currentAccount;
        final mode = account?.type.authMode ?? _launchAuthMode;
        final icon = switch (mode) {
          AuthMode.offline => Icons.person_outline_rounded,
          AuthMode.microsoft => Icons.account_circle_outlined,
          AuthMode.thirdParty => Icons.dns_outlined,
        };
        return Material(
      color: _panelColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _showAccountEntry,
        child: Container(
          width: compact ? double.infinity : 238,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _panelBorderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _panelAccentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: _LauncherHomePageState._green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account == null ? _l10n.homeLoginMethod : _l10n.homeCurrentAccount,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        color: _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account?.name ?? _homeAuthModeLabel(mode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account != null
                          ? _l10n.homeManageAccount(
                              _homeAccountTypeLabel(account.type),
                            )
                          : _homeAccountDetail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.swap_horiz_rounded, size: 17, color: _muted),
            ],
          ),
        ),
          ),
        );
      },
    );
  }

  /// Opens the account list, or the login chooser when nothing is stored yet.
  Future<void> _showAccountEntry() async {
    if (_auth.accounts.isEmpty) {
      await _showLoginMethodSheet();
      return;
    }
    await AccountManagerSheet.show(
      context,
      auth: _auth,
      onAddAccount: _showLoginMethodSheet,
    );
  }

  String _homeAuthModeLabel(AuthMode mode) => switch (mode) {
    AuthMode.offline => _l10n.authModeLocalProfile,
    AuthMode.microsoft => _l10n.authModeMicrosoft,
    AuthMode.thirdParty => _l10n.authModeThirdParty,
  };

  String _homeAccountTypeLabel(AccountType type) => switch (type) {
    AccountType.offline => _l10n.authModeLocalProfile,
    AccountType.microsoft => _l10n.authModeMicrosoft,
    AccountType.thirdParty => _l10n.authModeThirdParty,
  };

  String get _homeAccountDetail => switch (_launchAuthMode) {
    AuthMode.offline => _l10n.homePlayerName(_offlinePlayerName),
    AuthMode.microsoft => _l10n.homeMicrosoftHint,
    AuthMode.thirdParty => _thirdPartyAuthServer,
  };

  Future<void> _showLoginMethodSheet() async {
    final selected = await LoginMethodSheet.show(
      context,
      currentMode: _launchAuthMode,
      colors: _uiColors,
    );
    if (!mounted || selected == null || selected == _launchAuthMode) return;
    await _auth.updateMode(selected);
    if (!mounted) return;
    if (selected != AuthMode.microsoft) {
      _microsoftIdentity = null;
      _showVersionMessage(
        _l10n.homeAuthSwitched(
          switch (selected) {
            AuthMode.offline => _l10n.authModeLocalProfile,
            AuthMode.microsoft => _l10n.authModeMicrosoft,
            AuthMode.thirdParty => _l10n.authModeThirdParty,
          },
        ),
      );
      return;
    }
    // Switching to "Microsoft 正版登录" starts the device-code sign-in at once.
    final identity = await _authenticateMicrosoft();
    if (!mounted || identity == null) return;
    _showVersionMessage(_l10n.homeMicrosoftSignedIn(identity.name));
  }

  Widget _buildClientPickerBar(MinecraftVersion? selectedVersion) {
    final name = selectedVersion?.id ??
        (_isLoadingVersions
            ? _l10n.homeScanningClients
            : _l10n.homeSelectClient);
    final detail = selectedVersion == null
        ? _l10n.homeClickSelectClient
        : 'Minecraft ${selectedVersion.minecraftVersion ?? selectedVersion.type ?? _l10n.homeVersionUnknown}'
              ' · ${_homeLoaderLabel(selectedVersion)}'
              ' · ${lastPathSegment(selectedVersion.minecraftPath)}';
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                onTap: _showClientPicker,
                child: Padding(
                  padding: const EdgeInsets.only(left: 15, right: 8),
                  child: Row(
                    children: [
                      _clientIcon(selectedVersion),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10.5, color: _muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_l10n.homeSwitch, style: TextStyle(fontSize: 10, color: _muted)),
                      const SizedBox(width: 4),
                      Icon(Icons.unfold_more_rounded, size: 18, color: _muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: _panelAccentColor,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: selectedVersion == null ? null : _showClientConfig,
                child: Tooltip(
                  message: _l10n.homeViewClientConfig,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: selectedVersion == null
                          ? _muted
                          : _LauncherHomePageState._green,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showClientConfig() async {
    final selectedVersion = _localVersions
        .where((version) => version.directoryPath == _selectedLaunchVersionId)
        .firstOrNull;
    if (selectedVersion == null) {
      _showVersionMessage(_l10n.homeSelectClientFirst);
      return;
    }
    await ClientConfigSheet.show(
      context,
      versionId: selectedVersion.id,
      loaderLabel: _homeLoaderLabel(selectedVersion),
      directoryPath: selectedVersion.directoryPath,
      minecraftPath: selectedVersion.minecraftPath,
      javaLabel: _homeJavaLabel(),
      memoryGb: _bgucMemoryGb.round(),
      accountLabel: _homeAccountLabel,
      colors: _uiColors,
      onOpenDirectory: () =>
          unawaited(_openClientFolder(selectedVersion.directoryPath)),
      onOpenVersionDetails: () {
        final launcherVersion = _versions
            .where(
              (candidate) => candidate.path == selectedVersion.directoryPath,
            )
            .firstOrNull;
        if (launcherVersion == null) {
          _shell.selectTab(LauncherTab.versions);
          return;
        }
        _setPageState(() {
          _selectedVersion = launcherVersion;
        });
        _shell.openVersionDetails();
        unawaited(_loadManagedMods(launcherVersion));
      },
      onOpenSettings: () {
        _shell.selectTab(LauncherTab.settings);
      },
    );
  }

  Future<void> _showClientPicker() async {
    await ClientPickerSheet.show(
      context,
      clients: _clientTileData(),
      selectedDirectoryPath: _selectedLaunchVersionId,
      isLoading: _isLoadingVersions,
      colors: _uiColors,
      onReload: () async {
        await _catalog.loadVersions();
        return _clientTileData();
      },
      onSelect: _catalog.selectLaunchVersion,
      onAddFolder: () => unawaited(_addExistingFolder()),
      onDownload: () {
        if (isDownloadLocked) {
          unawaited(_showDownloadLockedDialog(context));
          return;
        }
        _shell.showDownloads();
      },
    );
  }

  List<ClientTileData> _clientTileData() {
    return [
      for (final version in _localVersions)
        ClientTileData(
          id: version.id,
          directoryPath: version.directoryPath,
          minecraftLabel: version.minecraftVersion == null
              ? (version.type ?? _l10n.homeVersionTypeUnknown)
              : 'Minecraft ${version.minecraftVersion}',
          loaderLabel: _homeLoaderLabel(version),
          isModded: version.loaderType != null,
          loaderType: version.loaderType,
        ),
    ];
  }

  /// Vector loader icon for the selected client, with a neutral placeholder
  /// while no client is installed.
  Widget _clientIcon(MinecraftVersion? version) {
    if (version == null) {
      return SizedBox(
        width: VersionIcon.defaultSize,
        height: VersionIcon.defaultSize,
        child: Icon(Icons.inventory_2_outlined, size: 20, color: _muted),
      );
    }
    return VersionIcon(version: version);
  }

  Widget _buildLaunchButton() {
    return ElevatedButton.icon(
      onPressed: _isLaunching || _selectedLaunchVersionId == null
          ? null
          : _launchSelectedVersion,
      icon: Icon(Icons.play_arrow_rounded, size: 22),
      label: _isLaunching
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xFF172013),
              ),
            )
          : Text(
              _l10n.homeLaunchGame,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _LauncherHomePageState._green,
        foregroundColor: const Color(0xFF172013),
        minimumSize: const Size(150, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _homeLoaderLabel(MinecraftVersion? version) {
    if (version == null) return _l10n.homeNoClient;
    final loader = version.loaderType;
    if (loader == null) return _l10n.versionVanilla;
    final loaderVersion = version.loaderVersion;
    return loaderVersion == null ? loader : '$loader $loaderVersion';
  }

  String _homeJavaLabel() {
    final custom = _customJavaPath.trim();
    if (custom.isNotEmpty) return lastPathSegment(custom);
    final selected = _selectedJavaExecutable;
    if (selected != null && selected.trim().isNotEmpty) {
      return lastPathSegment(selected);
    }
    if (_hasSearchedJava) {
      return _l10n.homeJavaAutoDetected(_javaRuntimes.length);
    }
    return _l10n.homeJavaAutoLaunch;
  }

  String get _homeAccountLabel => switch (_launchAuthMode) {
    AuthMode.offline => _l10n.homeLocalProfile(_offlinePlayerName),
    AuthMode.microsoft => _l10n.homeMicrosoftAccount,
    AuthMode.thirdParty => _l10n.homeThirdPartyAccount,
  };

  ResourceDownloadActions _buildDownloadsHost() {
    return ResourceDownloadActions(
      resource: _resourceDownloads,
      minecraft: _minecraftDownloads,
      activity: _downloads,
      manager: _downloadManager,
      context: context,
      minecraftPath: _minecraftPath,
      localClients: () => _localVersions,
      selectedVersion: _selectedVersion,
      selectedLaunchVersionPath: _selectedLaunchVersionId,
      minecraftClientNameController: _minecraftClientNameController,
      onLoadManagedMods: _loadManagedMods,
      onChooseDownloadClient: _chooseDownloadClient,
      onShowDownloadLockedDialog: _showDownloadLockedDialog,
      onCloseMinecraftDownload: _shell.closeMinecraftDownload,
      resourceSearchQuery: _resourceDownloads.searchQuery,
      resourceSearchController: _resourceDownloads.searchController,
      palette: _palette,
      isDark: _usesDarkPalette,
      isDownloadLocked: isDownloadLocked,
      setPageState: _setPageState,
      showMessage: _showVersionMessage,
      onScheduleResourceSearch: _scheduleResourceSearch,
      onLoadResourceResults: _loadResourceResults,
      onToggleResourceCandidate: (_) async {},
      onOpenResourceProject: (_) async {},
      onBackResourceList: () {},
      onShowResourceCandidates: () {},
      onChangeResourcePage: (_) {},
      onInstallModrinthProject: (_) async {},
      onDownloadResourceCandidates: () async {},
      onConfirmRemoveCandidate: (_) async => false,
      onDownloadModrinthProject: (_) async {},
      onHydrateResourceProject: (project) async => project,
      onPickResourceVersionAndLoader: (_) async => null,
      onChooseWorldFolderForDataPack: () async => null,
      onToggleVersionCandidate: (_, _) {},
      onSelectDefaultResourceVersion: (_) {},
      onLoadMinecraftCatalog: _loadMinecraftCatalog,
      onLoadLoaderVersions: _loadLoaderVersions,
      onSelectMinecraftVersion: _selectMinecraftVersion,
      onInstallSelectedMinecraft: _installSelectedMinecraft,
      onCancelActiveDownload: _cancelActiveDownload,
      onOpenDownloadTasks: _openDownloadTasks,
      onOpenMinecraftDownload: _openMinecraftDownload,
      onShowDownloads: () => _shell.showDownloads(),
    );
  }

  Widget _buildDownloadsTab() {
    if (_shell.showMinecraftDownload) {
      return MinecraftDownloadPage(
        minecraft: _minecraftDownloads,
        activity: _downloads,
        palette: _palette,
        isDark: _usesDarkPalette,
        isDownloadLocked: isDownloadLocked,
        minecraftPath: _minecraftPath,
        minecraftClientNameController: _minecraftClientNameController,
        onLoadCatalog: _loadMinecraftCatalog,
        onLoadLoaderVersions: _loadLoaderVersions,
        onSelectVersion: (version) => _selectMinecraftVersion(version),
        onInstall: _installSelectedMinecraft,
        onOpenResourceDownloads: _shell.closeMinecraftDownload,
        onShowDownloadLockedDialog: _showDownloadLockedDialog,
        onCancelInstall: _cancelActiveDownload,
      );
    }
    final host = _buildDownloadsHost();
    return ResourceDownloadsPage(
      resource: _resourceDownloads,
      activity: _downloads,
      catalog: _catalog,
      palette: _palette,
      isDark: _usesDarkPalette,
      isDownloadLocked: isDownloadLocked,
      minecraftEntryBuilder: (compact) => MinecraftDownloadEntryCard(
        minecraft: _minecraftDownloads,
        palette: _palette,
        isDownloadLocked: isDownloadLocked,
        onOpen: _openMinecraftDownload,
        onLoadCatalog: _loadMinecraftCatalog,
        onShowDownloadLockedDialog: _showDownloadLockedDialog,
      ),
      onLoadResults: _loadResourceResults,
      onScheduleSearch: _scheduleResourceSearch,
      onToggleCandidate: host.handleToggleResourceCandidate,
      onOpenProject: host.handleOpenResourceProject,
      onBackToList: host.handleBackToResourceList,
      onInstallProject: host.handleInstallModrinthProject,
      onDownloadCandidates: host.handleDownloadResourceCandidates,
      onToggleVersionCandidate: host.handleToggleVersionCandidate,
      onOpenDownloadTasks: _openDownloadTasks,
      onCancelActiveDownload: _cancelActiveDownload,
    );
  }
}
