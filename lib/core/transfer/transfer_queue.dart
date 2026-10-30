/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../adb/adb_client.dart';
import '../adb/full_control.dart';
import '../adb/tv_files.dart';

final tvFilesProvider = Provider<TvFiles>(
  (ref) => ref.read(fullControlProvider.notifier).tvFiles,
);
final transferQueueProvider =
    NotifierProvider<TransferQueue, List<TransferJob>>(TransferQueue.new);

/// A phone file ready to send, independent of where it was picked.
class PickedFile {
  const PickedFile({
    required this.name,
    required this.size,
    required this.openRead,
  });
  final String name;
  final int size;
  final Stream<List<int>> Function() openRead;
}

enum TransferDirection { toTv, toPhone, install, text }

enum TransferStatus { queued, running, done, failed, cancelled }

class TransferJob {
  TransferJob({
    required this.id,
    required this.name,
    required this.size,
    required this.direction,
    required this.status,
    required this.cancelToken,
    this.progress = 0,
    this.error,
    this.resultPath,
  });
  final String id, name;
  final int size;
  final TransferDirection direction;
  final TransferStatus status;
  final double progress;
  final String? error, resultPath;
  final CancelToken cancelToken;

  TransferJob copyWith({
    TransferStatus? status,
    double? progress,
    String? error,
    String? resultPath,
    CancelToken? cancelToken,
  }) => TransferJob(
    id: id,
    name: name,
    size: size,
    direction: direction,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    error: error,
    resultPath: resultPath ?? this.resultPath,
    cancelToken: cancelToken ?? this.cancelToken,
  );
}

typedef _TransferAction = Future<String?> Function(
  TvFiles files,
  CancelToken token,
  void Function(int, int) progress,
);

class TransferQueue extends Notifier<List<TransferJob>> {
  final _actions = <String, _TransferAction>{};
  final _tokens = <String, CancelToken>{};
  bool _working = false;
  int _nextId = 0;
  bool _alive = true;
  @override
  List<TransferJob> build() {
    ref.listen(fullControlProvider, (previous, next) {
      if (next.status == FullControlStatus.connected) {
        unawaited(_run());
      }
    });
    ref.onDispose(() {
      _alive = false;
      for (final token in _tokens.values) {
        token.cancel();
      }
      _tokens.clear();
    });
    return [];
  }

  void sendFiles(List<PickedFile> files) {
    for (final file in files) {
      if (file.name.toLowerCase().endsWith('.apk')) {
        installApk(file);
        continue;
      }
      _add(
        file.name,
        file.size,
        TransferDirection.toTv,
        (tv, token, progress) => tv.sendFile(
          file.name,
          file.openRead(),
          file.size,
          onProgress: progress,
          cancel: token,
        ),
      );
    }
  }

  void installApk(PickedFile file) => _add(
    file.name,
    file.size,
    TransferDirection.install,
    (tv, token, progress) async {
      await tv.installApk(
        file.openRead(),
        file.size,
        onProgress: progress,
        cancel: token,
      );
      return null;
    },
  );

  String download(AdbFileEntry entry, String folderPath) => _add(
    entry.name,
    entry.size,
    TransferDirection.toPhone,
    (tv, token, progress) async {
      final root = await getApplicationDocumentsDirectory();
      final dir = Directory('${root.path}/Xiaomi Remote');
      await dir.create(recursive: true);
      final dot = entry.name.lastIndexOf('.');
      final stem = dot > 0 ? entry.name.substring(0, dot) : entry.name;
      final ext = dot > 0 ? entry.name.substring(dot) : '';
      var file = File('${dir.path}/${entry.name}');
      var index = 2;
      while (await file.exists()) {
        file = File('${dir.path}/$stem (${index++})$ext');
      }
      try {
        await tv
            .download(
              '$folderPath/${entry.name}',
              onProgress: progress,
              cancel: token,
            )
            .pipe(file.openWrite());
        if (token.isCancelled) {
          throw AdbTransferCancelled();
        }
        return file.path;
      } catch (_) {
        if (await file.exists()) {
          await file.delete();
        }
        rethrow;
      }
    },
  );

  String _add(
    String name,
    int size,
    TransferDirection direction,
    _TransferAction action,
  ) {
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
    _actions[id] = action;
    final token = CancelToken();
    _tokens[id] = token;
    state = [
      ...state,
      TransferJob(
        id: id,
        name: name,
        size: size,
        direction: direction,
        status: TransferStatus.queued,
        cancelToken: token,
      ),
    ];
    unawaited(_run());
    return id;
  }

  void _update(String id, TransferJob Function(TransferJob) change) {
    if (!_alive) {
      return;
    }
    state = [
      for (final job in state)
        if (job.id == id) change(job) else job,
    ];
  }

  Future<void> _run() async {
    if (_working ||
        ref.read(fullControlProvider).status != FullControlStatus.connected) {
      return;
    }
    _working = true;
    try {
      while (_alive) {
        if (ref.read(fullControlProvider).status !=
            FullControlStatus.connected) {
          break;
        }
        final pending = state.where(
          (job) => job.status == TransferStatus.queued,
        );
        if (pending.isEmpty) {
          break;
        }
        final job = pending.first;
        _update(job.id, (j) => j.copyWith(status: TransferStatus.running));
        var last = DateTime.fromMillisecondsSinceEpoch(0);
        try {
          final path = await _actions[job.id]!(
            ref.read(tvFilesProvider),
            job.cancelToken,
            (sent, total) {
              final now = DateTime.now();
              if (now.difference(last).inMilliseconds < 100 && sent < total) {
                return;
              }
              last = now;
              _update(
                job.id,
                (j) => j.copyWith(
                  progress: total > 0 ? (sent / total).clamp(0.0, 1.0) : 0,
                ),
              );
            },
          );
          if (job.cancelToken.isCancelled) {
            throw AdbTransferCancelled();
          }
          _update(
            job.id,
            (j) => j.copyWith(
              status: TransferStatus.done,
              progress: 1,
              resultPath: path,
            ),
          );
        } catch (error) {
          _update(
            job.id,
            (j) => j.copyWith(
              status:
                  error is AdbTransferCancelled || job.cancelToken.isCancelled
                  ? TransferStatus.cancelled
                  : TransferStatus.failed,
              error: error is AdbException ? error.message : error.toString(),
            ),
          );
        }
      }
    } finally {
      _working = false;
    }
  }

  void cancel(String id) {
    for (final job in state.where((j) => j.id == id)) {
      job.cancelToken.cancel();
      if (job.status == TransferStatus.queued) {
        _update(id, (j) => j.copyWith(status: TransferStatus.cancelled));
      }
    }
  }

  void retry(String id) {
    if (!_actions.containsKey(id)) {
      return;
    }
    final token = CancelToken();
    _tokens[id] = token;
    _update(
      id,
      (j) => j.copyWith(
        status: TransferStatus.queued,
        progress: 0,
        cancelToken: token,
      ),
    );
    unawaited(_run());
  }

  void clearFinished() {
    final finished = state
        .where(
          (j) =>
              j.status == TransferStatus.done ||
              j.status == TransferStatus.failed ||
              j.status == TransferStatus.cancelled,
        )
        .map((j) => j.id)
        .toSet();
    for (final id in finished) {
      _actions.remove(id);
      _tokens.remove(id);
    }
    state = state.where((j) => !finished.contains(j.id)).toList();
  }
}
