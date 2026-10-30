/**
 * @author Shakib
 * @since 30/10/26
 */
import 'package:flutter/material.dart';

import '../../haptics.dart';
import '../../physics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../remote_models.dart';

enum _AppAction { back, forward, captions, previous, next, search }

const _controlSets = {
  'com.google.android.youtube.tv': [
    _AppAction.back, _AppAction.forward, _AppAction.captions,
    _AppAction.previous, _AppAction.next, _AppAction.search,
  ],
};

class AppControls extends StatelessWidget {
  const AppControls({super.key, required this.data, required this.onSeekBy, required this.onButton, required this.onSearch});
  final AppControlData data;
  final ValueChanged<Duration> onSeekBy;
  final ValueChanged<RemoteButton> onButton;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final actions = _controlSets[data.package];
    if (actions == null) return const SizedBox.shrink();
    final options = <_AppAction, (String, IconData, VoidCallback)>{
      _AppAction.back: ('−10s', Icons.replay_10_rounded, () => onSeekBy(const Duration(seconds: -10))),
      _AppAction.forward: ('+10s', Icons.forward_10_rounded, () => onSeekBy(const Duration(seconds: 10))),
      _AppAction.captions: ('Captions', Icons.closed_caption_outlined, () => onButton(RemoteButton.captions)),
      _AppAction.previous: ('Previous', Icons.skip_previous_rounded, () => onButton(RemoteButton.previous)),
      _AppAction.next: ('Next', Icons.skip_next_rounded, () => onButton(RemoteButton.next)),
      _AppAction.search: ('Search', Icons.search_rounded, onSearch),
    };
    final controls = [for (final action in actions) options[action]!];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(children: [
              if (data.icon != null)
                ClipRRect(borderRadius: BorderRadius.circular(5), child: Image.memory(data.icon!, width: 24, height: 24, fit: BoxFit.cover))
              else
                Icon(Icons.live_tv_rounded, size: 24, color: context.colors.muted),
              const SizedBox(width: 6),
              Text(data.label, style: context.appTextTheme.labelMedium!.copyWith(color: context.colors.muted)),
            ]),
          ),
          for (var i = 0; i < controls.length; i++)
            SpringIn(
              delay: Duration(milliseconds: i * 40),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Center(child: SizedBox(height: 40, child: Semantics(
                  label: controls[i].$1,
                  button: true,
                  child: ExcludeSemantics(child: ActionChip(
                    avatar: Icon(controls[i].$2, size: 18),
                    label: Text(controls[i].$1),
                    onPressed: () { AppHaptics.selection(); controls[i].$3(); },
                    visualDensity: VisualDensity.compact,
                    backgroundColor: context.colors.surfaceContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  )),
                ))),
              ),
            ),
        ],
      ),
    );
  }
}
