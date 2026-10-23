import 'package:flutter/material.dart';

import '../../../services/network/account_models.dart';
import '../../launcher/controllers/auth_controller.dart';

/// Material 3 bottom sheet that lists, switches and removes launcher accounts.
class AccountManagerSheet extends StatefulWidget {
  const AccountManagerSheet({
    super.key,
    required this.auth,
    required this.onAddAccount,
  });

  final AuthController auth;

  /// Invoked after the sheet closes so the caller can show the login chooser.
  final Future<void> Function() onAddAccount;

  static Future<void> show(
    BuildContext context, {
    required AuthController auth,
    required Future<void> Function() onAddAccount,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) =>
          AccountManagerSheet(auth: auth, onAddAccount: onAddAccount),
    );
  }

  @override
  State<AccountManagerSheet> createState() => _AccountManagerSheetState();
}

class _AccountManagerSheetState extends State<AccountManagerSheet> {
  String? _busyAccountId;

  Future<void> _select(UserAccount account) async {
    if (widget.auth.currentAccount?.id == account.id) return;
    setState(() => _busyAccountId = account.id);
    await widget.auth.selectAccount(account.id);
    if (!mounted) return;
    setState(() => _busyAccountId = null);
  }

  Future<void> _confirmRemove(UserAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除账号'),
        content: Text(
          '确定要从启动器移除「${account.name}」吗？\n'
          '本机保存的加密登录凭据也会一并清除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移除'),
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

  Future<void> _addAccount() async {
    Navigator.of(context).pop();
    await widget.onAddAccount();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedBuilder(
      animation: widget.auth,
      builder: (context, _) {
        final accounts = widget.auth.accounts;
        final currentId = widget.auth.currentAccount?.id;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.76,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.manage_accounts_outlined,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '账号管理',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '共 ${accounts.length} 个账号',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: accounts.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        child: Text(
                          '还没有保存的账号。点击下方按钮添加 Microsoft、离线或第三方账号。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                        itemCount: accounts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final account = accounts[index];
                          return _buildAccountCard(
                            account,
                            isCurrent: account.id == currentId,
                            scheme: scheme,
                            theme: theme,
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _addAccount,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('添加新账号'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountCard(
    UserAccount account, {
    required bool isCurrent,
    required ColorScheme scheme,
    required ThemeData theme,
  }) {
    final busy = _busyAccountId == account.id;
    return Material(
      color: isCurrent
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : () => _select(account),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent ? scheme.primary : scheme.outlineVariant,
              width: isCurrent ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              _buildAvatar(account, scheme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.type.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy && !isCurrent)
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
              else if (isCurrent)
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
                    '当前使用',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
              IconButton(
                tooltip: '移除账号',
                onPressed: busy ? null : () => _confirmRemove(account),
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

  /// Circular initial avatar with a small account-type badge.
  Widget _buildAvatar(UserAccount account, ColorScheme scheme) {
    final (background, foreground) = switch (account.type) {
      AccountType.microsoft => (scheme.primary, scheme.onPrimary),
      AccountType.offline => (scheme.tertiary, scheme.onTertiary),
      AccountType.thirdParty => (scheme.secondary, scheme.onSecondary),
    };
    final trimmed = account.name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    background.withValues(alpha: 0.82),
                    background,
                  ],
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
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.outlineVariant,
                  width: 0.8,
                ),
              ),
              child: Icon(
                _typeIcon(account.type),
                size: 10,
                color: background,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(AccountType type) => switch (type) {
    AccountType.microsoft => Icons.sports_esports_rounded,
    AccountType.offline => Icons.person_rounded,
    AccountType.thirdParty => Icons.dns_rounded,
  };

}
