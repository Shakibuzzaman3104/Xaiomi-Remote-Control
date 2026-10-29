/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Spring presets shared by every physics-driven animation.
abstract final class AppSprings {
  /// Fast, firm follow-through for press feedback.
  static final press = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 900,
    ratio: 0.55,
  );

  /// Lively settle with a visible overshoot for things that arrive.
  static final bouncy = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.62,
  );

  /// Calm settle with a hint of overshoot for layout and sheets.
  static final smooth = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 300,
    ratio: 0.82,
  );

  /// Critically damped, no overshoot, for values users read.
  static final settle = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: 1,
  );
}

/// A curve that follows a spring from 0 to 1, for APIs that only take curves.
class SpringCurve extends Curve {
  SpringCurve(this.spring, {this.duration = const Duration(milliseconds: 600)})
    : _simulation = SpringSimulation(spring, 0, 1, 0);

  final SpringDescription spring;
  final Duration duration;
  final SpringSimulation _simulation;

  @override
  double transformInternal(double t) => _simulation.x(
    t * duration.inMicroseconds / Duration.microsecondsPerSecond,
  );
}

/// Curves made from the spring presets.
abstract final class SpringCurves {
  static final bouncy = SpringCurve(AppSprings.bouncy);
  static final smooth = SpringCurve(AppSprings.smooth);
  static final settle = SpringCurve(AppSprings.settle);
}

/// Animates [value] towards its target with a spring, keeping velocity when
/// the target changes mid-flight.
class SpringValue extends StatefulWidget {
  const SpringValue({
    super.key,
    required this.value,
    required this.builder,
    this.spring,
    this.child,
  });

  final double value;
  final SpringDescription? spring;
  final ValueWidgetBuilder<double> builder;
  final Widget? child;

  @override
  State<SpringValue> createState() => _SpringValueState();
}

class _SpringValueState extends State<SpringValue>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController.unbounded(
    vsync: this,
    value: widget.value,
  );

  @override
  void didUpdateWidget(SpringValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    if (reduceMotion(context)) {
      controller.value = widget.value;
      return;
    }
    controller.animateWith(
      SpringSimulation(
        widget.spring ?? AppSprings.smooth,
        controller.value,
        widget.value,
        controller.velocity,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (context, child) =>
        widget.builder(context, controller.value, child),
  );
}

/// Squashes its child while [pressed] and springs it back on release.
class SpringPress extends StatelessWidget {
  const SpringPress({
    super.key,
    required this.pressed,
    required this.child,
    this.scale = 0.92,
  });

  final bool pressed;
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) => SpringValue(
    value: pressed ? scale : 1,
    spring: pressed ? AppSprings.press : AppSprings.bouncy,
    child: child,
    builder: (context, s, child) => Transform.scale(scale: s, child: child),
  );
}

/// Springs its child in once when first mounted, optionally after [delay].
class SpringIn extends StatefulWidget {
  const SpringIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.rise = 16,
    this.fromScale = 0.94,
    this.animate = true,
    this.spring,
  });

  final Widget child;
  final Duration delay;
  final double rise, fromScale;
  final bool animate;
  final SpringDescription? spring;

  @override
  State<SpringIn> createState() => _SpringInState();
}

class _SpringInState extends State<SpringIn>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController.unbounded(vsync: this);
  Timer? delay;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    if (!widget.animate || reduceMotion(context)) {
      controller.value = 1;
      return;
    }
    void start() => controller.animateWith(
      SpringSimulation(widget.spring ?? AppSprings.bouncy, 0, 1, 0),
    );
    widget.delay == Duration.zero
        ? start()
        : delay = Timer(widget.delay, start);
  }

  @override
  void dispose() {
    delay?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (context, child) {
      final t = controller.value;
      return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * widget.rise),
          child: Transform.scale(
            scale: widget.fromScale + (1 - widget.fromScale) * t,
            child: child,
          ),
        ),
      );
    },
  );
}
