/**
 * @author Shakib
 * @since 30/10/26
 */
import 'package:flutter/material.dart';

import '../motion.dart';
import '../physics.dart';
import '../theme/app_colors.dart';
import 'remote_models.dart';
import 'widgets/round_action_button.dart';
import 'widgets/swipe_pad.dart';
import 'widgets/trackpad.dart';

class ExpandedPadPage extends StatelessWidget {
  const ExpandedPadPage({
    super.key,
    required this.mode,
    required this.origin,
    required this.animation,
    required this.onButton,
    required this.onPointerMove,
    required this.onScroll,
    required this.onClick,
    this.onButtonDown,
    this.onButtonUp,
    this.onPointerLongPress,
    this.sensitivity = .5,
  });

  final RemoteMode mode;
  final Rect origin;
  final Animation<double> animation;
  final ValueChanged<RemoteButton> onButton;
  final ValueChanged<RemoteButton>? onButtonDown, onButtonUp;
  final ValueChanged<Offset> onPointerMove;
  final ValueChanged<double> onScroll;
  final ValueChanged<bool> onClick;
  final VoidCallback? onPointerLongPress;
  final double sensitivity;

  static Route<void> route({
    required RemoteMode mode,
    required Rect origin,
    required ValueChanged<RemoteButton> onButton,
    required ValueChanged<Offset> onPointerMove,
    required ValueChanged<double> onScroll,
    required ValueChanged<bool> onClick,
    ValueChanged<RemoteButton>? onButtonDown,
    ValueChanged<RemoteButton>? onButtonUp,
    VoidCallback? onPointerLongPress,
    double sensitivity = .5,
  }) => PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 600),
    reverseTransitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (context, animation, _) => ExpandedPadPage(
      mode: mode,
      origin: origin,
      animation: animation,
      onButton: onButton,
      onButtonDown: onButtonDown,
      onButtonUp: onButtonUp,
      onPointerMove: onPointerMove,
      onScroll: onScroll,
      onClick: onClick,
      onPointerLongPress: onPointerLongPress,
      sensitivity: sensitivity,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final safe = MediaQuery.paddingOf(context);
    final reduced = reduceMotion(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final landscape = constraints.maxWidth > constraints.maxHeight;
          final left = safe.left + 16;
          final top = safe.top + 16;
          final right = constraints.maxWidth - safe.right - 16;
          final bottom = constraints.maxHeight - safe.bottom - 16;
          final target = Rect.fromLTRB(
            left,
            top + 56,
            right - (landscape ? 88 : 0),
            bottom - (landscape ? 0 : 76),
          );
          final progress = reduced
              ? 1.0
              : SpringCurves.smooth.transform(animation.value).clamp(0.0, 1.0);
          final rect = Rect.lerp(origin, target, progress)!;
          final opacity = animation.value.clamp(0.0, 1.0);
          return Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: colors.background.withValues(alpha: opacity),
                  ),
                ),
                Positioned.fromRect(
                  rect: rect,
                  child: Opacity(
                    opacity: reduced ? opacity : 1,
                    child: mode == RemoteMode.swipe
                        ? SwipePad(
                            expanded: true,
                            radius: 16 + 12 * progress,
                            onButton: onButton,
                            onButtonDown: onButtonDown,
                            onButtonUp: onButtonUp,
                            sensitivity: sensitivity,
                          )
                        : Trackpad(
                            expanded: true,
                            radius: 16 + 12 * progress,
                            onPointerMove: onPointerMove,
                            onScroll: onScroll,
                            onClick: onClick,
                            onAirMouseChanged: (_) {},
                            onLongPress: onPointerLongPress,
                          ),
                  ),
                ),
                Positioned(
                  left: left,
                  right: constraints.maxWidth - right,
                  top: top,
                  height: 48,
                  child: Opacity(
                    opacity: opacity,
                    child: SpringIn(
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Collapse pad',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_fullscreen_rounded),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            mode == RemoteMode.swipe ? 'Swipe' : 'Mouse',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: landscape ? right - 80 : left,
                  right: constraints.maxWidth - right,
                  top: landscape ? top + 56 : null,
                  bottom: constraints.maxHeight - bottom,
                  height: landscape ? null : 64,
                  child: Opacity(
                    opacity: opacity,
                    child: SpringIn(
                      delay: const Duration(milliseconds: 40),
                      child: _actions(landscape),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: top + 56,
                  bottom: constraints.maxHeight - bottom,
                  width: 16,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) > 100) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _actions(bool landscape) {
    final items = mode == RemoteMode.swipe
        ? [
            _button('Back', Icons.arrow_back_rounded, RemoteButton.back),
            _button('Home', Icons.home_outlined, RemoteButton.home),
            _button(
              'Play/Pause',
              Icons.play_arrow_rounded,
              RemoteButton.playPause,
            ),
          ]
        : [
            RoundActionButton(
              label: 'Click',
              icon: Icons.touch_app_outlined,
              showLabel: false,
              onPressed: () => onClick(false),
            ),
            RoundActionButton(
              label: 'Back',
              icon: Icons.arrow_back_rounded,
              showLabel: false,
              onPressed: () => onClick(true),
            ),
          ];
    return Flex(
      direction: landscape ? Axis.vertical : Axis.horizontal,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items,
    );
  }

  Widget _button(String label, IconData icon, RemoteButton button) =>
      RoundActionButton(
        label: label,
        icon: icon,
        showLabel: false,
        onPressed: () => onButton(button),
        onLongDown: onButtonDown == null || onButtonUp == null
            ? null
            : () => onButtonDown!(button),
        onLongUp: onButtonDown == null || onButtonUp == null
            ? null
            : () => onButtonUp!(button),
      );
}
