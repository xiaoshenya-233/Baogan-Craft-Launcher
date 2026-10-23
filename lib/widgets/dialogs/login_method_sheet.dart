import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/network/auth_service.dart';
import '../client_tile.dart';

/// Localized display label for an [AuthMode]; enum labels stay untouched.
String authModeLabel(AuthMode mode, AppLocalizations l10n) => switch (mode) {
  AuthMode.offline => l10n.authModeLocalProfile,
  AuthMode.microsoft => l10n.authModeMicrosoft,
  AuthMode.thirdParty => l10n.authModeThirdParty,
};

String authModeDescription(AuthMode mode, AppLocalizations l10n) =>
    switch (mode) {
      AuthMode.offline => l10n.authModeLocalProfileDesc,
      AuthMode.microsoft => l10n.authModeMicrosoftDesc,
      AuthMode.thirdParty => l10n.authModeThirdPartyDesc,
    };

class LoginMethodSheet extends StatelessWidget {
  const LoginMethodSheet({
    super.key,
    required this.currentMode,
    required this.colors,
  });

  final AuthMode currentMode;
  final LauncherUiColors colors;

  static Future<AuthMode?> show(
    BuildContext context, {
    required AuthMode currentMode,
    required LauncherUiColors colors,
  }) {
    return showModalBottomSheet<AuthMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) =>
          LoginMethodSheet(currentMode: currentMode, colors: colors),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: colors.accent,
                ),
                const SizedBox(width: 9),
                Text(
                  l10n.loginMethodTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.loginMethodCurrent(
                    authModeLabel(currentMode, l10n),
                  ),
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (
                    var index = 0;
                    index < AuthMode.values.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(height: 8),
                    _LoginModeRow(
                      mode: AuthMode.values[index],
                      l10n: l10n,
                      selected: AuthMode.values[index] == currentMode,
                      colors: colors,
                      onTap: () =>
                          Navigator.pop(context, AuthMode.values[index]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    l10n.loginMethodHint,
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginModeRow extends StatelessWidget {
  const _LoginModeRow({
    required this.mode,
    required this.l10n,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final AuthMode mode;
  final AppLocalizations l10n;
  final bool selected;
  final LauncherUiColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (mode) {
      AuthMode.offline => Icons.person_outline_rounded,
      AuthMode.microsoft => Icons.account_circle_outlined,
      AuthMode.thirdParty => Icons.dns_outlined,
    };
    final description = authModeDescription(mode, l10n);
    return Material(
      color: selected ? colors.selectedSurface : colors.panelAccent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? colors.accent : colors.border),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? colors.accent : colors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authModeLabel(mode, l10n),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: colors.accent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
