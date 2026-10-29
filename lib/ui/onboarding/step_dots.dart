/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.current, this.total = 3});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = <Widget>[];

    for (var i = 1; i <= total; i++) {
      final isCompletedOrCurrent = i <= current;
      items.add(
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompletedOrCurrent ? c.primary : c.surfaceContainer,
          ),
          alignment: Alignment.center,
          child: Text(
            '$i',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isCompletedOrCurrent ? c.onPrimary : c.muted,
            ),
          ),
        ),
      );

      if (i < total) {
        items.add(
          Container(
            width: 20,
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: c.surfaceContainer,
          ),
        );
      }
    }

    return Semantics(
      label: 'Step $current of $total',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: items,
      ),
    );
  }
}
