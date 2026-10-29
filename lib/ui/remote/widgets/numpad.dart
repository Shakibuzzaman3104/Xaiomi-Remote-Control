/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../haptics.dart';

import '../../theme/app_colors.dart';
import '../remote_models.dart';
import '../../theme/app_theme.dart';

class Numpad extends StatelessWidget {
  const Numpad({super.key, required this.onButton});
  final ValueChanged<RemoteButton> onButton;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const labels = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      'CH −',
      '0',
      'CH +',
    ];
    const buttons = [
      RemoteButton.digit1,
      RemoteButton.digit2,
      RemoteButton.digit3,
      RemoteButton.digit4,
      RemoteButton.digit5,
      RemoteButton.digit6,
      RemoteButton.digit7,
      RemoteButton.digit8,
      RemoteButton.digit9,
      RemoteButton.channelDown,
      RemoteButton.digit0,
      RemoteButton.channelUp,
    ];
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 8,
        childAspectRatio: 1.33,
      ),
      itemCount: 12,
      itemBuilder: (context, i) => Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Semantics(
            label: labels[i],
            button: true,
            child: Material(
              type: MaterialType.transparency,
              child: Ink(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surfaceContainer,
                  border: Border.all(color: c.dpadOutline),
                ),
                child: InkResponse(
                  customBorder: const CircleBorder(),
                  containedInkWell: true,
                  onTap: () {
                    AppHaptics.selection();
                    onButton(buttons[i]);
                  },
                  child: Center(
                    child: Text(
                      labels[i],
                      style: context.appTextTheme.bodyMedium!.copyWith(
                        color: c.onSurfaceStrong,
                        fontSize: i == 9 || i == 11 ? 14 : 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
