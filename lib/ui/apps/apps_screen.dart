/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../fade_switcher.dart';
import '../motion.dart';
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

class _AppsScreenState extends State<AppsScreen>
    with SingleTickerProviderStateMixin {
  static const _rowDelay = Duration(milliseconds: 40);
  static const _tileDuration = Duration(milliseconds: 260);
  static const _staggerRows = 5;
  static final _entranceDuration = _rowDelay * _staggerRows + _tileDuration;

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  late final AnimationController _entrance = AnimationController(vsync: this);
  bool _favourites = false;
  bool _entrancePlayed = false;

  void _playEntranceOnce() {
    if (_entrancePlayed || widget.apps.isEmpty) return;
    _entrancePlayed = true;
    _entrance.animateTo(1, duration: motion(context, _entranceDuration));
  }

  Curve _tileEntranceCurve(int index) {
    final delay = _rowDelay * (index ~/ 4).clamp(0, _staggerRows - 1);
    return Interval(
      delay.inMilliseconds / _entranceDuration.inMilliseconds,
      (delay + _tileDuration).inMilliseconds / _entranceDuration.inMilliseconds,
      curve: AppMotion.easeOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _playEntranceOnce();
  }

  @override
  void didUpdateWidget(covariant AppsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _playEntranceOnce();
  }

  @override
  void dispose() {
    _entrance.dispose();
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
                    Expanded(
                      child: FadeSwitcher(
                        scale: 1,
                        duration: AppMotion.quick,
                        expand: true,
                        child: _content(context, apps, query),
                      ),
                    ),
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
    if (widget.loading && apps.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('skeleton'),
        child: _PulseOpacity(child: _skeleton(context)),
      );
    }
    if (apps.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('empty'),
        child: _emptyState(context, query),
      );
    }
    return KeyedSubtree(
      key: const ValueKey('grid'),
      child: _grid(
        context,
        itemCount: apps.length,
        builder: (index, tileWidth) {
          final app = apps[index];
          return _AppTile(
            key: ValueKey(app.package),
            app: app,
            tileWidth: tileWidth,
            entrance: _entrance,
            entranceCurve: _tileEntranceCurve(index),
            onOpen: () => widget.onOpen(app),
            onShowActions: () => widget.onShowActions(app),
            onToggleFavourite: widget.onToggleFavourite == null
                ? null
                : () => widget.onToggleFavourite!(app),
          );
        },
      ),
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

class _AppTile extends StatefulWidget {
  const _AppTile({
    super.key,
    required this.app,
    required this.tileWidth,
    required this.entrance,
    required this.entranceCurve,
    required this.onOpen,
    required this.onShowActions,
    required this.onToggleFavourite,
  });
  final TvAppItem app;
  final double tileWidth;
  final Animation<double> entrance;
  final Curve entranceCurve;
  final VoidCallback onOpen, onShowActions;
  final VoidCallback? onToggleFavourite;

  @override
  State<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<_AppTile> {
  int _starPops = 0;

  @override
  void didUpdateWidget(covariant _AppTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.app.isFavourite && widget.app.isFavourite) _starPops++;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final app = widget.app;
    final tile = InkWell(
      onTap: widget.onOpen,
      onLongPress: widget.onShowActions,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: app.dimmed ? 0.5 : 1,
        child: Column(
          children: [
            Container(
              width: widget.tileWidth,
              height: widget.tileWidth,
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
                          onTap: widget.onToggleFavourite,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: _StarPop(
                                key: ValueKey(_starPops),
                                pop: _starPops > 0,
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
    return AnimatedBuilder(
      animation: widget.entrance,
      child: tile,
      builder: (context, child) {
        if (widget.entrance.isCompleted) return child!;
        final t = widget.entranceCurve.transform(widget.entrance.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
    );
  }
}

class _StarPop extends StatelessWidget {
  const _StarPop({super.key, required this.pop, required this.child});
  final bool pop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!pop || reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: AppMotion.swap,
      curve: Curves.easeOutBack,
      child: child,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
    );
  }
}

class _PulseOpacity extends StatefulWidget {
  const _PulseOpacity({required this.child});
  final Widget child;

  @override
  State<_PulseOpacity> createState() => _PulseOpacityState();
}

class _PulseOpacityState extends State<_PulseOpacity>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 1, end: 0.5).animate(_curve),
    child: widget.child,
  );
}
