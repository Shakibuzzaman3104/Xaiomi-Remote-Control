/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../fade_switcher.dart';
import '../../haptics.dart';
import '../../motion.dart';
import '../../theme/app_colors.dart';
import '../remote_models.dart';
import 'round_action_button.dart';

class VolumePill extends StatefulWidget {
  const VolumePill({
    super.key,
    required this.level,
    required this.muted,
    required this.onButton,
    this.exactIndex,
    this.exactMax,
    this.onExactVolumeChanged,
  });

  /// Volume in percent, or null when the TV doesn't report it.
  final int? level;
  final bool muted;
  final ValueChanged<RemoteButton> onButton;
  final int? exactIndex, exactMax;
  final ValueChanged<int>? onExactVolumeChanged;

  @override
  State<VolumePill> createState() => _VolumePillState();
}

class _VolumePillState extends State<VolumePill> {
  int? _dragIndex;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                RoundActionButton(
                  label: 'Volume down',
                  icon: Icons.remove,
                  onPressed: () => widget.onButton(RemoteButton.volumeDown),
                  showLabel: false,
                  repeat: true,
                  strong: true,
                  size: 48,
                ),
                Expanded(
                  child:
                      widget.exactIndex != null &&
                          widget.exactMax != null &&
                          widget.exactMax! > 0 &&
                          widget.onExactVolumeChanged != null
                      ? Semantics(
                          label: 'Volume',
                          child: Slider(
                            value: (_dragIndex ?? widget.exactIndex!)
                                .clamp(0, widget.exactMax!)
                                .toDouble(),
                            max: widget.exactMax!.toDouble(),
                            divisions: widget.exactMax,
                            label:
                                '${((_dragIndex ?? widget.exactIndex!).clamp(0, widget.exactMax!) * 100 / widget.exactMax!).round()}%',
                            semanticFormatterCallback: (value) =>
                                '${(value * 100 / widget.exactMax!).round()}%',
                            activeColor: c.primary,
                            inactiveColor: c.progressTrack,
                            onChanged: (value) =>
                                setState(() => _dragIndex = value.round()),
                            onChangeEnd: (value) {
                              AppHaptics.selection();
                              setState(() => _dragIndex = null);
                              widget.onExactVolumeChanged!(value.round());
                            },
                          ),
                        )
                      : Center(
                          child: FadeSwitcher(
                            scale: 1,
                            slide: const Offset(0, 0.15),
                            duration: AppMotion.quick,
                            child: Text(
                              widget.level == null
                                  ? 'Volume'
                                  : 'Volume ${widget.level}%',
                              key: ValueKey(widget.level),
                              style: TextStyle(
                                color: c.onSurfaceStrong,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
                RoundActionButton(
                  label: 'Volume up',
                  icon: Icons.add,
                  onPressed: () => widget.onButton(RemoteButton.volumeUp),
                  showLabel: false,
                  repeat: true,
                  strong: true,
                  size: 48,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        RoundActionButton(
          label: widget.muted ? 'Unmute' : 'Mute',
          icon: widget.muted
              ? Icons.volume_off_outlined
              : Icons.volume_up_outlined,
          selected: widget.muted,
          onPressed: () => widget.onButton(RemoteButton.mute),
        ),
      ],
    );
  }
}
