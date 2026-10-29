/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../haptics.dart';
import '../../motion.dart';
import '../../physics.dart';
import '../../theme/app_colors.dart';
import '../remote_models.dart';
import '../../theme/app_theme.dart';

class Dpad extends StatefulWidget {
  const Dpad({
    super.key,
    required this.onButton,
    this.onButtonDown,
    this.onButtonUp,
  });
  final ValueChanged<RemoteButton> onButton;
  final ValueChanged<RemoteButton>? onButtonDown, onButtonUp;
  @override
  State<Dpad> createState() => _DpadState();
}

class _DpadState extends State<Dpad> with TickerProviderStateMixin {
  RemoteButton? pressed;
  Timer? timer;
  int? activePointer;
  bool longPressed = false;
  RemoteButton? lastPressed;
  late final hold = AnimationController(vsync: this);
  late final spread = AnimationController(vsync: this);
  late final longHold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  void spring(
    AnimationController controller,
    double target, {
    bool bounce = false,
  }) {
    if (reduceMotion(context)) {
      controller.value = target;
    } else {
      controller.animateWith(
        SpringSimulation(
          bounce ? AppSprings.bouncy : AppSprings.press,
          controller.value,
          target,
          controller.velocity,
        ),
      );
    }
  }

  void stop({bool cancel = false}) {
    if (pressed == RemoteButton.ok) {
      if (longPressed) {
        widget.onButtonUp?.call(RemoteButton.ok);
      } else if (!cancel) {
        widget.onButton(RemoteButton.ok);
      }
    }
    longPressed = false;
    timer?.cancel();
    timer = null;
    activePointer = null;
    pressed = null;
    longHold.stop();
    longHold.value = 0;
    spring(hold, 0, bounce: true);
    if (mounted) setState(() {});
  }

