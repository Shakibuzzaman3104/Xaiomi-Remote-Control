/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adb/adb_client.dart';
import '../../core/adb/tv_tuneup.dart';
import '../../core/session/providers.dart';
import '../haptics.dart';
import '../onboarding/unlock_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class TuneUpPage extends ConsumerStatefulWidget {
  const TuneUpPage({super.key});
  @override
  ConsumerState<TuneUpPage> createState() => _TuneUpPageState();
}

class _TuneUpPageState extends ConsumerState<TuneUpPage> {
  TvTuneUpReport? report;
  Object? error;
  final selected = <String>{};
  final restoring = <String>{};
  double scale = 1;
  bool loading = true, freeing = false, changingScale = false;
  int? removing;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_scan);
  }

  Future<void> _scan() async {
    if (!mounted) return;
    final tv = ref.read(tvTuneUpProvider);
    final current = ++generation;
    if (tv == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await tv.scan();
      if (!mounted ||
          current != generation ||
          ref.read(tvTuneUpProvider) != tv) {
        return;
      }
      setState(() {
        final previous = report;
        report = result;
        scale = [0.0, 0.5, 1.0].reduce(
          (a, b) =>
              (a - result.animationScale).abs() <=
                  (b - result.animationScale).abs()
              ? a
              : b,
        );
        if (previous == null) {
          selected.addAll(
            result.removable
                .where((app) => app.recommended)
                .map((app) => app.package),
          );
        } else {
          selected.retainAll(
            result.removable.map((app) => app.package).toSet(),
          );
        }
        loading = false;
      });
    } catch (e) {
      if (mounted && current == generation) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  String _message(Object e) => e is AdbException ? e.message : e.toString();
  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _freeMemory() async {
    AppHaptics.selection();
    final tv = ref.read(tvTuneUpProvider);
    if (tv == null) return;
    setState(() => freeing = true);
    try {
      final freed = await tv.freeMemory();
      _toast(freed > 0 ? 'Freed ${_size(freed)}' : 'Memory is already free');
      await _scan();
    } catch (e) {
      _toast(_message(e));
    } finally {
      if (mounted) setState(() => freeing = false);
    }
  }

  Future<void> _setScale(double value) async {
    AppHaptics.selection();
    final tv = ref.read(tvTuneUpProvider);
    if (tv == null) return;
    final previous = scale;
    setState(() {
      scale = value;
      changingScale = true;
    });
    try {
      await tv.setAnimationScale(value);
    } catch (e) {
      if (mounted) setState(() => scale = previous);
      _toast(_message(e));
    } finally {
      if (mounted) setState(() => changingScale = false);
    }
  }

  Future<void> _remove() async {
    AppHaptics.selection();
    final tv = ref.read(tvTuneUpProvider);
    if (tv == null) return;
    final packages = selected.toList();
    if (!await _confirm(
      'Remove ${_appCount(packages.length)} from your TV?',
      'They are removed for this TV user and can be restored below.',
      'Remove',
    )) {
      return;
    }
    if (!mounted || ref.read(tvTuneUpProvider) != tv) return;
    final failures = <String>[];
    for (var i = 0; i < packages.length; i++) {
      if (!mounted) return;
      setState(() => removing = i + 1);
      try {
        await tv.remove(packages[i]);
      } catch (e) {
        failures.add('${packages[i]}: ${_message(e)}');
      }
    }
    if (failures.isNotEmpty) _toast('Could not remove: ${failures.join(', ')}');
    if (mounted) setState(() => removing = null);
    await _scan();
  }

  Future<void> _restore(String package) async {
    AppHaptics.selection();
    final tv = ref.read(tvTuneUpProvider);
    if (tv == null) return;
    setState(() => restoring.add(package));
    try {
      await tv.restore(package);
      await _scan();
    } catch (e) {
      _toast(_message(e));
    } finally {
      if (mounted) setState(() => restoring.remove(package));
    }
  }

  Future<void> _restart() async {
    AppHaptics.selection();
    final tv = ref.read(tvTuneUpProvider);
    if (tv == null) return;
    if (!await _confirm(
      'Restart your TV?',
      'The remote reconnects when the TV is back.',
      'Restart',
    )) {
      return;
    }
    if (!mounted || ref.read(tvTuneUpProvider) != tv) return;
    try {
      await tv.restart();
      _toast('Restarting TV…');
    } catch (e) {
      _toast(_message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tv = ref.watch(tvTuneUpProvider);
    ref.listen(tvTuneUpProvider, (previous, next) {
      if (previous != next) {
        generation++;
        report = null;
        selected.clear();
        if (next != null) _scan();
      }
    });
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            if (tv == null)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _DisconnectedPrompt(),
                  ),
                ),
              )
            else
              Expanded(child: _content()),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 20, 12),
    child: Row(
      children: [
        IconButton(
          onPressed: () {
            AppHaptics.selection();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tune up TV',
                style: context.appTextTheme.headlineMedium?.copyWith(
                  color: context.colors.onSurfaceStrong,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ref.watch(activeTvProvider)?.displayName ?? 'TV',
                style: context.appTextTheme.bodyMedium?.copyWith(
                  color: context.colors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _content() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    children: [
      if (loading && report == null)
        for (final height in [160.0, 120.0, 220.0]) ...[
          _Card(child: SizedBox(height: height)),
          const SizedBox(height: 12),
        ]
      else if (error != null)
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(_message(error!)),
                TextButton(
                  onPressed: () {
                    AppHaptics.selection();
                    _scan();
                  },
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        )
      else if (report != null) ...[
        _status(report!.health),
        const SizedBox(height: 12),
        _speed(),
        const SizedBox(height: 12),
        _apps(report!),
        const SizedBox(height: 12),
        if (report!.removed.isNotEmpty) ...[
          _removed(report!.removed),
          const SizedBox(height: 12),
        ],
        OutlinedButton(onPressed: _restart, child: const Text('Restart TV')),
      ],
    ],
  );

  Widget _section(String title, Widget child) => _Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.appTextTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );

  Widget _status(TvHealth health) => _section(
    'Status',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _healthRow('Memory', health.memoryFree, health.memoryTotal),
        const SizedBox(height: 16),
        _healthRow('Storage', health.storageFree, health.storageTotal),
        TextButton(
          onPressed: freeing ? null : _freeMemory,
          child: const Text('Free up memory'),
        ),
      ],
    ),
  );

  Widget _healthRow(String label, int free, int total) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: context.appTextTheme.titleSmall),
      Text('${_size(free)} free of ${_size(total)}'),
      const SizedBox(height: 10),
      LinearProgressIndicator(
        value: total > 0 ? (1 - free / total).clamp(0.0, 1.0) : 0,
        backgroundColor: context.colors.progressTrack,
      ),
    ],
  );

  Widget _speed() => _section(
    'Speed',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Animations', style: context.appTextTheme.titleSmall),
        const SizedBox(height: 12),
        SegmentedButton<double>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Off')),
            ButtonSegment(value: 0.5, label: Text('Fast')),
            ButtonSegment(value: 1, label: Text('Normal')),
          ],
          selected: {scale},
          onSelectionChanged: changingScale
              ? null
              : (value) => _setScale(value.first),
        ),
      ],
    ),
  );

  Widget _apps(TvTuneUpReport data) => _section(
    'Remove apps',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Removed apps can be restored any time.'),
        if (data.removable.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Nothing left to remove'),
          ),
        for (final group in BloatGroup.values)
          if (data.removable.any((app) => app.group == group)) ...[
            const SizedBox(height: 16),
            Text(_groupName(group), style: context.appTextTheme.titleSmall),
            for (final app in data.removable.where((app) => app.group == group))
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(app.label),
                subtitle: _package(app.package),
                value: selected.contains(app.package),
                onChanged: removing != null
                    ? null
                    : (value) {
                        AppHaptics.selection();
                        setState(() {
                          if (value == true) {
                            selected.add(app.package);
                          } else {
                            selected.remove(app.package);
                          }
                        });
                      },
              ),
          ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: selected.isEmpty || removing != null ? null : _remove,
            child: Text(
              removing == null
                  ? 'Remove ${_appCount(selected.length)}'
                  : 'Removing $removing of ${selected.length}…',
            ),
          ),
        ),
      ],
    ),
  );

  Widget _removed(List<String> packages) => _section(
    'Removed apps',
    Column(
      children: [
        for (final package in packages)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(bloatAppFor(package)?.label ?? package),
            subtitle: _package(package),
            trailing: restoring.contains(package)
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: () => _restore(package),
                    child: const Text('Restore'),
                  ),
          ),
      ],
    ),
  );

  Widget _package(String package) => Text(
    package,
    style: context.appTextTheme.bodySmall?.copyWith(
      color: context.colors.muted,
    ),
  );
}

String _groupName(BloatGroup group) => switch (group) {
  BloatGroup.tracking => 'Ads & tracking',
  BloatGroup.xiaomi => 'Xiaomi extras',
  BloatGroup.google => 'Google extras',
  BloatGroup.streaming => 'Streaming apps',
};

String _appCount(int count) => count == 1 ? '1 app' : '$count apps';

String _size(int bytes) {
  if (bytes >= 1073741824) {
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surfaceContainer,
    borderRadius: BorderRadius.circular(AppShapes.card),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _DisconnectedPrompt extends StatelessWidget {
  const _DisconnectedPrompt();
  @override
  Widget build(BuildContext context) => _Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tune up needs Full control',
            style: context.appTextTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Text('Connect Full control to tune up your TV.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              AppHaptics.selection();
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const UnlockPage()),
              );
            },
            child: const Text('Set up Full control'),
          ),
        ],
      ),
    ),
  );
}
