/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class StepDots extends StatelessWidget {
  const StepDots({
    super.key,
    required this.current,
    this.total = 3,
    this.numbered = true,
  });
  final int current;
  final int total;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Step $current of $total',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= total; i++) ...[
            if (i > 1)
              SizedBox(
                width: numbered ? 42 : 15,
                child: numbered
                    ? Divider(
                        indent: 7,
                        endIndent: 7,
                        thickness: 3,
                        color: c.surfaceContainerStrong,
                      )
                    : null,
              ),
            Container(
              width: numbered ? 28 : 10,
              height: numbered ? 28 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (numbered ? i <= current : i == current)
                    ? c.primary
                    : (numbered ? c.surfaceContainerStrong : c.okButton),
              ),
              alignment: Alignment.center,
              child: numbered
                  ? Text(
                      '$i',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: i <= current ? c.onPrimary : c.onSurfaceStrong,
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
