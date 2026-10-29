/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'step_dots.dart';

class DiscoverItem {
  const DiscoverItem({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({
    super.key,
    required this.devices,
    required this.searching,
    required this.onSelect,
    required this.onEnterIp,
  });

  final List<DiscoverItem> devices;
  final bool searching;
  final ValueChanged<DiscoverItem> onSelect;
  final VoidCallback onEnterIp;

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
              const Center(child: StepDots(current: 1)),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Find your TV',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: c.onSurfaceStrong,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Make sure your phone and TV are on the same Wi-Fi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: c.muted),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Container(
                          width: 140,
                          height: 140,
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
                                size: 40,
                                color: c.primary,
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.tv_rounded,
                                size: 54,
                                color: c.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Available devices',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.onSurfaceStrong,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (devices.isNotEmpty) ...[
                        for (final item in devices) ...[
                          _DeviceTile(
                            item: item,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onSelect(item);
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                      if (searching) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Searching…',
                                style: TextStyle(fontSize: 14, color: c.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    child: TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onEnterIp();
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
                        label: 'Enter IP address manually',
                        child: Text(
                          'Enter IP address manually',
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

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.item, required this.onTap});

  final DiscoverItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      button: true,
      label: '${item.title}, ${item.subtitle}',
      child: Material(
        color: c.appTile,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.card),
          side: BorderSide(color: c.subtleOutline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppShapes.card),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.tv_rounded, size: 28, color: c.onSurfaceStrong),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.onSurfaceStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: c.muted),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: c.onSurfaceVariant,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
