/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:convert';

import 'adb_client.dart';

class TvFiles {
  TvFiles(this.client, {this.ensureHelper, this.helperCommand = ''});
  final AdbClient client;
  final Future<void> Function()? ensureHelper;
  final String helperCommand;
  static const sendFolder = '/sdcard/Download/Xiaomi Remote';
  static String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";

  Future<String> sendFile(
    String name,
    Stream<List<int>> data,
    int length, {
    void Function(int, int)? onProgress,
    CancelToken? cancel,
  }) async {
    if (name.isEmpty || name == '.' || name == '..' ||
        name.contains('/') || name.contains('\u0000')) {
      throw AdbException('Invalid file name');
    }
    await client.shell('mkdir -p ${_quote(sendFolder)}');
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final extension = dot > 0 ? name.substring(dot) : '';
    var path = '$sendFolder/$name';
    var index = 2;
    while (await client.stat(path) != null) {
      path = '$sendFolder/$stem (${index++})$extension';
    }
    await client.pushStream(
      data, length, path, onProgress: onProgress, cancel: cancel,
    );
    await client.shell(
      'am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d ${_quote('file://$path')}',
    );
    return path;
  }

  Future<List<AdbFileEntry>> listFolder(String path) async {
    final entries = (await client.list(path))
        .where((e) => !e.name.startsWith('.'))
        .toList();
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      final result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return result != 0 ? result : a.name.compareTo(b.name);
    });
    return entries;
  }

  Future<({int free, int total})> storage() async {
    final rows = (await client.shell('df -k /sdcard')).trim().split('\n');
    final columns = rows.last.trim().split(RegExp(r'\s+'));
    if (columns.length < 4) throw AdbException('Unable to parse storage');
    final total = int.tryParse(columns[1]);
    final free = int.tryParse(columns[3]);
    if (total == null || free == null) {
      throw AdbException('Unable to parse storage');
    }
    return (free: free * 1024, total: total * 1024);
  }

  Stream<List<int>> download(
    String path, {
    void Function(int, int)? onProgress,
    CancelToken? cancel,
  }) => client.pull(path, onProgress: onProgress, cancel: cancel);

  Future<void> delete(String path) async {
    final parts = path.split('/');
    if (!path.startsWith('/sdcard/') ||
        parts.contains('..') ||
        path.contains('\u0000') ||
        parts.skip(2).every((p) => p.isEmpty || p == '.')) {
      throw AdbException('Invalid delete path');
    }
    await client.shell('rm -rf ${_quote(path)}');
  }

  static const _mime = {
    'mp4': 'video/mp4', 'mkv': 'video/x-matroska', 'avi': 'video/x-msvideo', 'webm': 'video/webm', 'mov': 'video/quicktime',
    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'gif': 'image/gif', 'webp': 'image/webp',
    'mp3': 'audio/mpeg', 'wav': 'audio/wav', 'ogg': 'audio/ogg', 'm4a': 'audio/mp4', 'flac': 'audio/flac',
    'txt': 'text/plain', 'pdf': 'application/pdf', 'apk': 'application/vnd.android.package-archive',
  };

  Future<void> openOnTv(String path) async {
    final extension = path.split('/').last.split('.').last.toLowerCase();
    await client.shell(
      'am start -a android.intent.action.VIEW -d ${_quote('file://$path')} '
      '-t ${_quote(_mime[extension] ?? 'application/octet-stream')}',
    );
  }

  Future<void> installApk(
    Stream<List<int>> data,
    int length, {
    void Function(int, int)? onProgress,
    CancelToken? cancel,
  }) async {
    final path = '/data/local/tmp/xr_install_${DateTime.now().millisecondsSinceEpoch}.apk';
    try {
      await client.pushStream(
        data, length, path, onProgress: onProgress, cancel: cancel,
      );
      await installTvApk(path);
    } finally {
      await client.shell('rm -f ${_quote(path)}');
    }
  }

  Future<void> installTvApk(String tvPath) async {
    final result = await client.shell('pm install -r -g ${_quote(tvPath)}');
    if (!result.contains('Success')) throw AdbException(result.trim());
  }

  Future<void> sendText(String text) async {
    if (ensureHelper == null || helperCommand.isEmpty) {
      throw AdbException('Clipboard helper unavailable');
    }
    await ensureHelper!();
    final result = await client.shell(
      '$helperCommand clipboard-set ${_quote(base64Encode(utf8.encode(text)))}',
    );
    if (result.trim() != 'ok') throw AdbException(result.trim());
  }

  /// Reads the TV clipboard; empty when it holds no text.
  Future<String> readClipboard() async {
    await ensureHelper?.call();
    final output = await client.shell('$helperCommand clipboard-get');
    final line = output
        .split('\n')
        .firstWhere((l) => l.startsWith('clip:'), orElse: () => '');
    if (line.isEmpty) throw AdbException('Could not read the TV clipboard');
    return utf8.decode(base64.decode(line.substring(5).trim()));
  }

  Future<void> openText(String text) async {
    final uri = Uri.tryParse(text);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw AdbException('Invalid URL');
    }
    await client.shell('am start -a android.intent.action.VIEW -d ${_quote(text)}');
  }
}
