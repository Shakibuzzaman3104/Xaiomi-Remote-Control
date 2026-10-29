/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import 'dart:async';

import '../../fade_switcher.dart';
import '../../haptics.dart';
import '../../motion.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
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
  Timer? _throttle;
  int? _pending;

  void _sendPending() {
    final value = _pending;
    _pending = null;
    if (value != null) widget.onExactVolumeChanged?.call(value);
  }

  @override
  void dispose() {
    _throttle?.cancel();
    super.dispose();
  }

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
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ExcludeSemantics(
                              child: Text(
                                'Volume ${((_dragIndex ?? widget.exactIndex!) * 100 / widget.exactMax!).round()}%',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.appTextTheme.labelMedium,
                              ),
                            ),
                            SizedBox(
                              height: 32,
                              child: Slider(
                                value: (_dragIndex ?? widget.exactIndex!)
                                    .clamp(0, widget.exactMax!)
                                    .toDouble(),
                                max: widget.exactMax!.toDouble(),
                                divisions: widget.exactMax,
                                semanticFormatterCallback: (value) =>
                                    'Volume ${(value * 100 / widget.exactMax!).round()}%',
                                activeColor: widget.muted ? c.muted : c.primary,
                                inactiveColor: c.progressTrack,
                                onChanged: (value) {
                                  setState(() => _dragIndex = value.round());
                                  _pending = value.round();
                                  _throttle ??= Timer(
                                    const Duration(milliseconds: 150),
                                    () {
                                      _throttle = null;
                                      _sendPending();
                                    },
                                  );
                                },
                                onChangeEnd: (value) {
                                  AppHaptics.selection();
                                  setState(() => _dragIndex = null);
                                  _throttle?.cancel();
                                  _throttle = null;
                                  _pending = value.round();
                                  _sendPending();
                                },
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: FadeSwitcher(
                            scale: 1,
                            slide: const Offset(0, 0.15),
                            duration: AppMotion.quick,
                            child: Text(
                              widget.muted
                                  ? 'Muted'
                                  : widget.level == null
                                  ? 'Volume'
                                  : 'Volume ${widget.level}%',
                              key: ValueKey(widget.muted ? -1 : widget.level),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.appTextTheme.labelLarge!.copyWith(
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
