/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Fades and lifts its child in once when first mounted.
class FadeRiseIn extends StatelessWidget {
  const FadeRiseIn({
    super.key,
    required this.child,
    this.animate = true,
    this.rise = 8,
  });

  final Widget child;
  final bool animate;
  final double rise;

  @override
  Widget build(BuildContext context) {
    if (!animate || reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.standard,
      curve: AppMotion.easeOut,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * rise),
          child: child,
        ),
      ),
    );
  }
}
