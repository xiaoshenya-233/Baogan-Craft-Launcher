import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/network/account_models.dart';
import '../launcher/controllers/auth_controller.dart';

typedef OfflineAccountCreator = Future<UserAccount?> Function(String name);
typedef ThirdPartyAccountCreator = Future<UserAccount?> Function(
  String server,
  String username,
  String password,
);
typedef MicrosoftAccountCreator = Future<UserAccount?> Function();

/// Secondary page that lists, creates, renames, switches and removes accounts.
///
/// It is rendered inside the launcher shell (sidebar stays visible) and never
/// uses a bottom sheet or a dialog as its main surface.
class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({
    super.key,
    required this.auth,
    required this.onBack,
    required this.onCreateOffline,
    required this.onCreateThirdParty,
    required this.onCreateMicrosoft,
  });

  final AuthController auth;
  final VoidCallback onBack;
  final OfflineAccountCreator onCreateOffline;
  final ThirdPartyAccountCreator onCreateThirdParty;
  final MicrosoftAccountCreator onCreateMicrosoft;

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  String? _busyAccountId;
  bool _adding = false;

  static final RegExp _validName = RegExp(r'^[A-Za-z0-9]{3,16}$');

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _select(UserAccount account) async {
    if (_busyAccountId != null) return;
    if (widget.auth.currentAccount?.id == account.id) {
      // Keep the launch auth mode aligned even when the card is already active.
      await widget.auth.updateMode(account.type.authMode);
      return;
    }
    setState(() => _busyAccountId = account.id);
    await widget.auth.selectAccount(account.id);
    await widget.auth.updateMode(account.type.authMode);
    if (!mounted) return;
    setState(() => _busyAccountId = null);
  }

  Future<void> _addAccount() async {
    if (_adding) return;
    final l10n = AppLocalizations.of(context)!;
    final type = await showDialog<AccountType>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加账户'),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _typeOption(
              dialogContext,
              AccountType.offline,
              Icons.person_outline_rounded,
              l10n.authModeLocalProfile,
              '纯英文或数字，至少 3 位',
            ),
            _typeOption(
              dialogContext,
              AccountType.microsoft,
              Icons.account_circle_outlined,
              l10n.authModeMicrosoft,
              '设备码登录，成功后自动加入列表',
            ),
            _typeOption(
              dialogContext,
              AccountType.thirdParty,
              Icons.dns_outlined,
              l10n.authModeThirdParty,
              'Yggdrasil 服务器，登录后立即保存',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.actionCancel),
          ),
        ],
      ),
    );
    if (!mounted || type == null) return;

    switch (type) {
      case AccountType.offline:
        final name = await showDialog<String>(
          context: context,
          builder: (_) => const _OfflineNameDialog(),
        );
        if (!mounted || name == null) return;
        await _runCreator(() => widget.onCreateOffline(name));
        return;
      case AccountType.thirdParty:
        final account = await showDialog<UserAccount>(
          context: context,
          builder: (_) => _ThirdPartyAccountDialog(
            initialServer: widget.auth.thirdPartyAuthServer,
            onSubmit: widget.onCreateThirdParty,
          ),
        );
        if (!mounted || account == null) return;
        await _applyCreatedAccount(account);
        return;
      case AccountType.microsoft:
        await _runCreator(widget.onCreateMicrosoft);
        return;
    }
  }

  Widget _typeOption(
    BuildContext dialogContext,
    AccountType type,
    IconData icon,
    String title,
    String description,
  ) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Icon(icon, size: 22),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(description, style: const TextStyle(fontSize: 10.5)),
      onTap: () => Navigator.pop(dialogContext, type),
    );
  }

  Future<void> _runCreator(Future<UserAccount?> Function() create) async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      final account = await create();
      if (!mounted) return;
      if (account == null) {
        _showMessage('添加账号失败，请检查填写的信息。');
        return;
      }
      await widget.auth.updateMode(account.type.authMode);
      if (mounted) _showMessage('已添加账号：${account.name}');
    } on Object catch (error) {
      if (mounted) _showMessage('添加账号失败：$error');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _applyCreatedAccount(UserAccount account) async {
    await widget.auth.updateMode(account.type.authMode);
    if (mounted) _showMessage('已添加账号：${account.name}');
  }

  Future<void> _editName(UserAccount account) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _OfflineNameDialog(
        title: '编辑名称',
        initialName: account.name,
        confirmLabel: '保存',
      ),
    );
    if (!mounted || name == null) return;
    if (!_validName.hasMatch(name)) {
      _showMessage('必须为纯英文且至少3位字符');
      return;
    }
    setState(() => _busyAccountId = account.id);
    final updated = await widget.auth.renameAccount(account.id, name);
    if (!mounted) return;
    setState(() => _busyAccountId = null);
    if (updated == null) _showMessage('修改玩家名失败。');
  }

  Future<void> _confirmRemove(UserAccount account) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountRemoveTitle),
        content: Text(
          '${l10n.accountRemoveConfirm(account.name)}\n'
          '${l10n.accountRemoveHint}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.actionRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyAccountId = account.id);
    await widget.auth.removeAccount(account.id);
    if (!mounted) return;
    setState(() => _busyAccountId = null);
  }

  String _typeLabel(AccountType type, AppLocalizations l10n) => switch (type) {
    AccountType.offline => l10n.authModeLocalProfile,
    AccountType.microsoft => l10n.authModeMicrosoft,
    AccountType.thirdParty => l10n.authModeThirdParty,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: widget.auth,
      builder: (context, _) {
        final accounts = widget.auth.accounts;
        final currentId = widget.auth.currentAccount?.id;
        final currentAccount = widget.auth.currentAccount;
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final horizontal = compact ? 20.0 : 36.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    compact ? 18 : 26,
                    horizontal,
                    0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: widget.onBack,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                            ),
                            label: const Text('返回'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.accountManagerTitle,
                            style: TextStyle(
                              fontSize: compact ? 26 : 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                '账号列表',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                l10n.accountCount(accounts.length),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontal),
                        child: LayoutBuilder(
                          builder: (context, bodyConstraints) {
                            final showPreview = bodyConstraints.maxWidth >= 720;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildListPanel(
                                    accounts,
                                    currentId: currentId,
                                    theme: theme,
                                    scheme: scheme,
                                    l10n: l10n,
                                    compact: compact,
                                  ),
                                ),
                                if (showPreview) ...[
                                  const SizedBox(width: 18),
                                  Expanded(
                                    flex: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 40,
                                      ),
                                      child: _buildSkinPreview(
                                        theme,
                                        scheme,
                                        currentAccount,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildListPanel(
    List<UserAccount> accounts, {
    required String? currentId,
    required ThemeData theme,
    required ColorScheme scheme,
    required AppLocalizations l10n,
    required bool compact,
  }) {
    return Column(
      key: const ValueKey('account-list-panel'),
      children: [
        Expanded(
          child: accounts.isEmpty
              ? _buildEmpty(theme, scheme, l10n)
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  itemCount: accounts.length,
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildAccountCard(
                        account,
                        isCurrent: account.id == currentId,
                        theme: theme,
                        scheme: scheme,
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _adding ? null : _addAccount,
            icon: Icon(
              _adding ? Icons.hourglass_top_rounded : Icons.add_rounded,
              size: 20,
            ),
            label: Text(_adding ? '添加中…' : '添加账户'),
          ),
        ),
        SizedBox(height: compact ? 18 : 26),
      ],
    );
  }

  Widget _buildSkinPreview(
    ThemeData theme,
    ColorScheme scheme,
    UserAccount? account,
  ) {
    final avatarUrl = account?.effectiveAvatarUrl;
    final fallback = Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.person_rounded, size: 64, color: scheme.primary),
    );
    final avatar = avatarUrl == null || avatarUrl.isEmpty
        ? fallback
        : ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.network(
              avatarUrl,
              key: const ValueKey('account-skin-preview-image'),
              width: 104,
              height: 104,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, _, _) => fallback,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : fallback,
            ),
          );
    return Material(
      key: const ValueKey('account-skin-preview'),
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          key: ValueKey<String>(
            'account-skin-preview-body-${account?.id ?? 'none'}-'
            '${avatarUrl ?? 'none'}',
          ),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            avatar,
            const SizedBox(height: 14),
            Text(
              '皮肤预览',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '开发中',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _showMessage('功能开发中'),
                  child: const Text('更换皮肤'),
                ),
                OutlinedButton(
                  onPressed: () => _showMessage('功能开发中'),
                  child: const Text('切换模型 (经典/纤细)'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '这里将显示当前账号的 Minecraft 皮肤。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(
    ThemeData theme,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 44,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.accountManagerEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(
    UserAccount account, {
    required bool isCurrent,
    required ThemeData theme,
    required ColorScheme scheme,
  }) {
    final busy = _busyAccountId == account.id;
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: isCurrent
          ? scheme.primaryContainer.withValues(alpha: 0.4)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCurrent ? scheme.primary : scheme.outlineVariant,
          width: isCurrent ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : () => _select(account),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              _AccountAvatar(account: account, scheme: scheme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.accountCurrent,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _typeLabel(account.type, l10n),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
                )
              else if (account.isOffline)
                IconButton(
                  tooltip: '编辑名称',
                  onPressed: () => _editName(account),
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              IconButton(
                tooltip: l10n.accountRemoveTitle,
                onPressed: () => _confirmRemove(account),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.account, required this.scheme});

  final UserAccount account;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (account.type) {
      AccountType.microsoft => (scheme.primary, scheme.onPrimary),
      AccountType.offline => (scheme.tertiary, scheme.onTertiary),
      AccountType.thirdParty => (scheme.secondary, scheme.onSecondary),
    };
    final trimmed = account.name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();
    final fallback = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [background.withValues(alpha: 0.82), background],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: foreground,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final avatarUrl = account.effectiveAvatarUrl;
    final avatar = avatarUrl == null || avatarUrl.isEmpty
        ? fallback
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              avatarUrl,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, _, _) => fallback,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : fallback,
            ),
          );
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: avatar),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant, width: 0.8),
              ),
              child: Icon(
                switch (account.type) {
                  AccountType.microsoft => Icons.sports_esports_rounded,
                  AccountType.offline => Icons.person_rounded,
                  AccountType.thirdParty => Icons.dns_rounded,
                },
                size: 10,
                color: background,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineNameDialog extends StatefulWidget {
  const _OfflineNameDialog({
    this.title = '新建本地档案',
    this.initialName = '',
    this.confirmLabel = '添加',
  });

  final String title;
  final String initialName;
  final String confirmLabel;

  @override
  State<_OfflineNameDialog> createState() => _OfflineNameDialogState();
}

class _OfflineNameDialogState extends State<_OfflineNameDialog> {
  static final RegExp _validName = RegExp(r'^[A-Za-z0-9]{3,16}$');
  late final TextEditingController _controller;
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _value => _controller.text.trim();
  bool get _valid => _validName.hasMatch(_value);
  String? get _error {
    if (!_touched || _valid) return null;
    return '必须为纯英文且至少3位字符';
  }

  void _submit() {
    if (!_valid) return;
    Navigator.pop(context, _value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 16,
          onChanged: (_) => setState(() => _touched = true),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: '玩家名称',
            hintText: '3-16 位纯英文或数字',
            errorText: _error,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _valid ? _submit : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _ThirdPartyAccountDialog extends StatefulWidget {
  const _ThirdPartyAccountDialog({
    required this.initialServer,
    required this.onSubmit,
  });

  final String initialServer;
  final ThirdPartyAccountCreator onSubmit;

  @override
  State<_ThirdPartyAccountDialog> createState() =>
      _ThirdPartyAccountDialogState();
}

class _ThirdPartyAccountDialogState extends State<_ThirdPartyAccountDialog> {
  late final TextEditingController _server;
  late final TextEditingController _username;
  late final TextEditingController _password;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: widget.initialServer);
    _username = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid =>
      _server.text.trim().isNotEmpty &&
      _username.text.trim().isNotEmpty &&
      _password.text.isNotEmpty;

  void _onFieldChanged(String _) {
    setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (!_valid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final account = await widget.onSubmit(
        _server.text.trim(),
        _username.text.trim(),
        _password.text,
      );
      if (!mounted) return;
      if (account == null) {
        setState(() {
          _submitting = false;
          _error = '账号或密码错误，请重试。';
        });
        return;
      }
      Navigator.pop(context, account);
    } on Object catch (error) {
      if (!mounted) return;
      final message = error.toString();
      setState(() {
        _submitting = false;
        _error =
            message.contains('HTTP 401') ||
                message.contains('HTTP 403') ||
                message.contains('密码') ||
                message.contains('credentials')
            ? '账号或密码错误，请重试。'
            : '登录失败，请检查网络后重试。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.authModeThirdParty),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _server,
                enabled: !_submitting,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                onChanged: _onFieldChanged,
                decoration: const InputDecoration(
                  labelText: '服务器地址',
                  hintText: 'https://littleskin.cn/api/yggdrasil',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _username,
                enabled: !_submitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onChanged: _onFieldChanged,
                decoration: const InputDecoration(labelText: '用户名 / 邮箱'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                enabled: !_submitting,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onChanged: _onFieldChanged,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: '密码'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                '账号信息会立即保存到账号列表，下次启动无需重新填写。',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _valid && !_submitting ? _submit : null,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('登录并保存'),
        ),
      ],
    );
  }
}
