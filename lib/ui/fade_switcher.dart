/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/widgets.dart';

import 'motion.dart';

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
      switchInCurve: AppMotion.easeOut,
      switchOutCurve: AppMotion.easeOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        fit: expand ? StackFit.expand : StackFit.loose,
        children: [...previous, ?current],
      ),
      transitionBuilder: (incoming, animation) {
        var moving = incoming;
        if (scaled) {
          moving = ScaleTransition(
            scale: Tween<double>(begin: scale, end: 1).animate(animation),
            child: moving,
          );
        }
        if (slide != Offset.zero && !reduceMotion(context)) {
          moving = SlideTransition(
            position: Tween<Offset>(
              begin: slide,
              end: Offset.zero,
            ).animate(animation),
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
