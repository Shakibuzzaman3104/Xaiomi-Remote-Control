/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../haptics.dart';
import '../../motion.dart';
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
    hold.animateBack(
      0,
      duration: motion(context, AppMotion.pressOut),
      curve: AppMotion.easeOut,
    );
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
    spread.animateTo(
      1,
      duration: motion(context, AppMotion.tint),
      curve: AppMotion.easeOut,
    );
    hold.animateTo(
      1,
      duration: motion(context, AppMotion.pressIn),
      curve: AppMotion.easeOut,
    );
    if (b == RemoteButton.ok &&
        widget.onButtonDown != null &&
        widget.onButtonUp != null) {
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
            child: CustomPaint(
              painter: _Painter(c, lastPressed, hold: hold, spread: spread),
              child: SizedBox.square(
                dimension: s,
                child: Stack(
                  children: [
                    Center(
                      child: AnimatedBuilder(
                        animation: hold,
                        builder: (context, child) => Transform.scale(
                          scale: lastPressed == RemoteButton.ok
                              ? 1 - _okPressedShrink * hold.value
                              : 1,
                          child: child,
                        ),
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
        );
      },
    );
  }
}

const double _okPressedShrink = 0.05;

class _Painter extends CustomPainter {
  _Painter(this.c, this.pressed, {required this.hold, required this.spread})
    : super(repaint: Listenable.merge([hold, spread]));
  final AppColors c;
  final RemoteButton? pressed;
  final Animation<double> hold, spread;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    final okRadius = r * .36;
    final strength = hold.value;
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
          radius: okRadius + (r - okRadius) * spread.value,
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
  }

  @override
  bool shouldRepaint(_Painter old) => old.pressed != pressed || old.c != c;
}
