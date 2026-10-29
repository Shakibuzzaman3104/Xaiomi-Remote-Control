/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../remote/widgets/device_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class TvAppItem {
  const TvAppItem({
    required this.package,
    required this.label,
    required this.icon,
    required this.isFavourite,
    this.dimmed = false,
  });
  final String package, label;
  final Widget icon;
  final bool isFavourite;
  final bool dimmed;
}

class AppsScreen extends StatefulWidget {
  const AppsScreen({
    super.key,
    required this.deviceName,
    required this.connected,
    required this.onSwitchDevice,
    required this.onTvSettings,
    required this.onAppSettings,
    this.onPower,
    required this.onBack,
    required this.apps,
    required this.onOpen,
    required this.onShowActions,
    this.onToggleFavourite,
    this.notice,
    this.onNoticeTap,
    this.loading = false,
    this.errorText,
    this.onRetry,
  });
  final String deviceName;
  final bool connected;
  final VoidCallback onSwitchDevice, onTvSettings, onAppSettings, onBack;
  final VoidCallback? onPower;
  final List<TvAppItem> apps;
  final ValueChanged<TvAppItem> onOpen, onShowActions;
  final ValueChanged<TvAppItem>? onToggleFavourite;
  final String? notice;
  final VoidCallback? onNoticeTap;
  final bool loading;
  final String? errorText;
  final VoidCallback? onRetry;
  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _favourites = false;
  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final query = _search.text;
    final apps = widget.apps
        .where(
          (app) =>
              (!_favourites || app.isFavourite) &&
              app.label.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            children: [
              DeviceHeader(
                name: widget.deviceName,
                connected: widget.connected,
                onSwitchDevice: widget.onSwitchDevice,
                onTvSettings: widget.onTvSettings,
                onAppSettings: widget.onAppSettings,
                onPower: widget.onPower,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: Icon(Icons.arrow_back, color: c.onSurfaceStrong),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Apps',
                      style: context.appTextTheme.headlineSmall!.copyWith(
                        color: c.onSurfaceStrong,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                focusNode: _searchFocus,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: c.onSurfaceStrong),
                decoration: InputDecoration(
                  hintText: 'Search ${widget.apps.length} apps',
                  hintStyle: TextStyle(color: c.onSurfaceVariant),
                  prefixIcon: Icon(Icons.search, color: c.onSurface),
                  filled: true,
                  fillColor: c.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppShapes.pill),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 48,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: c.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppShapes.pill),
                ),
                child: Row(
                  children: [
                    for (final favourite in [false, true])
                      Expanded(
                        child: Semantics(
                          selected: _favourites == favourite,
                          button: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppShapes.pill),
                            onTap: () =>
                                setState(() => _favourites = favourite),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _favourites == favourite
                                    ? c.primary
                                    : c.surfaceContainer,
                                borderRadius: BorderRadius.circular(
                                  AppShapes.pill,
                                ),
                              ),
                              child: Text(
                                favourite ? 'Favourites' : 'All',
                                style: TextStyle(
                                  color: _favourites == favourite
                                      ? c.onPrimary
                                      : c.onSurfaceStrong,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      button: widget.onNoticeTap != null,
                      link: widget.onNoticeTap != null,
                      child: InkWell(
                        onTap: widget.onNoticeTap,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.notice!,
                              style: context.appTextTheme.labelMedium!.copyWith(
                                color: widget.onNoticeTap == null
                                    ? c.muted
                                    : c.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.errorText != null) ...[
                      Text(
                        widget.errorText!,
                        style: context.appTextTheme.labelMedium!.copyWith(
                          color: c.danger,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonal(
                          onPressed: widget.onRetry,
                          child: const Text('Try again'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Expanded(child: _content(context, apps, query)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<TvAppItem> apps, String query) {
    if (widget.loading && apps.isEmpty) return _skeleton(context);
    if (apps.isEmpty) return _emptyState(context, query);
    final c = context.colors;
    return _grid(
      context,
      itemCount: apps.length,
      builder: (index, tileWidth) {
        final app = apps[index];
        final toggle = widget.onToggleFavourite;
        return InkWell(
          onTap: () => widget.onOpen(app),
          onLongPress: () => widget.onShowActions(app),
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            opacity: app.dimmed ? 0.5 : 1,
            child: Column(
              children: [
                Container(
                  width: tileWidth,
                  height: tileWidth,
                  decoration: BoxDecoration(
                    color: c.appTile,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.subtleOutline),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: SizedBox(width: 56, height: 56, child: app.icon),
                      ),
                      if (app.isFavourite)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Semantics(
                            button: true,
                            label: 'Remove ${app.label} from favourites',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: toggle == null ? null : () => toggle(app),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: Icon(
                                    Icons.star,
                                    size: 16,
                                    color: c.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    app.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextTheme.labelMedium!.copyWith(
                      height: 1.2,
                      color: c.onSurfaceStrong,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context, String query) {
    final c = context.colors;
    if (query.isEmpty) {
      final favourites = _favourites;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              favourites ? 'No favourites yet' : 'No apps yet',
              textAlign: TextAlign.center,
              style: context.appTextTheme.titleMedium!.copyWith(
                color: c.onSurfaceStrong,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              favourites
                  ? 'Long-press an app to add it here.'
                  : 'Apps will appear here once your TV is connected.',
              textAlign: TextAlign.center,
              style: context.appTextTheme.labelMedium!.copyWith(color: c.muted),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Text(
        'No apps match "$query"',
        textAlign: TextAlign.center,
        style: context.appTextTheme.labelMedium!.copyWith(color: c.muted),
      ),
    );
  }

  Widget _skeleton(BuildContext context) {
    final c = context.colors;
    return _grid(
      context,
      itemCount: 12,
      builder: (index, tileWidth) => Column(
        children: [
          Container(
            width: tileWidth,
            height: tileWidth,
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: tileWidth * 0.6,
                height: 10,
                decoration: BoxDecoration(
                  color: c.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(
    BuildContext context, {
    required int itemCount,
    required Widget Function(int index, double tileWidth) builder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 14 * 3) / 4;
        final labelPainter = TextPainter(
          text: const TextSpan(
            text: 'Ag',
            style: TextStyle(fontSize: 12, height: 1.2),
          ),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          maxLines: 2,
        )..layout(maxWidth: tileWidth);
        final labelHeight = labelPainter.preferredLineHeight * 2;
        return GridView.builder(
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
            mainAxisExtent: tileWidth + 6 + labelHeight,
          ),
          itemBuilder: (context, index) => builder(index, tileWidth),
        );
      },
    );
  }
}
