/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../haptics.dart';
import '../../physics.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../remote_models.dart';

class ModeSwitcher extends StatelessWidget {
  const ModeSwitcher({super.key, required this.mode, required this.onChanged});
  final RemoteMode mode;
  final ValueChanged<RemoteMode> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final icons = [
      Icons.gamepad_outlined,
      Icons.touch_app_outlined,
      Icons.mouse_outlined,
      Icons.dialpad_rounded,
    ];
    final labels = ['D-pad', 'Swipe', 'Mouse', 'Numpad'];
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final labelStyle = context.appTextTheme.bodySmall!;

    double labelWidth(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textScaler: textScaler,
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 4;
          final iconsOnly = labels.any(
            (label) => 8 + 20 + 4 + labelWidth(label) > tabWidth,
          );
          return Stack(
            children: [
              SpringValue(
                value: mode.index.toDouble(),
                builder: (context, position, _) => Positioned(
                  left: position * tabWidth,
                  top: 0,
                  bottom: 0,
                  width: tabWidth,
                  child: Transform.scale(
                    scaleX:
                        1 +
                        ((mode.index - position).abs() * 0.025).clamp(
                          0.0,
                          0.06,
                        ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(4, (i) {
                  final selected = mode.index == i;
                  return Expanded(
                    child: Tooltip(
                      message: labels[i],
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: labels[i],
                        excludeSemantics: true,
                        onTap: () => onChanged(RemoteMode.values[i]),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            AppHaptics.selection();
                            onChanged(RemoteMode.values[i]);
                          },
                          child: SpringValue(
                            value: selected ? 1 : 0,
                            spring: AppSprings.settle,
                            builder: (context, amount, _) => Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icons[i],
                                  size: 20,
                                  color: Color.lerp(
                                    c.onSurface,
                                    c.onPrimary,
                                    amount.clamp(0.0, 1.0),
                                  ),
                                ),
                                if (!iconsOnly) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    labels[i],
                                    maxLines: 1,
                                    softWrap: false,
                                    style: labelStyle.copyWith(
                                      color: Color.lerp(
                                        c.onSurface,
                                        c.onPrimary,
                                        amount.clamp(0.0, 1.0),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
