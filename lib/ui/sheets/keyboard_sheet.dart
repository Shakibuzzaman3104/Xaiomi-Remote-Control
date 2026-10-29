/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../fade_switcher.dart';
import '../physics.dart';

import '../haptics.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class KeyboardSheet extends StatefulWidget {
  const KeyboardSheet({
    super.key,
    required this.fieldLabel,
    required this.initialText,
    required this.onChanged,
    required this.onSend,
    required this.onClear,
    required this.onClose,
    this.imeActive = true,
  });

  final String fieldLabel;
  final String initialText;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final bool imeActive;

  @override
  State<KeyboardSheet> createState() => _KeyboardSheetState();
}

class _KeyboardSheetState extends State<KeyboardSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void didUpdateWidget(covariant KeyboardSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText &&
        _controller.text != widget.initialText) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleClear() {
    AppHaptics.selection();
    _controller.clear();
    widget.onChanged('');
    widget.onClear();
  }

  void _handleSend() {
    AppHaptics.selection();
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

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
          padding: EdgeInsets.only(
            left: AppShapes.screenPadding,
            right: AppShapes.screenPadding,
            top: 12,
            bottom: bottomInset + 16,
          ),
          child: SpringIn(
            spring: AppSprings.smooth,
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
                const SizedBox(height: 12),
                Text(
                  widget.fieldLabel.isEmpty
                      ? 'Typing on TV'
                      : 'Typing on TV · ${widget.fieldLabel}',
                  style: context.appTextTheme.titleMedium!.copyWith(
                    color: c.onSurfaceStrong,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.send,
                  style: context.appTextTheme.bodyLarge!.copyWith(
                    color: c.onSurfaceStrong,
                  ),
                  cursorColor: c.primary,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: c.surfaceContainer.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppShapes.card),
                      borderSide: BorderSide(color: c.primary, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppShapes.card),
                      borderSide: BorderSide(color: c.primary, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppShapes.card),
                      borderSide: BorderSide(color: c.primary, width: 1.5),
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) {
                          return const SizedBox(width: 48);
                        }
                        return Center(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: Semantics(
                            button: true,
                            label: 'Clear text',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _handleClear,
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(
                                  Icons.cancel_rounded,
                                  color: c.muted,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  onChanged: widget.onChanged,
                  onSubmitted: (_) => _handleSend(),
                ),
                const SizedBox(height: 12),
                if (!widget.imeActive)
                  Text(
                    'Select a text field on the TV first.',
                    style: context.appTextTheme.bodyMedium,
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SpringTapFeedback(
                        child: Semantics(
                          button: true,
                          label: 'Clear',
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: FilledButton.tonalIcon(
                              onPressed: _handleClear,
                              icon: const Icon(
                                Icons.backspace_outlined,
                                size: 20,
                              ),
                              label: Text(
                                'Clear',
                                style: context.appTextTheme.displaySmall!,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: c.surfaceContainer,
                                side: BorderSide(color: c.subtleOutline),
                                foregroundColor: c.onSurfaceStrong,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppShapes.card,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SpringTapFeedback(
                        child: Semantics(
                          button: true,
                          label: 'Send',
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: FilledButton.icon(
                              onPressed: _handleSend,
                              icon: const Icon(Icons.send_outlined, size: 20),
                              label: Text(
                                'Send',
                                style: context.appTextTheme.displaySmall!,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: c.primary,
                                foregroundColor: c.onPrimary,
                                elevation: 0,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppShapes.card,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
