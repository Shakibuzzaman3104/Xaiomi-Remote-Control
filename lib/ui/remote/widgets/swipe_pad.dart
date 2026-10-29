/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';

import 'package:flutter/material.dart';

import '../../haptics.dart';
import '../../motion.dart';
import '../../theme/app_colors.dart';
import '../remote_models.dart';

class SwipePad extends StatefulWidget {
  const SwipePad({
    super.key,
    required this.onButton,
    this.sensitivity = 0.5,
    this.onButtonDown,
    this.onButtonUp,
  });

  final ValueChanged<RemoteButton> onButton;
  final double sensitivity;
  final ValueChanged<RemoteButton>? onButtonDown, onButtonUp;

  @override
  State<SwipePad> createState() => _SwipePadState();
}

class _SwipePadState extends State<SwipePad> with TickerProviderStateMixin {
  final Map<int, Offset> points = {};
  final Map<int, Offset> origins = {};
  Offset? origin;
  int maxPointers = 0;
  bool moved = false;
  Timer? timer;
  bool longPressed = false;
  RemoteButton? flashDirection;
  final touch = ValueNotifier<Offset?>(null);
  late final contact = AnimationController(vsync: this);
  late final flash = AnimationController(vsync: this);

  void emit(RemoteButton button) {
    AppHaptics.selection();
    widget.onButton(button);
  }

  void down(PointerDownEvent event) {
    points[event.pointer] = event.localPosition;
    origins[event.pointer] = event.localPosition;
    maxPointers = points.length > maxPointers ? points.length : maxPointers;
    origin ??= event.localPosition;
    touch.value = event.localPosition;
    contact.animateTo(
      1,
      duration: motion(context, AppMotion.pressIn),
      curve: AppMotion.easeOut,
    );
    if (points.length == 1 &&
        widget.onButtonDown != null &&
        widget.onButtonUp != null) {
      timer = Timer(const Duration(milliseconds: 450), () {
        if (!moved && points.length == 1) {
          longPressed = true;
          AppHaptics.selection();
          widget.onButtonDown!(RemoteButton.ok);
        }
      });
    }
    if (points.length > 1) {
      timer?.cancel();
      timer = null;
    }
  }

  double get threshold => 52 - 16 * widget.sensitivity.clamp(0.0, 1.0);

  void move(PointerMoveEvent event) {
    points[event.pointer] = event.localPosition;
    touch.value = event.localPosition;
    if (maxPointers > 1) {
      final start = origins[event.pointer];
      if (start != null &&
          (event.localPosition - start).distance >= threshold) {
        moved = true;
      }
      return;
    }
    if (origin == null || longPressed) return;
    var delta = event.localPosition - origin!;
    while (delta.distance >= threshold) {
      moved = true;
      timer?.cancel();
      final horizontal = delta.dx.abs() > delta.dy.abs();
      final direction = horizontal
          ? (delta.dx < 0 ? RemoteButton.left : RemoteButton.right)
          : (delta.dy < 0 ? RemoteButton.up : RemoteButton.down);
      origin =
          origin! +
          (horizontal
              ? Offset(delta.dx.sign * threshold, 0)
              : Offset(0, delta.dy.sign * threshold));
      delta = event.localPosition - origin!;
      emit(direction);
      flashDirection = direction;
      flash.forward(from: 0);
    }
  }

  void up(PointerEvent event, {bool cancel = false}) {
    points.remove(event.pointer);
    origins.remove(event.pointer);
    if (cancel) moved = true;
    if (points.isNotEmpty) {
      touch.value = points.values.last;
      return;
    }
    contact.animateBack(
      0,
      duration: motion(context, AppMotion.quick),
      curve: AppMotion.easeOut,
    );
    timer?.cancel();
    if (longPressed) {
      widget.onButtonUp?.call(RemoteButton.ok);
    } else if (!moved) {
      emit(maxPointers >= 2 ? RemoteButton.back : RemoteButton.ok);
    }
    longPressed = false;
    origin = null;
    maxPointers = 0;
    moved = false;
  }

  @override
  void dispose() {
    timer?.cancel();
    if (longPressed) widget.onButtonUp?.call(RemoteButton.ok);
    touch.dispose();
    contact.dispose();
    flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'Swipe pad',
      child: Listener(
        onPointerDown: down,
        onPointerMove: move,
        onPointerUp: up,
        onPointerCancel: (event) => up(event, cancel: true),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.dpadOutline),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Swipe to move · Tap to select · Two fingers to go back',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.muted),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _TouchPainter(
                              colors.primary,
                              touch,
                              contact,
                            ),
                          ),
                        ),
                        _DirectionFlash(
                          animation: flash,
                          direction: () => flashDirection,
                          color: colors.primary,
                          drift: reduceMotion(context) ? 0 : 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TouchPainter extends CustomPainter {
  _TouchPainter(this.color, this.touch, this.contact)
    : super(repaint: Listenable.merge([touch, contact]));
  final Color color;
  final ValueNotifier<Offset?> touch;
  final Animation<double> contact;

  @override
  void paint(Canvas canvas, Size size) {
    final position = touch.value;
    final strength = contact.value;
    if (position == null || strength <= 0) return;
    canvas.drawCircle(
      position,
      26 * (0.6 + 0.4 * strength),
      Paint()..color = color.withValues(alpha: 0.14 * strength),
    );
  }

  @override
  bool shouldRepaint(_TouchPainter old) => old.color != color;
}

class _DirectionFlash extends StatelessWidget {
  const _DirectionFlash({
    required this.animation,
    required this.direction,
    required this.color,
    required this.drift,
  });
  final Animation<double> animation;
  final RemoteButton? Function() direction;
  final Color color;
  final double drift;

  static final _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 70),
  ]);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final button = direction();
        if (button == null || !animation.isAnimating) {
          return const SizedBox.shrink();
        }
        final (icon, axis) = switch (button) {
          RemoteButton.up => (Icons.keyboard_arrow_up, const Offset(0, -1)),
          RemoteButton.down => (Icons.keyboard_arrow_down, const Offset(0, 1)),
          RemoteButton.left => (Icons.keyboard_arrow_left, const Offset(-1, 0)),
          _ => (Icons.keyboard_arrow_right, const Offset(1, 0)),
        };
        final t = AppMotion.easeOut.transform(animation.value);
        return Align(
          alignment: Alignment(axis.dx * 0.72, axis.dy * 0.72),
          child: Opacity(
            opacity: _opacity.transform(animation.value) * 0.8,
            child: Transform.translate(
              offset: axis * drift * t,
              child: Icon(icon, size: 44, color: color),
            ),
          ),
        );
      },
    );
  }
}
