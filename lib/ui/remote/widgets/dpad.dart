/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../haptics.dart';

import '../../theme/app_colors.dart';
import '../remote_models.dart';

class Dpad extends StatefulWidget {
  const Dpad({super.key, required this.onButton});
  final ValueChanged<RemoteButton> onButton;
  @override
  State<Dpad> createState() => _DpadState();
}

class _DpadState extends State<Dpad> {
  RemoteButton? pressed;
  Timer? timer;
  void stop() {
    timer?.cancel();
    timer = null;
    if (pressed != null && mounted) setState(() => pressed = null);
  }

  void start(Offset p, double size) {
    final d = p - Offset(size / 2, size / 2);
    if (d.distance > size / 2) return;
    final b = d.distance < size * .18
        ? RemoteButton.ok
        : d.dx.abs() > d.dy.abs()
        ? (d.dx < 0 ? RemoteButton.left : RemoteButton.right)
        : (d.dy < 0 ? RemoteButton.up : RemoteButton.down);
    AppHaptics.selection();
    widget.onButton(b);
    setState(() => pressed = b);
    if (b != RemoteButton.ok) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final s = box.maxWidth;
        return Listener(
          onPointerDown: (e) => start(e.localPosition, s),
          onPointerUp: (_) => stop(),
          onPointerCancel: (_) => stop(),
          child: CustomPaint(
            painter: _Painter(c, pressed),
            child: SizedBox.square(
              dimension: s,
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      'OK',
                      style: TextStyle(
                        color: c.onSurfaceStrong,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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
        );
      },
    );
  }
}

class _Painter extends CustomPainter {
  _Painter(this.c, this.pressed);
  final AppColors c;
  final RemoteButton? pressed;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(center, r, Paint()..color = c.surfaceContainer);
    if (pressed != null && pressed != RemoteButton.ok) {
      final index = switch (pressed!) {
        RemoteButton.right => 0,
        RemoteButton.down => 1,
        RemoteButton.left => 2,
        _ => 3,
      };
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 4 + index * math.pi / 2,
        math.pi / 2,
        true,
        Paint()..color = c.surfaceContainerStrong,
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
      canvas.drawLine(center + v * r * .36, center + v * r, line);
    }
    canvas.drawCircle(
      center,
      r * .36,
      Paint()
        ..color = (pressed == RemoteButton.ok
            ? c.surfaceContainerStrong
            : c.okButton),
    );
    canvas.drawCircle(center, r * .36, line);
  }

  @override
  bool shouldRepaint(_Painter old) => old.pressed != pressed || old.c != c;
}
