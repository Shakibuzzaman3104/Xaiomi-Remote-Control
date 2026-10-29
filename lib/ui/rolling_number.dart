/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'physics.dart';

/// Shows [value] as odometer digits that roll to new values on a spring.
class RollingNumber extends StatelessWidget {
  const RollingNumber({
    super.key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.suffix = '',
  });

  final int value;
  final TextStyle style;
  final String prefix, suffix;

  @override
  Widget build(BuildContext context) {
    final digitStyle = style.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      height: 1.2,
    );
    final height = (digitStyle.fontSize ?? 14) * 1.2;
    final places = math.max(1, value.abs().toString().length);
    return Semantics(
      label: '$prefix$value$suffix',
      excludeSemantics: true,
      child: SpringValue(
        value: value.toDouble(),
        spring: AppSprings.settle,
        builder: (context, number, _) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prefix.isNotEmpty) Text(prefix, style: digitStyle),
              for (var place = places - 1; place >= 0; place--)
                _Digit(
                  position: _digitPosition(number, place),
                  height: height,
                  style: digitStyle,
                ),
              if (suffix.isNotEmpty) Text(suffix, style: digitStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rolls a digit only while every lower digit carries over, like an odometer.
double _digitPosition(double number, int place) {
  final unit = math.pow(10, place).toDouble();
  final whole = (number / unit).floorToDouble();
  if (place == 0) return number;
  final carry = number % unit - (unit - 1);
  return whole + carry.clamp(0.0, 1.0);
}

class _Digit extends StatelessWidget {
  const _Digit({
    required this.position,
    required this.height,
    required this.style,
  });

  final double position, height;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final lower = position.floor() % 10;
    final fraction = position - position.floor();
    return SizedBox(
      height: height,
      child: ClipRect(
        child: Stack(
          children: [
            Opacity(opacity: 0, child: Text('0', style: style)),
            Transform.translate(
              offset: Offset(0, -fraction * height),
              child: Text('$lower', style: style),
            ),
            Transform.translate(
              offset: Offset(0, (1 - fraction) * height),
              child: Text('${(lower + 1) % 10}', style: style),
            ),
          ],
        ),
      ),
    );
  }
}
