/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../haptics.dart';
import '../../motion.dart';

import '../../theme/app_colors.dart';
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
      Icons.dialpad,
    ];
    final labels = ['D-pad', 'Swipe', 'Mouse', 'Numpad'];
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    const labelStyle = TextStyle(fontSize: 13);

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
            (label) => 8 + 19 + 4 + labelWidth(label) > tabWidth,
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(4, (i) {
              final selected = mode.index == i;
              final color = selected ? c.onPrimary : c.onSurface;
              return Expanded(
                child: Tooltip(
                  message: labels[i],
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: labels[i],
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        AppHaptics.selection();
                        onChanged(RemoteMode.values[i]);
                      },
                      child: AnimatedContainer(
                        duration: motion(context, AppMotion.quick),
                        curve: AppMotion.easeOut,
                        decoration: BoxDecoration(
                          color: selected ? c.primary : c.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icons[i], size: 19, color: color),
                            if (!iconsOnly) ...[
                              const SizedBox(width: 4),
                              Text(
                                labels[i],
                                maxLines: 1,
                                softWrap: false,
                                style: labelStyle.copyWith(color: color),
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
          );
        },
      ),
    );
  }
}
