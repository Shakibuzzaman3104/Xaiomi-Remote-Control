/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';

import 'package:flutter/material.dart';

import '../../haptics.dart';

import '../../theme/app_colors.dart';
import '../remote_models.dart';

class SwipePad extends StatefulWidget {
  const SwipePad({super.key, required this.onButton, this.sensitivity = 0.5});

  final ValueChanged<RemoteButton> onButton;
  final double sensitivity;

  @override
  State<SwipePad> createState() => _SwipePadState();
}

class _SwipePadState extends State<SwipePad> {
  final Map<int, Offset> points = {};
  final Map<int, Offset> origins = {};
  Offset? origin;
  int maxPointers = 0;
  bool moved = false;
  Timer? timer;
  RemoteButton? direction;

  void emit(RemoteButton button) {
    AppHaptics.selection();
    widget.onButton(button);
  }

  void down(PointerDownEvent event) {
    points[event.pointer] = event.localPosition;
    origins[event.pointer] = event.localPosition;
    maxPointers = points.length > maxPointers ? points.length : maxPointers;
    origin ??= event.localPosition;
    if (points.length > 1) {
      timer?.cancel();
      timer = null;
    }
  }

  double get threshold => 32 - 16 * widget.sensitivity.clamp(0.0, 1.0);

  void move(PointerMoveEvent event) {
    points[event.pointer] = event.localPosition;
    if (maxPointers > 1) {
      final start = origins[event.pointer];
      if (start != null &&
          (event.localPosition - start).distance >= threshold) {
        moved = true;
      }
      return;
    }
    if (origin == null || direction != null) return;
    final delta = event.localPosition - origin!;
    if (delta.distance < threshold) return;
    moved = true;
    direction = delta.dx.abs() > delta.dy.abs()
        ? (delta.dx < 0 ? RemoteButton.left : RemoteButton.right)
        : (delta.dy < 0 ? RemoteButton.up : RemoteButton.down);
    emit(direction!);
    timer = Timer(const Duration(milliseconds: 350), () {
      timer = Timer.periodic(
        const Duration(milliseconds: 120),
        (_) => widget.onButton(direction!),
      );
    });
  }

  void up(PointerEvent event, {bool cancel = false}) {
    points.remove(event.pointer);
    origins.remove(event.pointer);
    if (cancel) moved = true;
    if (points.isNotEmpty) return;
    timer?.cancel();
    if (!moved) emit(maxPointers >= 2 ? RemoteButton.back : RemoteButton.ok);
    origin = null;
    maxPointers = 0;
    moved = false;
    direction = null;
  }

  @override
  void dispose() {
    timer?.cancel();
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Swipe to move · Tap to select · Two fingers to go back',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.muted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
