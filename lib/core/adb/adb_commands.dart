/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:typed_data';

import 'adb_client.dart';

enum AdbPlaybackState { playing, paused, other }

class AdbNowPlaying {
  const AdbNowPlaying({
    required this.package,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.positionMs,
    this.durationMs,
  });
  final String package, title, subtitle;
  final AdbPlaybackState state;
  final int positionMs;
  final int? durationMs;
}

class AdbDeviceInfo {
  const AdbDeviceInfo({
    required this.model,
    required this.androidVersion,
    required this.sdk,
    required this.storageFreeBytes,
    required this.storageTotalBytes,
    required this.memoryTotalBytes,
    required this.memoryAvailableBytes,
    required this.uptime,
  });
  final String model, androidVersion;
  final int sdk,
      storageFreeBytes,
      storageTotalBytes,
      memoryTotalBytes,
      memoryAvailableBytes;
  final Duration uptime;
}

class AdbCommands {
  AdbCommands(this.client);
  final AdbClient client;
  static String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";

  Future<void> launchApp(String package) async {
    final p = _quote(package);
    final result = await client.shell(
      'monkey -p $p -c android.intent.category.LEANBACK_LAUNCHER 1',
    );
    if (result.contains('No activities found') ||
        result.contains('Events injected: 0') ||
        result.contains('Error')) {
      await client.shell('monkey -p $p -c android.intent.category.LAUNCHER 1');
    }
  }

  Future<List<String>> listLauncherApps() async {
    final output = await client.shell(
      'cmd package query-activities -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER',
    );
    return RegExp(r'packageName=([^\s,}]+)')
        .allMatches(output)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
  }

  Future<void> forceStop(String package) async {
    await client.shell('am force-stop ${_quote(package)}');
  }

  Future<void> clearCache(String package) async {
    final result = await client.shell(
      'pm clear --cache-only ${_quote(package)}',
    );
    if (!result.contains('Success')) {
      throw AdbException(
        'Cache clearing unsupported or failed: ${result.trim()}',
      );
    }
  }

  Future<void> uninstall(String package) async {
    final result = await client.shell('pm uninstall ${_quote(package)}');
    if (!result.contains('Success')) throw AdbException(result.trim());
  }

  Future<void> openAppInfo(String package) async {
    await client.shell(
      'am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d ${_quote('package:$package')}',
    );
  }

  Future<void> globalSearch(String query) async {
    await client.shell(
      'am start -a android.search.action.GLOBAL_SEARCH --es query ${_quote(query)}',
    );
  }

  Future<void> openUrl(String url) async {
    await client.shell(
      'am start -a android.intent.action.VIEW -d ${_quote(url)}',
    );
  }

  static (int, int) parseMusicVolume(String output) {
    final section = RegExp(
      r'- STREAM_MUSIC:\s*([\s\S]*?)(?=\n\s*- STREAM_|$(?![\s\S]))',
    ).firstMatch(output)?.group(1);
    if (section == null) throw AdbException('STREAM_MUSIC not found');
    final max = RegExp(
      r'^\s*Max:\s*(\d+)',
      multiLine: true,
    ).firstMatch(section);
    final current = RegExp(
      r'^\s*Current:\s*(.*)',
      multiLine: true,
    ).firstMatch(section)?.group(1);
    final value = current == null
        ? null
        : RegExp(r'\((hdmi|default)\):\s*(\d+)').allMatches(current).toList();
    if (max == null || value == null || value.isEmpty) {
      throw AdbException('Music volume unavailable');
    }
    final selected =
        value.where((m) => m.group(1) == 'hdmi').firstOrNull ?? value.first;
    return (int.parse(selected.group(2)!), int.parse(max.group(1)!));
  }

  Future<(int, int)> musicVolume() async =>
      parseMusicVolume(await client.shell('dumpsys audio'));

