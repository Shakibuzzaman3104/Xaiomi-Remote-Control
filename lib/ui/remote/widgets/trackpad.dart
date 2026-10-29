/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../haptics.dart';

import '../../theme/app_colors.dart';

class Trackpad extends StatefulWidget {
  const Trackpad({
    super.key,
    required this.onPointerMove,
    required this.onScroll,
    required this.onClick,
    required this.onAirMouseChanged,
  });
  final ValueChanged<Offset> onPointerMove;
  final ValueChanged<double> onScroll;
  final ValueChanged<bool> onClick, onAirMouseChanged;
  @override
  State<Trackpad> createState() => _TrackpadState();
}

class _TrackpadState extends State<Trackpad> {
  bool air = false;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Mouse trackpad',
                  child: GestureDetector(
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
        const SizedBox(height: 6),
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
                    child: Text(right ? 'Right click' : 'Left click'),
                  ),
                ),
              ),
          ],
        ),
        Row(
          children: [
            Text('Air mouse', style: TextStyle(color: c.onSurfaceStrong)),
            const Spacer(),
            Semantics(
              label: 'Air mouse',
              child: Switch(
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
