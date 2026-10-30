/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../physics.dart';
import '../haptics.dart';
import '../motion.dart';
import '../theme/app_colors.dart';
import 'step_dots.dart';
import 'illustrations.dart';
import '../theme/app_theme.dart';

class DiscoverItem {
  const DiscoverItem({
    required this.id,
    required this.title,
    required this.subtitle,
  });
  final String id;
  final String title;
  final String subtitle;
}

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({
    super.key,
    required this.devices,
    required this.searching,
    required this.onSelect,
    required this.onEnterIp,
    this.timedOut = false,
    this.errorText,
    this.onRetry,
    this.onClose,
  });
  final List<DiscoverItem> devices;
  final bool searching;
  final ValueChanged<DiscoverItem> onSelect;
  final VoidCallback onEnterIp;
  final bool timedOut;
  final String? errorText;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              if (onClose != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ),
              const Center(child: StepDots(current: 1)),
              const SizedBox(height: 48),
              Text(
                'Find your TV',
                textAlign: TextAlign.center,
                style: context.appTextTheme.headlineMedium!.copyWith(
                  color: c.onSurfaceStrong,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 35),
                child: Text(
                  'Make sure your phone and TV are on the same Wi-Fi.',
                  textAlign: TextAlign.center,
                  style: context.appTextTheme.bodyLarge!.copyWith(
                    height: 1.3,
                    color: c.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 38),
              Center(
                child: _SearchRadar(
                  active:
                      searching &&
                      devices.isEmpty &&
                      !timedOut &&
                      errorText == null,
                  child: const SizedBox(
                    width: 280,
                    height: 201,
                    child: DiscoverIllustration(),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              Text(
                'Available devices',
                style: context.appTextTheme.displaySmall!.copyWith(
                  color: c.onSurfaceStrong,
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < devices.length; i++) ...[
                SpringIn(
                  key: ValueKey(devices[i].id),
                  delay: Duration(milliseconds: (i * 70).clamp(0, 300)),
                  rise: -18,
                  child: _DeviceTile(
                    item: devices[i],
                    onTap: () {
                      AppHaptics.selection();
                      onSelect(devices[i]);
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (devices.isEmpty && (timedOut || errorText != null))
                Column(
                  children: [
                    Icon(Icons.wifi_off_outlined, color: c.muted, size: 32),
                    const SizedBox(height: 12),
                    Text(
                      errorText ?? 'No TVs found',
                      textAlign: TextAlign.center,
                      style: context.appTextTheme.displaySmall!.copyWith(
                        color: c.onSurfaceStrong,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Make sure the TV is on and on the same Wi-Fi as this phone.',
                      textAlign: TextAlign.center,
                      style: context.appTextTheme.bodyMedium!.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: onRetry,
                      child: const Text('Search again'),
                    ),
                  ],
                )
              else if (searching)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (devices.isEmpty)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.primary,
                            backgroundColor: c.okButton,
                          ),
                        )
                      else
                        Icon(Icons.wifi_find, size: 20, color: c.muted),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Text(
                          devices.isEmpty
                              ? 'Searching…'
                              : 'Still looking for more TVs…',
                          style: context.appTextTheme.bodySmall!.copyWith(
                            color: c.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 68),
              if (devices.isEmpty &&
                  timedOut &&
                  Theme.of(context).platform == TargetPlatform.iOS)
                Text(
                  'On iPhone, allow Local Network for Xiaomi Remote in Settings › Privacy & Security › Local Network.',
                  textAlign: TextAlign.center,
                  style: context.appTextTheme.bodyMedium!.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              Center(
                child: TextButton(
                  onPressed: () {
                    AppHaptics.selection();
                    onEnterIp();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: c.primaryText,
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(
                    'Enter IP address manually',
                    style: context.appTextTheme.labelLarge!,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.item, required this.onTap});
  final DiscoverItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '${item.title}, ${item.subtitle}',
      child: Material(
        color: c.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.card),
          side: BorderSide(color: c.subtleOutline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppShapes.card),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.tv_outlined, size: 29, color: c.onSurfaceStrong),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.appTextTheme.displaySmall!.copyWith(
                          color: c.onSurfaceStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.appTextTheme.bodySmall!.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: c.onSurfaceStrong, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchRadar extends StatefulWidget {
  const _SearchRadar({required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  State<_SearchRadar> createState() => _SearchRadarState();
}

class _SearchRadarState extends State<_SearchRadar>
    with SingleTickerProviderStateMixin {
  static const _size = Size(280, 201);
  static const _source = Offset(0.2, 0.67);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool get _running => widget.active && !reduceMotion(context);

  void _syncAnimation() {
    if (_running && !_controller.isAnimating) _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _SearchRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.colors.primary;
    return SizedBox.fromSize(
      size: _size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: AnimatedOpacity(
                opacity: _running ? 1 : 0,
                duration: AppMotion.standard,
                curve: AppMotion.easeOut,
                onEnd: () {
                  if (!_running) _controller.stop();
                },
                child: ClipRect(
                  child: CustomPaint(
                    painter: _RadarPainter(color, _controller, _source),
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            child: widget.child,
            builder: (context, child) => Transform.translate(
              offset: Offset(
                0,
                _running ? 3 * math.sin(_controller.value * math.pi * 2) : 0,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.color, this.progress, this.source)
    : super(repaint: progress);
  final Color color;
  final Animation<double> progress;
  final Offset source;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * source.dx, size.height * source.dy);
    for (final phase in [0.0, 0.5]) {
      final t = AppMotion.easeOut.transform((progress.value + phase) % 1);
      canvas.drawCircle(
        center,
        14 + 170 * t,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: 0.3 * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.color != color;
}
