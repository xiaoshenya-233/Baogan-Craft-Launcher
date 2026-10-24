import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/plugin/plugin_action_dispatcher.dart';
import '../launcher/launcher_palette.dart';
import '../plugins/plugin_list_page.dart';

/// Launcher feature hub: a two-column grid that hosts plugins and utilities.
///
/// [State] keeps `_selectedFeatureIndex` (0 = grid). Sub-features replace the
/// grid with an animated transition and always offer a back button, so the hub
/// never leaves the shell or pushes global routes.
class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({
    super.key,
    required this.palette,
    required this.onNavigate,
    required this.onLaunchGame,
  });

  final LauncherPalette palette;
  final PluginNavigateAction onNavigate;
  final PluginLaunchAction onLaunchGame;

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  static const Duration _switchDuration = Duration(milliseconds: 220);

  int _selectedFeatureIndex = 0;

  List<_WorkbenchFeature> _features(AppLocalizations l10n) =>
      <_WorkbenchFeature>[
        _WorkbenchFeature(
          icon: Icons.extension_rounded,
          title: l10n.pluginsTitle,
          description: l10n.workbenchPluginCenterDescription,
          accent: const Color(0xFF4C8C3F),
          isPluginCenter: true,
        ),
        _WorkbenchFeature(
          icon: Icons.memory_rounded,
          title: l10n.workbenchSystemMonitor,
          description: l10n.workbenchSystemMonitorDescription,
          accent: const Color(0xFF2F6FB0),
          placeholder: l10n.workbenchSystemMonitorPlaceholder,
        ),
        _WorkbenchFeature(
          icon: Icons.data_object_rounded,
          title: l10n.workbenchNbtViewer,
          description: l10n.workbenchNbtViewerDescription,
          accent: const Color(0xFFB4762C),
          placeholder: l10n.workbenchNbtPlaceholder,
        ),
        _WorkbenchFeature(
          icon: Icons.backup,
          title: l10n.workbenchSaveBackup,
          description: l10n.workbenchSaveBackupDescription,
          accent: const Color(0xFF2E8B7A),
          placeholder: l10n.workbenchSaveBackupPlaceholder,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final features = _features(l10n);
    final index = _selectedFeatureIndex;
    final detail = index > 0 && index <= features.length
        ? features[index - 1]
        : null;
    return AnimatedSwitcher(
      duration: _switchDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        alignment: Alignment.topLeft,
        children: <Widget>[...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.015, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey<int>(index),
        child: detail == null
            ? _buildGrid(context, l10n, features)
            : _buildDetail(context, l10n, detail),
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    AppLocalizations l10n,
    List<_WorkbenchFeature> features,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hubHeader(context, l10n),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 2 : 1;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 130,
                ),
                itemCount: features.length,
                itemBuilder: (context, index) => _FeatureCard(
                  feature: features[index],
                  palette: widget.palette,
                  comingSoonLabel: l10n.workbenchComingSoon,
                  onTap: () =>
                      setState(() => _selectedFeatureIndex = index + 1),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _hubHeader(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final palette = widget.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.panelAccentColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.panelBorderColor),
            ),
            child: Icon(Icons.widgets_rounded, color: palette.uiColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.workbenchHubTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.workbenchHubSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    AppLocalizations l10n,
    _WorkbenchFeature feature,
  ) {
    final theme = Theme.of(context);
    final palette = widget.palette;
    final scheme = theme.colorScheme;
    // 与模组详情页一致的阅读遮罩：铺满子页面，不加圆角、不加边框。
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: ColoredBox(color: scheme.surface.withValues(alpha: 0.45)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: l10n.workbenchBack,
                    onPressed: () => setState(() => _selectedFeatureIndex = 0),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 2),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: feature.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(feature.icon, size: 20, color: feature.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          feature.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (feature.comingSoon)
                    _ComingSoonBadge(
                      text: l10n.workbenchComingSoon,
                      accent: feature.accent,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 10),
              Expanded(child: _featureBody(context, l10n, feature)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _featureBody(
    BuildContext context,
    AppLocalizations l10n,
    _WorkbenchFeature feature,
  ) {
    if (feature.isPluginCenter) {
      return PluginListPage(
        onNavigate: widget.onNavigate,
        onLaunchGame: widget.onLaunchGame,
        showHeader: false,
      );
    }
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(feature.icon, size: 56, color: feature.accent),
              const SizedBox(height: 16),
              Text(
                feature.placeholder!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: widget.palette.muted,
                ),
              ),
              const SizedBox(height: 14),
              _ComingSoonBadge(
                text: l10n.workbenchComingSoon,
                accent: feature.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One entry of the workbench grid.
class _WorkbenchFeature {
  const _WorkbenchFeature({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    this.isPluginCenter = false,
    this.placeholder,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;

  /// Renders [PluginListPage] instead of a placeholder.
  final bool isPluginCenter;

  /// Copy shown on the "coming soon" screen; `null` for real features.
  final String? placeholder;

  bool get comingSoon => placeholder != null;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.feature,
    required this.palette,
    required this.comingSoonLabel,
    required this.onTap,
  });

  final _WorkbenchFeature feature;
  final LauncherPalette palette;
  final String comingSoonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.dark ? 0.26 : 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: palette.panelColor,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: feature.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(feature.icon, size: 28, color: feature.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              feature.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (feature.comingSoon) ...[
                            const SizedBox(width: 8),
                            _ComingSoonBadge(
                              text: comingSoonLabel,
                              accent: feature.accent,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        feature.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11.5,
                          height: 1.3,
                          color: palette.muted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }
}
