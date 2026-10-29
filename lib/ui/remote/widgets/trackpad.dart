/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../haptics.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class Trackpad extends StatefulWidget {
  const Trackpad({
    super.key,
    required this.onPointerMove,
    required this.onScroll,
    required this.onClick,
    required this.onAirMouseChanged,
    this.onLongPress,
  });
  final ValueChanged<Offset> onPointerMove;
  final ValueChanged<double> onScroll;
  final ValueChanged<bool> onClick, onAirMouseChanged;
  final VoidCallback? onLongPress;
  @override
  State<Trackpad> createState() => _TrackpadState();
}

class _TrackpadState extends State<Trackpad> {
  bool air = false;

  @override
  void dispose() {
    if (air) widget.onAirMouseChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Semantics(
                  label: 'Mouse trackpad',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      AppHaptics.selection();
                      widget.onClick(false);
                    },
                    onLongPress: widget.onLongPress == null
                        ? null
                        : () {
                            AppHaptics.medium();
                            widget.onLongPress!();
                          },
                    onPanUpdate: (d) => widget.onPointerMove(d.delta),
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.dpadOutline),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                label: 'Scroll',
                child: GestureDetector(
                  onVerticalDragUpdate: (d) => widget.onScroll(d.delta.dy),
                  child: Container(
                    width: 48,
                    decoration: BoxDecoration(
                      color: c.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.unfold_more, color: c.muted),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final right in [false, true])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextButton(
                    onPressed: () {
                      AppHaptics.selection();
                      widget.onClick(right);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: c.surfaceContainer,
                      foregroundColor: c.onSurface,
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(right ? 'Back' : 'Click'),
                  ),
                ),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                air ? 'Point the phone at the TV and turn it' : 'Air mouse',
                style: context.appTextTheme.bodyMedium!.copyWith(
                  color: c.onSurfaceStrong,
                ),
              ),
            ),
            Semantics(
              label: 'Air mouse',
              child: Switch.adaptive(
                activeTrackColor: c.primary,
                value: air,
                onChanged: (v) {
                  AppHaptics.selection();
                  setState(() => air = v);
                  widget.onAirMouseChanged(v);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
