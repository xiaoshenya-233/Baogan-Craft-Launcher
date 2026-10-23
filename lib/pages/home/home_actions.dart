part of '../launcher_home_page.dart';

extension _LaunchActions on _LauncherHomePageState {
  Future<void> _launchSelectedVersion() async {
    if (_isLaunching) return;
    final selectedId = _selectedLaunchVersionId;
    final matchingVersions = _localVersions.where(
      (version) => version.directoryPath == selectedId,
    );
    if (matchingVersions.isEmpty) {
      _showVersionMessage(_l10n.homeNeedInstalledVersion);
      return;
    }
    await _launchVersion(matchingVersions.first);
  }

  /// 快速加入：以已保存服务器的地址启动客户端（`--server` / `--port`）。
  Future<void> _fastJoinServer(
    LauncherVersion launcherVersion,
    ServerEntry server,
  ) async {
    if (_isLaunching) {
      _showVersionMessage(_l10n.homeLaunchBusy);
      return;
    }
    final matching = _localVersions.where(
      (version) => version.directoryPath == launcherVersion.path,
    );
    if (matching.isEmpty) {
      _showVersionMessage(
        _l10n.homeMissingLaunchConfig(launcherVersion.name),
      );
      return;
    }
    if ((_selectedJavaExecutable ?? '').trim().isEmpty &&
        _customJavaPath.trim().isEmpty &&
        _javaRuntimes.isEmpty &&
        _java.javaSelection != PreferencesStore.autoJavaValue) {
      _showVersionMessage(
        _l10n.homeJavaNotSelectedQuickJoin,
      );
      return;
    }
    await _launchVersion(matching.first, server: server);
  }

