/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../haptics.dart';

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
    this.deviceName,
    this.onBack,
  });

  final String statusText;
  final bool connecting;
  final bool connected;
  final VoidCallback onConnect;
  final VoidCallback onSkip;
  final String? deviceName;

  /// Set when opened outside onboarding; shows a back arrow instead of the step dots.
  final VoidCallback? onBack;

  static const _steps = [
    'On the TV open Settings › Device Preferences › About',
    'Click Build 7 times to become a developer',
    'Open Developer options and turn on Network debugging',
    'Tap Connect below, then choose Always allow on the TV',
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (onBack != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: onBack,
                            icon: Icon(
                              Icons.arrow_back,
                              color: c.onSurfaceStrong,
                            ),
                            tooltip: 'Back',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else if (deviceName != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.tv_outlined,
                              size: 28,
                              color: c.onSurfaceStrong,
                            ),
                            const SizedBox(width: 22),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          deviceName!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: context
                                              .appTextTheme
                                              .titleSmall!
                                              .copyWith(
                                                color: c.onSurfaceStrong,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 20,
                                        color: c.onSurfaceStrong,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.wifi,
                                        size: 16,
                                        color: c.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Connected',
                                        style: context.appTextTheme.labelMedium!
                                            .copyWith(color: c.muted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.more_vert, color: c.onSurfaceStrong),
                          ],
                        ),
                        const SizedBox(height: 25),
                      ] else
                        const SizedBox(height: 20),
                      if (onBack == null) ...[
                        Center(
                          child: Text(
                            '3 of 3',
                            style: context.appTextTheme.bodySmall!.copyWith(
                              color: c.muted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: StepDots(current: 3, numbered: false),
                        ),
                        const SizedBox(height: 25),
                      ],
                      Text(
                        'Unlock full control',
                        textAlign: TextAlign.center,
                        style: context.appTextTheme.headlineMedium!.copyWith(
                          color: c.onSurfaceStrong,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Optional. Shows every app on your TV and lets you force stop, clear cache or uninstall them.',
                        textAlign: TextAlign.center,
                        style: context.appTextTheme.bodyMedium!.copyWith(
                          color: c.muted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Image.asset(
                          Theme.of(context).brightness == Brightness.dark
                              ? 'assets/illustrations/unlock_dark.png'
                              : 'assets/illustrations/unlock.png',
                          width: 277,
                          height: 185,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const SizedBox(width: 277, height: 185),
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < _steps.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c.okButton,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${i + 1}',
                                  style: context.appTextTheme.bodySmall!
                                      .copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: c.onSurfaceStrong,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _steps[i],
                                    style: context.appTextTheme.bodyMedium!
                                        .copyWith(
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
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
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
                          style: context.appTextTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w500,
                            color: c.onSurfaceStrong,
                          ),
                        ),
                      ),
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
                              AppHaptics.selection();
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
                                  style: context.appTextTheme.bodyLarge!
                                      .copyWith(fontWeight: FontWeight.bold),
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
                        AppHaptics.selection();
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
                        label: onBack == null ? 'Skip for now' : 'Not now',
                        child: Text(
                          onBack == null ? 'Skip for now' : 'Not now',
                          style: context.appTextTheme.displaySmall!.copyWith(
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
