/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../haptics.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

enum VoiceTarget { search, typeIntoField }

class VoiceSheet extends StatelessWidget {
  const VoiceSheet({
    super.key,
    required this.listening,
    required this.transcript,
    required this.target,
    required this.onTargetChanged,
    required this.onMicTap,
    required this.onCancel,
    this.typeIntoFieldAvailable = true,
    this.errorText,
  });

  final bool listening;
  final String transcript;
  final VoiceTarget target;
  final ValueChanged<VoiceTarget> onTargetChanged;
  final VoidCallback onMicTap;
  final VoidCallback onCancel;
  final bool typeIntoFieldAvailable;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final String displayText;
    final Color textColor;
    final isListening = listening && errorText == null;
    if (errorText != null) {
      displayText = errorText!;
      textColor = c.danger;
    } else if (transcript.isNotEmpty) {
      displayText = transcript;
      textColor = c.onSurfaceStrong;
    } else if (isListening) {
      displayText = 'Listening…';
      textColor = c.muted;
    } else {
      displayText = 'Tap the mic to speak';
      textColor = c.muted;
    }

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppShapes.card),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppShapes.screenPadding,
            vertical: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.surfaceContainerStrong,
                    borderRadius: BorderRadius.circular(AppShapes.pill),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Semantics(
                  button: true,
                  label: isListening ? 'Stop listening' : 'Start listening',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      AppHaptics.selection();
                      onMicTap();
                    },
                    child: _MicRing(
                      listening: isListening,
                      child: Container(
                        width: 114,
                        height: 114,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.primary.withValues(alpha: 0.06),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.primary,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.mic_rounded,
                            size: 36,
                            color: c.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Semantics(
                  liveRegion: errorText != null,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayText,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.appTextTheme.bodyLarge!.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (errorText == null && transcript.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 1.5,
                            height: 23,
                            color: c.primaryText,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _TargetChip(
                      label: 'Search YouTube',
                      icon: Icons.smart_display_rounded,
                      selected: target == VoiceTarget.search,
                      enabled: true,
                      onTap: () => onTargetChanged(VoiceTarget.search),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TargetChip(
                      label: 'Type into field',
                      icon: Icons.keyboard_alt_outlined,
                      selected: target == VoiceTarget.typeIntoField,
                      enabled: typeIntoFieldAvailable,
                      onTap: () => onTargetChanged(VoiceTarget.typeIntoField),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    minWidth: 48,
                  ),
                  child: TextButton(
                    onPressed: () {
                      AppHaptics.selection();
                      onCancel();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: c.primaryText,
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppShapes.card),
                      ),
                    ),
                    child: Semantics(
                      button: true,
                      label: 'Cancel',
                      child: Text(
                        'Cancel',
                        style: context.appTextTheme.displaySmall!.copyWith(
                          color: c.primaryText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicRing extends StatefulWidget {
  const _MicRing({required this.listening, required this.child});

  final bool listening;
  final Widget child;

  @override
  State<_MicRing> createState() => _MicRingState();
}

class _MicRingState extends State<_MicRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  void syncAnimation() {
    if (widget.listening && !MediaQuery.disableAnimationsOf(context)) {
      if (!controller.isAnimating) controller.repeat(reverse: true);
    } else {
      controller.stop();
      controller.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _MicRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncAnimation();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: 138,
      height: 138,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) => Transform.scale(
              scale: 1 + 0.08 * Curves.easeOut.transform(controller.value),
              child: child,
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primary.withValues(
                  alpha: widget.listening && reduced ? 0.16 : 0.06,
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final Color backgroundColor;
    final Color contentColor;
    Border? border;

    if (selected) {
      backgroundColor = c.okButton;
      contentColor = c.primaryText;
    } else {
      backgroundColor = c.background;
      contentColor = c.onSurface;
      border = Border.all(color: c.subtleOutline);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Material(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShapes.card),
            side: border?.top ?? BorderSide.none,
          ),
          child: InkWell(
            onTap: enabled
                ? () {
                    AppHaptics.selection();
                    onTap();
                  }
                : null,
            borderRadius: BorderRadius.circular(AppShapes.card),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: contentColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: context.appTextTheme.labelLarge!.copyWith(
                        color: contentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
