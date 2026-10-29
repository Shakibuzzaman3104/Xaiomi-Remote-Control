/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/widgets.dart';

abstract final class AppMotion {
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  static const Duration pressIn = Duration(milliseconds: 100);
  static const Duration pressOut = Duration(milliseconds: 150);
  static const Duration tint = Duration(milliseconds: 120);
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration swap = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration exit = Duration(milliseconds: 150);

  static const double enterScale = 0.95;
}

bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

Duration motion(BuildContext context, Duration duration) =>
    reduceMotion(context) ? Duration.zero : duration;

AnimationStyle sheetAnimation(BuildContext context) => AnimationStyle(
  duration: motion(context, AppMotion.standard),
  reverseDuration: motion(context, AppMotion.exit),
  curve: AppMotion.easeOut,
  reverseCurve: AppMotion.easeOut,
);
