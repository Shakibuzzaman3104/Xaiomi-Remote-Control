/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';

import 'package:flutter/material.dart';

import '../../fade_switcher.dart';
import '../../haptics.dart';
import '../../motion.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class RoundActionButton extends StatefulWidget {
  const RoundActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.size = 56,
    this.selected = false,
    this.showLabel = true,
    this.repeat = false,
    this.strong = false,
    this.onLongDown,
    this.onLongUp,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongDown, onLongUp;
  final double size;
  final bool selected, showLabel, repeat, strong;
  @override
  State<RoundActionButton> createState() => _RoundActionButtonState();
}

class _RoundActionButtonState extends State<RoundActionButton> {
  Timer? timer;
  bool pressed = false;
  bool longPressed = false;
  void start() {
    AppHaptics.selection();
    if (widget.onLongDown == null) widget.onPressed();
    setState(() => pressed = true);
    if (widget.onLongDown != null && widget.onLongUp != null) {
      timer = Timer(const Duration(milliseconds: 450), () {
        longPressed = true;
        AppHaptics.selection();
        widget.onLongDown!();
      });
    } else if (widget.repeat) {
      timer = Timer(const Duration(milliseconds: 350), () {
        widget.onPressed();
        timer = Timer.periodic(
          const Duration(milliseconds: 120),
          (_) => widget.onPressed(),
        );
      });
    }
  }

  void stop({bool cancel = false}) {
    if (pressed && widget.onLongDown != null) {
      if (longPressed) {
        widget.onLongUp?.call();
      } else if (!cancel) {
        widget.onPressed();
      }
    }
    longPressed = false;
    timer?.cancel();
    timer = null;
    if (pressed && mounted) setState(() => pressed = false);
  }

  @override
  void dispose() {
    timer?.cancel();
    if (longPressed) widget.onLongUp?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: widget.label,
      button: true,
      onTap: () {
        AppHaptics.selection();
        widget.onPressed();
      },
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => start(),
          onTapUp: (_) => stop(),
          onTapCancel: () => stop(cancel: true),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: pressed ? 0.95 : 1,
                duration: motion(
                  context,
                  pressed ? AppMotion.pressIn : AppMotion.pressOut,
                ),
                curve: AppMotion.easeOut,
                child: AnimatedContainer(
                  duration: motion(context, AppMotion.tint),
                  curve: AppMotion.easeOut,
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.selected
                        ? c.primary
                        : (pressed || widget.strong)
                        ? c.surfaceContainerStrong
                        : c.surfaceContainer,
                  ),
                  child: FadeSwitcher(
                    scale: 0.85,
                    duration: AppMotion.quick,
                    child: Icon(
                      widget.icon,
                      key: ValueKey(widget.icon),
                      color: widget.selected ? c.onPrimary : c.onSurface,
                      size: 25,
                    ),
                  ),
                ),
              ),
              if (widget.showLabel) ...[
                const SizedBox(height: 4),
                FadeSwitcher(
                  scale: 1,
                  duration: AppMotion.quick,
                  child: Text(
                    widget.label,
                    key: ValueKey(widget.label),
                    maxLines: 1,
                    style: context.appTextTheme.labelSmall!.copyWith(
                      color: c.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