  static AdbNowPlaying? parseNowPlaying(String output) {
    final packages = RegExp(
      r'^\s*package=([^\s]+)',
      multiLine: true,
    ).allMatches(output).toList();
    for (var i = 0; i < packages.length; i++) {
      final section = output.substring(
        packages[i].end,
        i + 1 < packages.length ? packages[i + 1].start : output.length,
      );
      final state = RegExp(
        r'PlaybackState\s*\{\s*state=(\d+),\s*position=(-?\d+)',
      ).firstMatch(section);
      if (state == null || (state.group(1) != '3' && state.group(1) != '2')) {
        continue;
      }
      final description =
          RegExp(r'description=([^\r\n]*)')
              .firstMatch(section)
              ?.group(1)
              ?.split(', ') ??
          [];
      final duration = RegExp(
        r'(?:android\.media\.metadata\.DURATION|duration)\s*[=:]\s*(\d+)',
        caseSensitive: false,
      ).firstMatch(section);
      return AdbNowPlaying(
        package: packages[i].group(1)!,
        title: description.isNotEmpty && description[0] != 'null'
            ? description[0]
            : '',
        subtitle: description.length > 1 && description[1] != 'null'
            ? description[1]
            : '',
        state: state.group(1) == '3'
            ? AdbPlaybackState.playing
            : AdbPlaybackState.paused,
        positionMs: int.parse(state.group(2)!),
        durationMs: duration == null ? null : int.parse(duration.group(1)!),
      );
    }
    return null;
  }

  Future<AdbNowPlaying?> nowPlaying() async =>
      parseNowPlaying(await client.shell('dumpsys media_session'));
  Future<Uint8List> screencapPng() => client.exec('screencap -p');
  Future<AdbDeviceInfo> deviceInfo() async {
    final results = await Future.wait([
      client.shell('getprop ro.product.model'),
      client.shell('getprop ro.build.version.release'),
      client.shell('getprop ro.build.version.sdk'),
      client.shell('df -k /data'),
      client.shell('cat /proc/meminfo'),
      client.shell('cat /proc/uptime'),
    ]);
    final rows = results[3].trim().split('\n');
    final columns = rows.last.trim().split(RegExp(r'\s+'));
    final memory = <String, int>{};
    for (final m in RegExp(
      r'^(MemTotal|MemAvailable):\s*(\d+)',
      multiLine: true,
    ).allMatches(results[4])) {
      memory[m.group(1)!] = int.parse(m.group(2)!) * 1024;
    }
    if (columns.length < 4 ||
        !memory.containsKey('MemTotal') ||
        !memory.containsKey('MemAvailable')) {
      throw AdbException('Unable to parse device information');
    }
    try {
      return AdbDeviceInfo(
        model: results[0].trim(),
        androidVersion: results[1].trim(),
        sdk: int.parse(results[2].trim()),
        storageTotalBytes: int.parse(columns[1]) * 1024,
        storageFreeBytes: int.parse(columns[3]) * 1024,
        memoryTotalBytes: memory['MemTotal']!,
        memoryAvailableBytes: memory['MemAvailable']!,
        uptime: Duration(
          milliseconds:
              (double.parse(results[5].trim().split(RegExp(r'\s+')).first) *
                      1000)
                  .round(),
        ),
      );
    } on FormatException {
      throw AdbException('Unable to parse device information');
    }
  }

  Future<void> sleep() async {
    await client.shell('input keyevent KEYCODE_SLEEP');
  }

  Future<void> wakeUp() async {
    await client.shell('input keyevent KEYCODE_WAKEUP');
  }

  Future<void> tap(int x, int y) async {
    await client.shell('input tap $x $y');
  }

  Future<void> swipe(int x1, int y1, int x2, int y2, int ms) async {
    await client.shell('input swipe $x1 $y1 $x2 $y2 $ms');
  }

  Future<void> inputText(String asciiText) async {
    if (asciiText.codeUnits.any((c) => c < 32 || c > 126)) {
      throw AdbException('Input text must be printable ASCII');
    }
    final parts = asciiText.split('%');
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) await client.shell("input text '%'");
      if (parts[i].isNotEmpty) {
        await client.shell(
          'input text ${_quote(parts[i].replaceAll(' ', '%s'))}',
        );
      }
    }
  }
}