  Future<void> _launchVersion(
    MinecraftVersion version, {
    ServerEntry? server,
  }) async {
    if (_isLaunching) return;
    _setPageState(() => _isLaunching = true);
    LaunchPlan? launchPlan;
    try {
      LauncherLog.info(
        'Launch',
        '准备启动 ${version.id} · 目录 ${version.directoryPath} · '
            'Minecraft ${version.minecraftVersion ?? '未知'} · '
            '加载器 ${version.loaderType ?? '原版'} ${version.loaderVersion ?? ''}',
      );
      if (server != null) {
        LauncherLog.info(
          'Servers',
          '快速加入目标：${server.name}（${server.address}）',
        );
      }
      LauncherLog.info('Launch', '认证模式：${_launchAuthMode.name}');
      final launchIdentity = await _authenticateForLaunch();
      if (!mounted || launchIdentity == null) {
        LauncherLog.warning('Launch', '认证未完成，已取消启动');
        if (mounted && server != null) {
          _showVersionMessage(_l10n.homeQuickJoinNoAccount);
        }
        return;
      }
      LauncherLog.info(
        'Launch',
        '玩家：${launchIdentity.name} · 用户类型 ${launchIdentity.userType}',
      );
      // Per-client overrides (BGCL/client.json) win over the global defaults.
      final clientSettings = await ClientLaunchSettings.load(
        version.directoryPath,
      );
      if (clientSettings.isIndependent) {
        LauncherLog.info(
          'Launch',
          '客户端使用独立配置：Java=${clientSettings.java} · '
              '内存=${clientSettings.ownMemoryGb?.round() ?? '跟随全局'} GB',
        );
      }
      final effectiveMemoryGb =
          (clientSettings.ownMemoryGb ?? _bgucMemoryGb).round();
      final String javaExecutable;
      try {
        javaExecutable = await _findJavaExecutable(version, clientSettings);
      } on StateError catch (error) {
        _showVersionMessage(
          _l10n.homeJavaRuntimeMissing(error.message),
        );
        return;
      }
      if (javaExecutable.trim().isEmpty) {
        _showVersionMessage(
          _l10n.homeJavaNotSelected,
        );
        return;
      }
      LauncherLog.info('Launch', 'Java：$javaExecutable');
      final plan = await MinecraftLaunchService.buildArguments(
        version: version,
        minecraftPath: version.minecraftPath,
        identity: launchIdentity,
        javaExecutable: javaExecutable,
        memoryGb: effectiveMemoryGb,
        javaAgent: launchIdentity.javaAgent,
        serverAddress: server?.ip,
        serverPort: server?.port,
      );
      launchPlan = plan;
      final agentArgument = plan.arguments
          .where((argument) => argument.startsWith('-javaagent:'))
          .firstOrNull;
      if (agentArgument != null) {
        LauncherLog.info('Launch', 'JVM 代理参数：$agentArgument');
      }
      LauncherLog.info(
        'Launch',
        '工作目录：${plan.gameDirectory.path} · '
            '内存：$effectiveMemoryGb GB',
      );
      LauncherLog.info(
        'Launch',
        '启动参数：${redactLogSecrets(plan.arguments.join(' '))}',
      );
      final session = await _launchRunner.launch(
        javaExecutable: javaExecutable,
        plan: plan,
      );
      launchPlan = null;
      unawaited(
        session.waitForExit().then((result) async {
          if (result.cleanupError != null && mounted) {
            _showVersionMessage(result.cleanupError!);
          }
          if (!mounted || result.exitCode == 0) return;
          await _handleMinecraftLaunchFailure(
            version: version,
            javaExecutable: javaExecutable,
            exitCode: result.exitCode,
            output: result.output,
          );
        }),
      );
      if (!mounted) return;
      _setPageState(() => _isLaunching = false);
      _showVersionMessage(
        server == null
            ? _l10n.homeLaunching(version.id)
            : _l10n.homeLaunchingJoin(
                version.id,
                server.name,
                server.address,
              ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      _setPageState(() => _isLaunching = false);
      _showVersionMessage(error.message);
    } on FileSystemException catch (error) {
      if (!mounted) return;
      _setPageState(() => _isLaunching = false);
      _showVersionMessage(_l10n.homeLaunchFilesUnavailable(error.message));
    } on ProcessException catch (error) {
      if (!mounted) return;
      _setPageState(() => _isLaunching = false);
      _showVersionMessage(_l10n.homeJavaStartFailed(error.message));
    } on SocketException catch (error) {
      if (!mounted) return;
      _setPageState(() => _isLaunching = false);
      _showVersionMessage(_l10n.homeAuthConnectFailed(error.message));
    } on HttpException catch (error) {
      if (!mounted) return;
      _setPageState(() => _isLaunching = false);
      _showVersionMessage(_l10n.homeAuthRequestFailed(error.message));
    } on HandshakeException catch (error) {
      if (!mounted) return;
      _setPageState(() => _isLaunching = false);
      _showVersionMessage(_l10n.homeAuthTlsFailed(error.message));
    } on TimeoutException {
      if (!mounted) return;
      _setPageState(() => _isLaunching = false);
      _showVersionMessage(_l10n.homeAuthTimeout);
    } finally {
      final pendingPlan = launchPlan;
      if (pendingPlan != null) {
        final cleanupError = await _launchRunner.cleanupNatives(
          pendingPlan.nativesDirectory,
        );
        if (cleanupError != null && mounted) {
          _showVersionMessage(cleanupError);
        }
      }
      if (mounted && _isLaunching) _setPageState(() => _isLaunching = false);
    }
  }

  JavaRuntime? _javaRuntimeForExecutable(String executable) {
    return _javaRuntimeService.runtimeForExecutable(executable, _javaRuntimes);
  }

  Future<void> _handleMinecraftLaunchFailure({
    required MinecraftVersion version,
    required String javaExecutable,
    required int exitCode,
    required String output,
  }) async {
    final diagnosis = await _launchDiagnostics.diagnose(
      versionId: version.id,
      exitCode: exitCode,
      output: output,
      javaRuntime: _javaRuntimeForExecutable(javaExecutable),
      loadRequiredJavaMajor: () => _requiredJavaMajor(version),
    );
    if (!mounted) return;
    void openLog() => unawaited(_openDebugLogWindow());
    switch (diagnosis.kind) {
      case LaunchFailureKind.missingMods:
        await LaunchFailureDialogs.showMissingMods(
          context,
          missingDependencies: diagnosis.missingDependencies,
          colors: _uiColors,
          onOpenDebugLog: openLog,
        );
        return;

      case LaunchFailureKind.incompatibleMods:
        await LaunchFailureDialogs.showIncompatibleMods(
          context,
          message: diagnosis.compatibilityIssue ?? '',
          onOpenDebugLog: openLog,
        );
        return;

      case LaunchFailureKind.javaVersion:
        final runtime = _javaRuntimeForExecutable(javaExecutable);
        final currentJava = runtime == null || runtime.majorVersion == 0
            ? lastPathSegment(javaExecutable)
            : 'Java ${runtime.majorVersion}';
        final openSettings = await LaunchFailureDialogs.showJavaMismatch(
          context,
          versionId: version.id,
          exitCode: exitCode,
          currentJava: currentJava,
          snippet: diagnosis.snippet,
          colors: _uiColors,
          onOpenDebugLog: openLog,
        );
        if (openSettings == true && mounted) {
          _shell.selectTab(LauncherTab.settings);
        }
        return;

      case LaunchFailureKind.unknown:
        await LaunchFailureDialogs.showUnknownFailure(
          context,
          versionId: version.id,
          exitCode: exitCode,
          snippet: diagnosis.snippet,
          colors: _uiColors,
          onOpenDebugLog: openLog,
        );
        return;
    }
  }

  Future<int?> _requiredJavaMajor(MinecraftVersion version) async {
    try {
      final config = await MinecraftLaunchService.readConfig(
        version,
        version.minecraftPath,
      );
      final javaVersion = config['javaVersion'];
      if (javaVersion is Map<String, dynamic> &&
          javaVersion['majorVersion'] is int) {
        return javaVersion['majorVersion'] as int;
      }
    } on Exception {
      // 配置无法读取时只依赖启动输出判断。
    }
    return null;
  }

  Future<AuthIdentity?> _authenticateForLaunch() async {
    // The selected account wins: its tokens are read from secure storage.
    final account = _auth.currentAccount;
    if (account != null && account.type.authMode == _launchAuthMode) {
      if (account.isOffline || account.hasToken) {
        if (account.type == AccountType.thirdParty) {
          // Always point the agent at the current bundled jar.
          final server =
              AuthlibInjector.serverFromAgent(account.javaAgent) ??
              _thirdPartyAuthServer;
          final jarPath = await AuthlibInjector.ensureExtracted();
          if (jarPath == null) {
            _showVersionMessage(_l10n.homeAuthlibFailed);
            return null;
          }
          LauncherLog.info('Launch', '第三方认证服务器：$server · 代理：$jarPath');
          return AuthIdentity(
            name: account.name,
            uuid: account.uuid,
            accessToken: account.accessToken,
            userType: 'mojang',
            javaAgent: AuthlibInjector.agentArgument(jarPath, server),
          );
        }
        return account.toIdentity();
      }
    }
    return switch (_launchAuthMode) {
      AuthMode.offline => _authenticateOffline(),
      AuthMode.microsoft => _authenticateMicrosoft(),
      AuthMode.thirdParty => _authenticateThirdParty(),
    };
  }

  Future<AuthIdentity?> _authenticateOffline() async {
    final controller = TextEditingController(text: _offlinePlayerName);
    final playerName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l10n.localProfileTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          decoration: InputDecoration(
            labelText: _l10n.localProfileNameLabel,
            hintText: _l10n.localProfileNameHint,
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(_l10n.actionContinue),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || playerName == null) return null;
    final identity = await _minecraftAuthService.authenticateOffline(
      playerName,
    );
    if (!mounted) return null;
    unawaited(_auth.updateOfflinePlayerName(identity.name));
    unawaited(_auth.rememberAccount(identity));
    return identity;
  }

  Future<AuthSetup?> _showLaunchSetupDialog({
    required String title,
    required List<Widget> Function(
      TextEditingController first,
      TextEditingController second,
      TextEditingController third,
    )
    buildFields,
    required TextEditingController first,
    required TextEditingController second,
    required TextEditingController third,
  }) async {
    try {
      return await showDialog<AuthSetup>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: buildFields(first, second, third),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                AuthSetup(
                  first: first.text.trim(),
                  second: second.text,
                  third: third.text.trim(),
                ),
              ),
              child: Text(_l10n.homeLoginAndLaunch),
            ),
          ],
        ),
      );
    } finally {
      first.dispose();
      second.dispose();
      third.dispose();
    }
  }

  Future<AuthIdentity?> _authenticateThirdParty() async {
    final endpointController = TextEditingController(
      text: _thirdPartyAuthServer,
    );
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final setup = await _showLaunchSetupDialog(
      title: _l10n.homeThirdPartyLoginTitle,
      first: endpointController,
      second: usernameController,
      third: passwordController,
      buildFields: (endpoint, username, password) => [
        TextField(
          controller: endpoint,
          decoration: InputDecoration(
            labelText: _l10n.homeYggdrasilAddress,
          ),
        ),
        TextField(
          controller: username,
          decoration: InputDecoration(
            labelText: _l10n.homeEmailOrUsername,
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        TextField(
          controller: password,
          decoration: InputDecoration(labelText: _l10n.homePassword),
          obscureText: true,
        ),
      ],
    );
    if (!mounted || setup == null) return null;
    final request = _minecraftAuthService.prepareThirdPartyAuth(
      server: setup.first,
      username: setup.second,
      password: setup.third,
    );
    unawaited(_auth.updateThirdPartyAuthServer(request.server));

    // The jar ships with the launcher; no manual file picking any more.
    final agentPath = await AuthlibInjector.ensureExtracted();
    if (!mounted) return null;
    if (agentPath == null) {
      _showVersionMessage(_l10n.homeAuthlibFailed);
      return null;
    }
    LauncherLog.info('Auth', '第三方认证服务器：${request.server} · 代理：$agentPath');
    return _minecraftAuthService.authenticateThirdParty(
      request: request,
      agentPath: agentPath,
    ).then((identity) {
      unawaited(_auth.rememberAccount(identity));
      return identity;
    });
  }

  /// Microsoft sign-in through the `mcid_connect` package.
  ///
  /// Uses the public community client id, so clicking “Microsoft 正版登录”
  /// immediately shows the device-code dialog with no configuration step.
  Future<AuthIdentity?> _authenticateMicrosoft() async {
    final cached = _microsoftIdentity;
    if (cached != null) return cached;

    var dialogOpen = false;
    try {
      final identity = await const MicrosoftConnectService().signIn(
        onDeviceCode: (prompt) {
          if (!mounted) return;
          dialogOpen = true;
          unawaited(
            _showMicrosoftDeviceCodeDialog(prompt).whenComplete(() {
              dialogOpen = false;
            }),
          );
        },
      );
      _microsoftIdentity = identity;
      unawaited(_auth.rememberAccount(identity));
      return identity;
    } on MicrosoftConnectException catch (error) {
      _showVersionMessage(error.message);
      return null;
    } on FormatException catch (error) {
      _showVersionMessage(error.message);
      return null;
    } finally {
      if (mounted && dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _showMicrosoftDeviceCodeDialog(
    MicrosoftConnectDeviceCode prompt,
  ) {
    final minutes = prompt.expiresInDuration.inMinutes;
    final expiry = minutes > 0
        ? '\n\n${_l10n.microsoftDeviceCodeExpiry(minutes)}'
        : '';
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l10n.microsoftDeviceCodeTitle),
        content: SelectableText(
          '${_l10n.microsoftDeviceCodeBody(prompt.verificationUri, prompt.userCode)}'
          '$expiry',
        ),
        actions: [
          TextButton(
            onPressed: () => unawaited(
              PlatformLauncher.openUrl(prompt.verificationUri),
            ),
            child: Text(_l10n.actionOpenBrowser),
          ),
        ],
      ),
    );
  }


  /// Loads the per-client Java/memory overrides shown on the details page.
  Future<void> _loadSelectedVersionSettings(LauncherVersion version) async {
    final settings = await ClientLaunchSettings.load(version.path);
    if (!mounted || _selectedVersion?.path != version.path) return;
    _setPageState(() => _selectedVersionSettings = settings);
  }

  /// Persists the per-client overrides; global preferences stay untouched.
  Future<void> _persistSelectedVersionSettings(
    ClientLaunchSettings next, {
    required String message,
  }) async {
    final version = _selectedVersion;
    if (version == null) return;
    _setPageState(() => _selectedVersionSettings = next);
    await next.save(version.path);
    LauncherLog.info(
      'Launch',
      '保存客户端独立配置：${version.name} -> Java=${next.java} · '
          '内存=${next.memoryGb?.round() ?? '跟随全局'}',
    );
    _showVersionMessage(message);
  }

  Future<void> _saveClientJava(String value) async {
    final next = _selectedVersionSettings.copyWith(java: value);
    final name = _selectedVersion?.name ?? _l10n.homeClientFallback;
    await _persistSelectedVersionSettings(
      next,
      message: next.usesOwnJava
          ? _l10n.homeClientJavaSaved(name, next.java)
          : _l10n.homeClientJavaFollowGlobal(name),
    );
  }

  Future<void> _saveClientMemory(double value) async {
    final next = _selectedVersionSettings.copyWith(memoryGb: value);
    final name = _selectedVersion?.name ?? _l10n.homeClientFallback;
    await _persistSelectedVersionSettings(
      next,
      message: _l10n.homeClientMemorySaved(name, '${value.round()}'),
    );
  }

  Future<String> _findJavaExecutable(
    MinecraftVersion version,
    ClientLaunchSettings clientSettings,
  ) async {
    // An explicit per-client override from the details page always wins.
    if (clientSettings.usesOwnJava) {
      final runtime = await _runtimeForJavaPath(
        clientSettings.java,
        source: '客户端独立配置',
      );
      if (runtime != null) {
        LauncherLog.info('Launch', '使用客户端独立 Java：${runtime.executable}');
        return runtime.executable;
      }
      LauncherLog.warning(
        'Launch',
        '客户端独立 Java 不可用，改为按全局设置选择：${clientSettings.java}',
      );
    }
    final config = await MinecraftLaunchService.readConfig(
      version,
      version.minecraftPath,
    );
    // (a) A Java path configured by the client itself always wins.
    final versionJava = _versionConfiguredJava(config);
    if (versionJava != null) {
      final runtime = await _runtimeForJavaPath(versionJava, source: '客户端配置');
      if (runtime != null) {
        LauncherLog.info('Launch', '使用客户端自带的 Java：${runtime.executable}');
        return runtime.executable;
      }
      LauncherLog.warning(
        'Launch',
        '客户端配置的 Java 不可用，改为使用全局设置：$versionJava',
      );
    }

    final javaVersion = config['javaVersion'];
    final requiredMajor =
        javaVersion is Map<String, dynamic> &&
            javaVersion['majorVersion'] is int
        ? javaVersion['majorVersion'] as int
        : null;
    final globalSelection = _java.javaSelection;

    // (b) A concrete global choice is used as-is; the client version must not
    // override it with a dynamic match.
    if (globalSelection != PreferencesStore.autoJavaValue) {
      final runtime = await _runtimeForJavaPath(
        globalSelection,
        source: '全局设置',
      );
      if (runtime == null) {
        throw StateError(
          _l10n.homeGlobalJavaMissing(globalSelection),
        );
      }
      LauncherLog.info('Launch', '使用全局设置的 Java：${runtime.executable}');
      return runtime.executable;
    }

    // (c) `auto`: match the javaVersion requirement declared by this version.
    LauncherLog.info(
      'Launch',
      '全局 Java 为自动匹配'
          '${requiredMajor == null ? '（该版本未声明 Java 版本）' : ' Java $requiredMajor'}',
    );
    return _javaRuntimeService.resolveExecutable(
      requiredMajor: requiredMajor,
      customPath: '',
      selectedExecutable: null,
      runtimes: _javaRuntimes,
      hasSearched: _hasSearchedJava,
      discover: () async {
        await _java.discover();
        return _javaRuntimes;
      },
      resolveRuntimePath: (path, source) =>
          _runtimeForJavaPath(path, source: source),
    );
  }

  /// Reads a Java executable written into the version JSON
  /// (`javaPath` / `javaExecutable` / `java`, also inside a `BGCL` block).
  String? _versionConfiguredJava(Map<String, dynamic> config) {
    String? pick(Object? source) {
      if (source is! Map) return null;
      for (final key in const <String>['javaPath', 'javaExecutable', 'java']) {
        final value = source[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    }

    return pick(config) ?? pick(config['BGCL']);
  }

  Future<JavaRuntime?> _runtimeForJavaPath(
    String path, {
    String source = '',
  }) async {
    final service = _javaRuntimeService;
    final probed = await service.runtimeForPath(
      path,
      known: _javaRuntimes,
      source: source,
    );
    if (probed == null) return null;
    if (!mounted) return probed;
    final normalized = service.normalizePath(probed.executable);
    final existing = _javaRuntimes
        .where(
          (runtime) =>
              service.normalizePath(runtime.executable) == normalized &&
              runtime.majorVersion == probed.majorVersion,
        )
        .firstOrNull;
    if (existing == null) {
      await _java.addProbedRuntime(probed);
    }
    return probed;
  }
}

extension _PreferencesActions on _LauncherHomePageState {
  Future<void> _loadLauncherPreferences() async {
    unawaited(_auth.loadAccounts());
    unawaited(AuthlibInjector.ensureExtracted());
    if (!await _preferences.exists()) {
      unawaited(_applyDebugLoggingState(openWindow: true));
      return;
    }
    try {
      final decoded = await _preferences.readAll();
      final preferredVersion = decoded['preferredDownloadVersionId'];
      if (!mounted) return;
      final storedSources = decoded['minecraftSources'];
      final legacyMinecraftPath = decoded['minecraftPath'];
      _environment.applyStoredPreferences(
        sources: storedSources is List
            ? storedSources.whereType<String>().toList()
            : const [],
        legacyPath: legacyMinecraftPath is String ? legacyMinecraftPath : null,
        gameRoot: PathManager.instance.gameRoot,
      );
      _catalog.applyPersistedSelection(
        preferredVersion is String ? preferredVersion : null,
      );
      final javaPath = decoded['customJavaPath'];
      final selectedJava = decoded['selectedJavaExecutable'];
      _java.applyPreferences(
        customPath: javaPath is String ? javaPath : null,
        selectedExecutable: selectedJava is String ? selectedJava : null,
      );
      _auth.applyPreferences(
        modeName: decoded['launchAuthMode'] is String
            ? decoded['launchAuthMode'] as String
            : null,
        offlinePlayerName: decoded['offlinePlayerName'] is String
            ? decoded['offlinePlayerName'] as String
            : null,
        thirdPartyAuthServer: decoded['thirdPartyAuthServer'] is String
            ? decoded['thirdPartyAuthServer'] as String
            : null,
      );
      _setPageState(() {
        final aggregatePreference = decoded['aggregatePreference'];
        _aggregatePreference = AggregatePreference.values.firstWhere(
          (preference) => preference.name == aggregatePreference,
          orElse: () => AggregatePreference.balanced,
        );
        final debugLogging = decoded['debugLoggingEnabled'];
        _debugLoggingEnabled = debugLogging is bool ? debugLogging : true;
        _mcimEnabled = decoded[PreferencesStore.mcimEnabledKey] == true;
      });
      CurseForgeService.endpoint = _mcimEnabled
          ? CurseForgeEndpoint.mcim
          : CurseForgeEndpoint.proxy;
      if (_minecraftSources.isNotEmpty) {
        unawaited(_catalog.loadVersions());
      }
      LauncherLog.info(
        'Settings',
        '设置已载入：来源 ${_minecraftSources.length} 个，'
            '调试日志=${_debugLoggingEnabled ? '开' : '关'}',
      );
    } on FormatException catch (error) {
      _showVersionMessage(_l10n.homeSettingsReadFailed(error.message));
    } on FileSystemException catch (error) {
      _showVersionMessage(_l10n.homeSettingsReadFailed(error.message));
    } finally {
      unawaited(_applyDebugLoggingState(openWindow: _debugLoggingEnabled));
    }
  }

  Future<void> _saveCustomJavaPath() async {
    final path = _javaPathController.text.trim();
    if (path.isEmpty) {
      await _java.clearCustomPath();
      _showVersionMessage(_l10n.homeJavaAutoRestored);
      return;
    }
    if (!await File(path).exists()) {
      _showVersionMessage(_l10n.javaPathMissing(path));
      return;
    }
    final runtime = await _java.registerExecutable(path);
    if (runtime == null) {
      _showVersionMessage(_l10n.homeJavaUnrecognized);
      return;
    }
    _javaPathController.clear();
    _showVersionMessage(_l10n.homeJavaAdded(runtime.displayName));
  }

  Future<void> _saveMinecraftSources() async {
    await _persistPreference('minecraftSources', _minecraftSources);
    await _persistPreference('minecraftPath', _minecraftPath);
  }

  Future<void> _persistPreference(String key, Object? value) async {
    try {
      await _preferences.write(key, value);
    } on FormatException catch (error) {
      _showVersionMessage(_l10n.homeSettingsSaveFailed(error.message));
    } on FileSystemException catch (error) {
      _showVersionMessage(_l10n.homeSettingsSaveFailed(error.message));
    }
  }

  Future<void> _applyDebugLoggingState({required bool openWindow}) async {
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    if (_debugLoggingEnabled) {
      await LauncherLog.initialize();
      if (!mounted) return;
      if (openWindow) await _openDebugLogWindow();
    } else {
      await LauncherLog.setEnabled(false);
      await _closeDebugLogWindow();
    }
    if (mounted) _setPageState(() {});
  }

  Future<void> _setDebugLoggingEnabled(bool enabled) async {
    if (_debugLoggingEnabled == enabled) return;
    LauncherLog.info('Debug', enabled ? '用户开启调试模式' : '用户关闭调试模式');
    _setPageState(() => _debugLoggingEnabled = enabled);
    await _persistPreference('debugLoggingEnabled', enabled);
    if (enabled) {
      await LauncherLog.setEnabled(true);
      await _openDebugLogWindow();
    } else {
      await LauncherLog.setEnabled(false);
      await _closeDebugLogWindow();
    }
    if (!mounted) return;
    _setPageState(() {});
    _showVersionMessage(
      enabled ? _l10n.homeDebugEnabled : _l10n.homeDebugDisabled,
    );
  }

  Future<void> _openDebugLogWindow() async {
    if (!_debugLoggingEnabled ||
        _openingDebugLogWindow ||
        _debugLogProcess != null) {
      return;
    }
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    final executable = Platform.resolvedExecutable.toLowerCase();
    if (executable.contains('flutter_tester') ||
        executable.endsWith('dart.exe')) {
      return;
    }
    final logPath = LauncherLog.filePath;
    if (logPath == null) return;
    _openingDebugLogWindow = true;
    try {
      final process = await Process.start(Platform.resolvedExecutable, [
        '--debug-log-window=$logPath',
      ], workingDirectory: File(Platform.resolvedExecutable).parent.path);
      _debugLogProcess = process;
      LauncherLog.info('Debug', '独立调试日志窗口已启动，PID=${process.pid}');
      unawaited(
        process.exitCode.then((exitCode) {
          if (identical(_debugLogProcess, process)) {
            _debugLogProcess = null;
          }
          LauncherLog.info('Debug', '调试日志窗口已退出，代码 $exitCode');
          if (mounted) _setPageState(() {});
        }),
      );
    } catch (error) {
      LauncherLog.error('Debug', '无法打开独立调试日志窗口：$error');
    } finally {
      _openingDebugLogWindow = false;
    }
  }

  Future<void> _closeDebugLogWindow() async {
    final process = _debugLogProcess;
    _debugLogProcess = null;
    if (process == null) return;
    try {
      process.kill();
      LauncherLog.info('Debug', '调试日志窗口已关闭');
    } catch (error) {
      LauncherLog.error('Debug', '关闭调试日志窗口失败：$error');
    }
  }

  Future<void> _pickJavaExecutable() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: _l10n.homePickJavaTitle,
        type: Platform.isWindows ? FileType.custom : FileType.any,
        allowedExtensions: Platform.isWindows ? ['exe'] : null,
      );
      final path = files.firstOrNull?.path;
      if (path == null || !mounted) return;
      if (!await File(path).exists()) {
        _showVersionMessage(_l10n.javaPathMissing(path));
        return;
      }
      final runtime = await _java.registerExecutable(path);
      if (!mounted) return;
      _showVersionMessage(
        runtime == null
            ? _l10n.homeJavaUnrecognized
            : _l10n.homeJavaAdded(runtime.displayName),
      );
    } on PlatformException catch (error) {
      _showVersionMessage(
        _l10n.homePickJavaFailed(error.message ?? error.code),
      );
    } on FileSystemException catch (error) {
      _showVersionMessage(_l10n.homePickJavaFailed(error.message));
    }
  }
}
