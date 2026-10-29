/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  });

  final bool listening;
  final String transcript;
  final VoiceTarget target;
  final ValueChanged<VoiceTarget> onTargetChanged;
  final VoidCallback onMicTap;
  final VoidCallback onCancel;
  final bool typeIntoFieldAvailable;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final String displayText;
    final Color textColor;
    if (transcript.isNotEmpty) {
      displayText = transcript;
      textColor = c.onSurfaceStrong;
    } else if (listening) {
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
            vertical: 16,
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
              const SizedBox(height: 24),
              Center(
                child: Semantics(
                  button: true,
                  label: listening ? 'Stop listening' : 'Start listening',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onMicTap();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: listening ? 132 : 108,
                      height: listening ? 132 : 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.primary.withValues(alpha: 0.12),
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
                          size: 40,
                          color: c.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Center(
                  child: Text(
                    displayText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _TargetChip(
                      label: 'Search on TV',
                      icon: Icons.search_rounded,
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
                      HapticFeedback.selectionClick();
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
      backgroundColor = c.appTile;
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
                    HapticFeedback.selectionClick();
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
