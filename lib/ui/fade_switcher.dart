/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/widgets.dart';

import 'motion.dart';
import 'physics.dart';

/// Cross-fades between keyed children; scale and slide drop away under Reduce Motion.
class FadeSwitcher extends StatelessWidget {
  const FadeSwitcher({
    super.key,
    required this.child,
    this.scale = AppMotion.enterScale,
    this.duration = AppMotion.standard,
    this.reverseDuration = AppMotion.exit,
    this.expand = false,
    this.alignment = Alignment.center,
    this.slide = Offset.zero,
  });

  final Widget? child;
  final double scale;
  final Duration duration;
  final Duration reverseDuration;
  final bool expand;
  final AlignmentGeometry alignment;
  final Offset slide;

  @override
  Widget build(BuildContext context) {
    final scaled = !reduceMotion(context) && scale != 1;
    return AnimatedSwitcher(
      duration: motion(context, duration),
      reverseDuration: motion(context, reverseDuration),
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        fit: expand ? StackFit.expand : StackFit.loose,
        children: [...previous, ?current],
      ),
      transitionBuilder: (incoming, animation) {
        var moving = incoming;
        final spring = animation.drive(CurveTween(curve: SpringCurves.smooth));
        if (scaled) {
          moving = ScaleTransition(
            scale: Tween<double>(begin: scale, end: 1).animate(spring),
            child: moving,
          );
        }
        if (slide != Offset.zero && !reduceMotion(context)) {
          moving = SlideTransition(
            position: Tween<Offset>(
              begin: slide,
              end: Offset.zero,
            ).animate(spring),
            child: moving,
          );
        }
        final faded = FadeTransition(opacity: animation, child: moving);
        return IgnorePointer(
          ignoring: incoming.key != child?.key,
          child: faded,
        );
      },
      child: child,
    );
  }
}

class SpringTapFeedback extends StatefulWidget {
  const SpringTapFeedback({super.key, required this.child, this.scale = 0.97});
  final Widget child;
  final double scale;

  @override
  State<SpringTapFeedback> createState() => _SpringTapFeedbackState();
}

class _SpringTapFeedbackState extends State<SpringTapFeedback> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => pressed = true),
    onPointerUp: (_) => setState(() => pressed = false),
    onPointerCancel: (_) => setState(() => pressed = false),
    child: SpringPress(
      pressed: pressed && !reduceMotion(context),
      scale: widget.scale,
      child: widget.child,
    ),
  );
}
