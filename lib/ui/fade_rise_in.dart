/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/widgets.dart';

import 'motion.dart';
import 'physics.dart';

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
    return SpringIn(
      rise: rise,
      fromScale: 1,
      spring: AppSprings.smooth,
      child: child,
    );
  }
}
