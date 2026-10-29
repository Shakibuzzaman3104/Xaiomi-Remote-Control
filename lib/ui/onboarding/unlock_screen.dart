/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'step_dots.dart';

class UnlockScreen extends StatelessWidget {
  const UnlockScreen({
    super.key,
    required this.statusText,
    required this.connecting,
    required this.connected,
    required this.onConnect,
    required this.onSkip,
  });

  final String statusText;
  final bool connecting;
  final bool connected;
  final VoidCallback onConnect;
  final VoidCallback onSkip;

  static const _steps = [
    'On the TV open Settings › Device Preferences › About',
    'Click Build 7 times to become a developer',
    'Open Developer options and turn on Network debugging',
    'Tap Connect, then choose Always allow on the TV',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppShapes.screenPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Center(child: StepDots(current: 3)),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Unlock full control',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: c.onSurfaceStrong,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Optional. Lets you open any app, manage apps, see what\'s playing, take screenshots and mirror the TV.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: c.muted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.surfaceContainer,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone_android_rounded,
                                size: 36,
                                color: c.primary,
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.settings_rounded,
                                size: 28,
                                color: c.primary,
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.tv_rounded,
                                size: 48,
                                color: c.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (var i = 0; i < _steps.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c.okButton,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: c.onSurfaceStrong,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _steps[i],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: c.onSurfaceStrong,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (i < _steps.length - 1)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: c.subtleOutline,
                          ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: c.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppShapes.card),
                          border: Border.all(color: c.subtleOutline),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: connected ? c.connected : c.muted,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: c.onSurfaceStrong,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Semantics(
                  button: true,
                  label: connected ? 'Continue' : 'Connect',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: ElevatedButton(
                      onPressed: connecting
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              onConnect();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
                        disabledBackgroundColor: c.surfaceContainerStrong,
                        disabledForegroundColor: c.muted,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppShapes.pill),
                        ),
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      child: connecting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.onPrimary,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!connected) ...[
                                  const Icon(Icons.link_rounded, size: 20),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  connected ? 'Continue' : 'Connect',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    child: TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onSkip();
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
                        label: 'Skip for now',
                        child: Text(
                          'Skip for now',
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
