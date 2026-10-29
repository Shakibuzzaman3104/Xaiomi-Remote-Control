/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../haptics.dart';
import '../../physics.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class Trackpad extends StatefulWidget {
  const Trackpad({
    super.key,
    required this.onPointerMove,
    required this.onScroll,
    required this.onClick,
    required this.onAirMouseChanged,
    this.onLongPress,
    this.onExpand,
    this.expanded = false,
    this.radius,
  });
  final ValueChanged<Offset> onPointerMove;
  final ValueChanged<double> onScroll;
  final ValueChanged<bool> onClick, onAirMouseChanged;
  final VoidCallback? onLongPress;
  final ValueChanged<Rect>? onExpand;
  final bool expanded;
  final double? radius;
  @override
  State<Trackpad> createState() => _TrackpadState();
}

class _TrackpadState extends State<Trackpad> {
  bool air = false;
  Offset? touch;
  bool touching = false;
  final surfaceKey = GlobalKey();

  @override
  void dispose() {
    if (air) widget.onAirMouseChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  key: surfaceKey,
                  children: [
                    Positioned.fill(
                      child: Semantics(
                        label: 'Mouse trackpad',
                        child: Listener(
                          onPointerDown: (event) => setState(() {
                            touch = event.localPosition;
                            touching = true;
                          }),
                          onPointerMove: (event) =>
                              setState(() => touch = event.localPosition),
                          onPointerUp: (_) => setState(() => touching = false),
                          onPointerCancel: (_) =>
                              setState(() => touching = false),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              AppHaptics.selection();
                              widget.onClick(false);
                            },
                            onLongPress: widget.onLongPress == null
                                ? null
                                : () {
                                    AppHaptics.medium();
                                    widget.onLongPress!();
                                  },
                            onPanUpdate: (d) => widget.onPointerMove(d.delta),
                            child: Container(
                              decoration: BoxDecoration(
                                color: c.surfaceContainer,
                                borderRadius: BorderRadius.circular(
                                  widget.radius ??
                                      (widget.expanded ? 28 : AppShapes.card),
                                ),
                                border: Border.all(color: c.dpadOutline),
                              ),
                              child: SpringValue(
                                value: touching ? 1 : 0,
                                builder: (context, value, _) => CustomPaint(
                                  painter: _GlowPainter(
                                    touch,
                                    value.clamp(0.0, 1.0),
                                    c.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.onExpand != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: 'Expand pad',
                            icon: const Icon(
                              Icons.open_in_full_rounded,
                              size: 20,
                            ),
                            onPressed: () {
                              final box =
                                  surfaceKey.currentContext!.findRenderObject()!
                                      as RenderBox;
                              widget.onExpand!(
                                box.localToGlobal(Offset.zero) & box.size,
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                label: 'Scroll',
                child: GestureDetector(
                  onVerticalDragUpdate: (d) => widget.onScroll(d.delta.dy),
                  child: Container(
                    width: 48,
                    decoration: BoxDecoration(
                      color: c.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.unfold_more, color: c.muted),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!widget.expanded) const SizedBox(height: 8),
        if (!widget.expanded)
          Row(
            children: [
              for (final right in [false, true])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: TextButton(
                      onPressed: () {
                        AppHaptics.selection();
                        widget.onClick(right);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: c.surfaceContainer,
                        foregroundColor: c.onSurface,
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(right ? 'Back' : 'Click'),
                    ),
                  ),
                ),
            ],
          ),
        if (!widget.expanded)
          Row(
            children: [
              Expanded(
                child: Text(
                  air ? 'Point the phone at the TV and turn it' : 'Air mouse',
                  style: context.appTextTheme.bodyMedium!.copyWith(
                    color: c.onSurfaceStrong,
                  ),
                ),
              ),
              Semantics(
                label: 'Air mouse',
                child: Switch.adaptive(
                  activeTrackColor: c.primary,
                  value: air,
                  onChanged: (v) {
                    AppHaptics.selection();
                    setState(() => air = v);
                    widget.onAirMouseChanged(v);
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.position, this.amount, this.color);
  final Offset? position;
  final double amount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final point = position;
    final radius = 65 * amount;
    if (point == null || radius <= 0) return;
    canvas.drawCircle(
      point,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: .22 * amount),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: point, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.position != position || old.amount != amount || old.color != color;
}