  void start(Offset p, double size, int pointer) {
    timer?.cancel();
    timer = null;
    final d = p - Offset(size / 2, size / 2);
    if (d.distance > size / 2) return;
    final b = d.distance < size * .18
        ? RemoteButton.ok
        : d.dx.abs() > d.dy.abs()
        ? (d.dx < 0 ? RemoteButton.left : RemoteButton.right)
        : (d.dy < 0 ? RemoteButton.up : RemoteButton.down);
    activePointer = pointer;
    AppHaptics.selection();
    if (b != RemoteButton.ok) widget.onButton(b);
    pressed = b;
    lastPressed = b;
    spread.value = 0;
    spring(spread, 1, bounce: true);
    spring(hold, 1);
    setState(() {});
    if (b == RemoteButton.ok &&
        widget.onButtonDown != null &&
        widget.onButtonUp != null) {
      if (reduceMotion(context)) {
        longHold.value = 1;
      } else {
        longHold.forward(from: 0);
      }
      timer = Timer(const Duration(milliseconds: 450), () {
        longPressed = true;
        AppHaptics.selection();
        widget.onButtonDown!(b);
      });
    } else if (b != RemoteButton.ok) {
      timer = Timer(const Duration(milliseconds: 350), () {
        widget.onButton(b);
        timer = Timer.periodic(
          const Duration(milliseconds: 120),
          (_) => widget.onButton(b),
        );
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    if (longPressed) widget.onButtonUp?.call(RemoteButton.ok);
    hold.dispose();
    spread.dispose();
    longHold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final s = box.maxWidth;
        return Semantics(
          label: 'D-pad',
          explicitChildNodes: true,
          child: Listener(
            onPointerDown: (e) {
              if (activePointer == null) start(e.localPosition, s, e.pointer);
            },
            onPointerUp: (e) {
              if (e.pointer == activePointer) stop();
            },
            onPointerCancel: (e) {
              if (e.pointer == activePointer) stop(cancel: true);
            },
            child: AnimatedBuilder(
              animation: hold,
              builder: (context, child) {
                final direction = lastPressed;
                final tilt = hold.value * 0.07;
                final x = direction == RemoteButton.up
                    ? tilt
                    : direction == RemoteButton.down
                    ? -tilt
                    : 0.0;
                final y = direction == RemoteButton.left
                    ? -tilt
                    : direction == RemoteButton.right
                    ? tilt
                    : 0.0;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(x)
                    ..rotateY(y),
                  child: child,
                );
              },
              child: CustomPaint(
                painter: _Painter(
                  c,
                  lastPressed,
                  hold: hold,
                  spread: spread,
                  longHold: longHold,
                ),
                child: SizedBox.square(
                  dimension: s,
                  child: Stack(
                    children: [
                      Center(
                        child: SpringPress(
                          pressed: pressed == RemoteButton.ok,
                          scale: 0.95,
                          child: ExcludeSemantics(
                            child: Text(
                              'OK',
                              style: context.appTextTheme.titleLarge!.copyWith(
                                color: c.onSurfaceStrong,
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (final item in [
                        (Icons.keyboard_arrow_up, const Alignment(0, -.68)),
                        (Icons.keyboard_arrow_down, const Alignment(0, .68)),
                        (Icons.keyboard_arrow_left, const Alignment(-.68, 0)),
                        (Icons.keyboard_arrow_right, const Alignment(.68, 0)),
                      ])
                        Align(
                          alignment: item.$2,
                          child: Icon(item.$1, color: c.onSurface, size: 30),
                        ),
                      for (final item in [
                        (RemoteButton.ok, 'OK', Alignment.center),
                        (RemoteButton.up, 'Up', const Alignment(0, -.75)),
                        (RemoteButton.down, 'Down', const Alignment(0, .75)),
                        (RemoteButton.left, 'Left', const Alignment(-.75, 0)),
                        (RemoteButton.right, 'Right', const Alignment(.75, 0)),
                      ])
                        Align(
                          alignment: item.$3,
                          child: Semantics(
                            label: item.$2,
                            button: true,
                            onTap: () {
                              AppHaptics.selection();
                              widget.onButton(item.$1);
                            },
                            child: const SizedBox(width: 48, height: 48),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

const double _okPressedShrink = 0.05;

class _Painter extends CustomPainter {
  _Painter(
    this.c,
    this.pressed, {
    required this.hold,
    required this.spread,
    required this.longHold,
  }) : super(repaint: Listenable.merge([hold, spread, longHold]));
  final AppColors c;
  final RemoteButton? pressed;
  final Animation<double> hold, spread, longHold;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    final okRadius = r * .36;
    final strength = hold.value.clamp(0.0, 1.0);
    canvas.drawCircle(center, r, Paint()..color = c.surfaceContainer);
    if (pressed != null && pressed != RemoteButton.ok && strength > 0) {
      final index = switch (pressed!) {
        RemoteButton.right => 0,
        RemoteButton.down => 1,
        RemoteButton.left => 2,
        _ => 3,
      };
      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: okRadius + (r - okRadius) * spread.value.clamp(0.0, 1.0),
        ),
        -math.pi / 4 + index * math.pi / 2,
        math.pi / 2,
        true,
        Paint()
          ..color = Color.lerp(
            c.surfaceContainer,
            c.surfaceContainerStrong,
            strength,
          )!,
      );
    }
    final line = Paint()
      ..color = c.dpadOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, r - .5, line);
    for (var i = 0; i < 4; i++) {
      final a = math.pi / 4 + i * math.pi / 2;
      final v = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center + v * okRadius, center + v * r, line);
    }
    final okPressed = pressed == RemoteButton.ok;
    final scaledOk =
        okRadius * (okPressed ? 1 - _okPressedShrink * strength : 1);
    canvas.drawCircle(
      center,
      scaledOk,
      Paint()
        ..color = okPressed
            ? Color.lerp(c.okButton, c.surfaceContainerStrong, strength)!
            : c.okButton,
    );
    canvas.drawCircle(center, scaledOk, line);
    if (okPressed) {
      canvas.drawCircle(
        center,
        okRadius * (1 + 0.35 * spread.value.clamp(0.0, 1.0)),
        Paint()
          ..color = c.primary.withValues(
            alpha: 0.18 * (1 - spread.value.clamp(0.0, 1.0)),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: okRadius - 3),
        -math.pi / 2,
        2 * math.pi * longHold.value,
        false,
        Paint()
          ..color = c.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_Painter old) => old.pressed != pressed || old.c != c;
}
