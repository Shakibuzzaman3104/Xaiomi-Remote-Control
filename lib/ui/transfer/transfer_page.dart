/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/adb/adb_client.dart';
import '../../core/adb/full_control.dart';
import '../../core/session/providers.dart';
import '../../core/transfer/transfer_queue.dart';
import '../fade_switcher.dart';
import '../haptics.dart';
import '../motion.dart';
import '../onboarding/unlock_page.dart';
import '../physics.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

part 'send_tab.dart';
part 'tv_files_tab.dart';
part 'transfer_job_tile.dart';
part 'file_actions_sheet.dart';
part 'transfer_widgets.dart';

class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({super.key, this.initialFilesTab = false});
  final bool initialFilesTab;
  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends ConsumerState<TransferPage> {
  late bool filesTab = widget.initialFilesTab;
  final text = TextEditingController();
  String path = '/sdcard';
  List<AdbFileEntry>? entries;
  ({int free, int total})? storage;
  Object? error;
  int generation = 0;
  final autoShare = <String>{};

  @override
  void initState() {
    super.initState();
    if (filesTab) scheduleMicrotask(_load);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final current = ++generation;
    setState(() {
      entries = null;
      error = null;
    });
    try {
      final tv = ref.read(tvFilesProvider);
      final results = await Future.wait<Object?>([
        tv.listFolder(path),
        tv.storage().then<Object?>((value) => value).catchError((_) => null),
      ]);
      if (!mounted || current != generation) return;
      final list = List<AdbFileEntry>.of(results[0] as List<AdbFileEntry>);
      list.sort(
        (a, b) => a.isDirectory != b.isDirectory
            ? (a.isDirectory ? -1 : 1)
            : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      setState(() {
        entries = list;
        storage = results[1] as ({int free, int total})?;
      });
    } catch (e) {
      if (mounted && current == generation) setState(() => error = e);
    }
  }

  void _navigate(String value) {
    setState(() => path = value);
    _load();
  }

  bool _up() {
    if (filesTab && path != '/sdcard') {
      _navigate(path.substring(0, path.lastIndexOf('/')));
      return true;
    }
    return false;
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _run(Future<void> Function() action, [String? success]) async {
    try {
      await action();
      if (success != null) _toast(success);
    } catch (e) {
      _toast(e is AdbException ? e.message : e.toString());
    }
  }

  Future<void> _share(String path) async {
    await _run(() async {
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    });
  }

  static const _shareChannel = MethodChannel('xr/share');

  /// Android keeps downloads in Downloads/Xiaomi Remote; elsewhere the share sheet saves them.
  Future<void> _saveToPhone(TransferJob job) async {
    String? uri;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        uri = await _shareChannel.invokeMethod<String>('saveToDownloads', {
          'path': job.resultPath,
          'name': job.name,
        });
      } catch (e) {
        _toast("Couldn't save ${job.name}");
        return;
      }
    }
    if (uri == null) return _share(job.resultPath!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Saved to Downloads › Xiaomi Remote'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () =>
              _shareChannel.invokeMethod('openDownload', {'uri': uri}),
        ),
      ),
    );
  }

  Future<void> _pick() async {
    try {
      final picked = await FilePicker.pickFiles();
      final files = <PickedFile>[];
      for (final file in picked) {
        final size = file.lengthSync() ?? await file.length();
        if (size == null) continue;
        files.add(
          PickedFile(
            name: file.name,
            size: size,
            openRead: file.readAsByteStream,
          ),
        );
      }
      if (files.isNotEmpty) {
        ref.read(transferQueueProvider.notifier).sendFiles(files);
      }
    } catch (e) {
      _toast(e.toString());
    }
  }

  bool get isUrl {
    final uri = Uri.tryParse(text.text.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  void _actions(AdbFileEntry entry) {
    final target = '$path/${entry.name}';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: sheetAnimation(context),
      builder: (sheet) => _FileActionsSheet(
        entry: entry,
        onSave: () {
          Navigator.pop(sheet);
          final id = ref
              .read(transferQueueProvider.notifier)
              .download(entry, path);
          autoShare.add(id);
        },
        onOpen: () {
          Navigator.pop(sheet);
          _run(() => ref.read(tvFilesProvider).openOnTv(target));
        },
        onInstall: () {
          Navigator.pop(sheet);
          _run(
            () => ref.read(tvFilesProvider).installTvApk(target),
            'Installed',
          );
        },
        onDelete: () {
          Navigator.pop(sheet);
          _delete(entry, target);
        },
      ),
    );
  }

  Future<void> _delete(AdbFileEntry entry, String target) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete ${entry.name}?'),
        content: const Text('This will remove the file from your TV.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await _run(() async {
        await ref.read(tvFilesProvider).delete(target);
        await _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected =
        ref.watch(fullControlProvider).status == FullControlStatus.connected;
    final jobs = ref.watch(transferQueueProvider);
    ref.listen(transferQueueProvider, (previous, next) {
      for (final job in next) {
        if (autoShare.contains(job.id) &&
            job.status == TransferStatus.done &&
            job.resultPath != null) {
          autoShare.remove(job.id);
          unawaited(_saveToPhone(job));
        } else if (job.status == TransferStatus.failed ||
            job.status == TransferStatus.cancelled) {
          autoShare.remove(job.id);
        }
      }
    });
    ref.listen(fullControlProvider, (previous, next) {
      if (previous?.status != FullControlStatus.connected &&
          next.status == FullControlStatus.connected &&
          filesTab) {
        _load();
      }
    });
    final theme = Theme.of(context);
    const minimum = Size(48, 48);
    return Theme(
      data: theme.copyWith(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: minimum),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: minimum),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(minimumSize: minimum),
        ),
      ),
      child: PopScope(
        canPop: !(filesTab && path != '/sdcard'),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _up();
        },
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _TransferHeader(
                  name: ref.watch(activeTvProvider)?.displayName ?? 'TV',
                  onBack: () {
                    if (!_up()) Navigator.pop(context);
                  },
                ),
                if (!connected)
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: _DisconnectedPrompt(),
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _TransferTabs(
                      filesTab: filesTab,
                      onSelect: (value) {
                        AppHaptics.selection();
                        setState(() => filesTab = value);
                        if (filesTab && entries == null && error == null) {
                          _load();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: FadeSwitcher(
                      scale: 1,
                      expand: true,
                      child: filesTab
                          ? _TvFilesTab(
                              key: const ValueKey('tv-files-tab'),
                              path: path,
                              entries: entries,
                              storage: storage,
                              error: error,
                              onLoad: _load,
                              onNavigate: _navigate,
                              onActions: _actions,
                            )
                          : _SendTab(
                              key: const ValueKey('send-tab'),
                              text: text,
                              isUrl: isUrl,
                              jobs: jobs,
                              onPick: _pick,
                              onChanged: () => setState(() {}),
                              onCopy: () => _run(
                                () => ref
                                    .read(tvFilesProvider)
                                    .sendText(text.text),
                                'Copied to TV clipboard',
                              ),
                              onType: () {
                                final session = ref.read(tvSessionProvider);
                                if (session == null || !session.isConnected) {
                                  _toast('The TV is not connected');
                                  return;
                                }
                                session.sendText(text.text);
                              },
                              onPaste: () async {
                                try {
                                  final value = await ref
                                      .read(tvFilesProvider)
                                      .readClipboard();
                                  if (mounted) {
                                    setState(() => text.text = value);
                                  }
                                } catch (e) {
                                  _toast(e.toString());
                                }
                              },
                              onOpenText: () => _run(
                                () => ref
                                    .read(tvFilesProvider)
                                    .openText(text.text.trim()),
                              ),
                              onClear: () => ref
                                  .read(transferQueueProvider.notifier)
                                  .clearFinished(),
                              onCancel: (id) => ref
                                  .read(transferQueueProvider.notifier)
                                  .cancel(id),
                              onRetry: (id) => ref
                                  .read(transferQueueProvider.notifier)
                                  .retry(id),
                              onOpenJob: (job) =>
                                  job.direction == TransferDirection.toPhone
                                  ? _share(job.resultPath!)
                                  : _run(
                                      () => ref
                                          .read(tvFilesProvider)
                                          .openOnTv(job.resultPath!),
                                    ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransferHeader extends StatelessWidget {
  const _TransferHeader({required this.name, required this.onBack});
  final String name;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 20, 12),
    child: Row(
      children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer',
                style: context.appTextTheme.headlineMedium?.copyWith(
                  color: context.colors.onSurfaceStrong,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                name,
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
}

class _TransferTabs extends StatelessWidget {
  const _TransferTabs({required this.filesTab, required this.onSelect});
  final bool filesTab;
  final ValueChanged<bool> onSelect;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: List.generate(2, (i) {
          final selected = filesTab == (i == 1);
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(i == 1),
              child: Container(
                margin: const EdgeInsets.all(3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? c.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  i == 0 ? 'Send to TV' : 'TV files',
                  style: context.appTextTheme.titleSmall?.copyWith(
                    color: selected ? c.onPrimary : c.onSurfaceStrong,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DisconnectedPrompt extends StatelessWidget {
  const _DisconnectedPrompt();
  @override
  Widget build(BuildContext context) => _TransferCard(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Transfer needs Full control',
            style: context.appTextTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Text('Connect Full control to transfer files and text.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const UnlockPage()),
            ),
            child: const Text('Set up Full control'),
          ),
        ],
      ),
    ),
  );
}
