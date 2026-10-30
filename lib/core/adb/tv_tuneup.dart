/**
 * @author Shakib
 * @since 30/10/26
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adb_client.dart';
import 'full_control.dart';

enum BloatGroup { tracking, xiaomi, google, streaming }

class BloatApp {
  const BloatApp(
    this.package,
    this.label,
    this.group, {
    this.recommended = true,
  });
  final String package, label;
  final BloatGroup group;
  final bool recommended;
}

/// The only packages Tune up may remove; everything the TV needs stays off this list.
const bloatCatalog = [
  BloatApp(
    'tv.alphonso.alphonso_eula',
    'Alphonso ad tracking',
    BloatGroup.tracking,
  ),
  BloatApp('com.miui.tv.analytics', 'Xiaomi analytics', BloatGroup.tracking),
  BloatApp('com.mitv.tvhome.atv', 'Mi channels', BloatGroup.xiaomi),
  BloatApp(
    'com.mitv.tvhome.michannel',
    'Mi channel content',
    BloatGroup.xiaomi,
  ),
  BloatApp('com.xm.webcontent', 'Xiaomi web content', BloatGroup.xiaomi),
  BloatApp(
    'com.xiaomi.android.tvsetup.partnercustomizer',
    'Partner promotions',
    BloatGroup.xiaomi,
  ),
  BloatApp(
    'com.mitv.videoplayer',
    'Mi video player',
    BloatGroup.xiaomi,
    recommended: false,
  ),
  BloatApp(
    'com.mitv.milinkservice',
    'Mi casting',
    BloatGroup.xiaomi,
    recommended: false,
  ),
  BloatApp(
    'com.xiaomi.mitv.updateservice',
    'Xiaomi system updates',
    BloatGroup.xiaomi,
    recommended: false,
  ),
  BloatApp(
    'com.mitv.download.service',
    'Xiaomi downloader',
    BloatGroup.xiaomi,
    recommended: false,
  ),
  BloatApp(
    'com.google.android.videos',
    'Google Play Movies',
    BloatGroup.google,
  ),
  BloatApp(
    'com.google.android.play.games',
    'Google Play Games',
    BloatGroup.google,
  ),
  BloatApp('com.google.android.feedback', 'Feedback sender', BloatGroup.google),
  BloatApp(
    'com.google.android.tv.bugreportsender',
    'Bug report sender',
    BloatGroup.google,
  ),
  BloatApp(
    'com.google.android.tvrecommendations',
    'Legacy recommendations',
    BloatGroup.google,
  ),
  BloatApp('com.android.printspooler', 'Printing', BloatGroup.google),
  BloatApp('com.android.dreams.basic', 'Basic screensaver', BloatGroup.google),
  BloatApp('com.android.camera2', 'Camera', BloatGroup.google),
  BloatApp(
    'com.google.android.marvin.talkback',
    'TalkBack',
    BloatGroup.google,
    recommended: false,
  ),
  BloatApp(
    'com.netflix.ninja',
    'Netflix',
    BloatGroup.streaming,
    recommended: false,
  ),
  BloatApp(
    'com.amazon.amazonvideo.livingroom',
    'Prime Video',
    BloatGroup.streaming,
    recommended: false,
  ),
  BloatApp(
    'com.google.android.youtube.tvmusic',
    'YouTube Music',
    BloatGroup.streaming,
    recommended: false,
  ),
];

const _autoInstallerPrefix = 'android.autoinstalls.config.';

/// Catalog entry for [package], including Xiaomi's per-model auto-installer.
BloatApp? bloatAppFor(String package) {
  for (final app in bloatCatalog) {
    if (app.package == package) return app;
  }
  if (package.startsWith(_autoInstallerPrefix)) {
    return BloatApp(package, 'Xiaomi app auto-installer', BloatGroup.xiaomi);
  }
  return null;
}

class TvHealth {
  const TvHealth({
    required this.memoryFree,
    required this.memoryTotal,
    required this.storageFree,
    required this.storageTotal,
  });
  final int memoryFree, memoryTotal, storageFree, storageTotal;
}

class TvTuneUpReport {
  const TvTuneUpReport({
    required this.health,
    required this.animationScale,
    required this.removable,
    required this.removed,
  });
  final TvHealth health;
  final double animationScale;
  final List<BloatApp> removable;

  /// Packages removed for the user, catalog or not, so any can be restored.
  final List<String> removed;
}

class TvTuneUp {
  TvTuneUp(this.client);
  final AdbClient client;
  static const _animationKeys = [
    'window_animation_scale',
    'transition_animation_scale',
    'animator_duration_scale',
  ];

  static ({int free, int total}) parseMemInfo(String output) {
    int read(String key) {
      final match = RegExp(
        '^$key:\\s+(\\d+) kB',
        multiLine: true,
      ).firstMatch(output);
      return (int.tryParse(match?.group(1) ?? '') ?? 0) * 1024;
    }

    return (free: read('MemAvailable'), total: read('MemTotal'));
  }

  static ({int free, int total}) parseDf(String output) {
    final columns = output.trim().split('\n').last.trim().split(RegExp(r'\s+'));
    if (columns.length < 4) throw AdbException('Could not read TV storage');
    final total = int.tryParse(columns[1]), free = int.tryParse(columns[3]);
    if (total == null || free == null) {
      throw AdbException('Could not read TV storage');
    }
    return (free: free * 1024, total: total * 1024);
  }

  static Set<String> parsePackages(String output) => {
    for (final line in output.split('\n'))
      if (line.trim().startsWith('package:')) line.trim().substring(8),
  };

  static double parseScale(String output) =>
      double.tryParse(output.trim()) ?? 1.0;

  Future<TvHealth> health() async {
    final memory = parseMemInfo(await client.shell('cat /proc/meminfo'));
    final storage = parseDf(await client.shell('df -k /data'));
    return TvHealth(
      memoryFree: memory.free,
      memoryTotal: memory.total,
      storageFree: storage.free,
      storageTotal: storage.total,
    );
  }

  Future<TvTuneUpReport> scan() async {
    final health = await this.health();
    final scale = parseScale(
      await client.shell('settings get global ${_animationKeys.first}'),
    );
    final installed = parsePackages(await client.shell('pm list packages'));
    final everything = parsePackages(await client.shell('pm list packages -u'));
    final removable = [for (final package in installed) ?bloatAppFor(package)]
      ..sort(
        (a, b) => a.group.index != b.group.index
            ? a.group.index - b.group.index
            : a.label.compareTo(b.label),
      );
    final removed = everything.difference(installed).toList()..sort();
    return TvTuneUpReport(
      health: health,
      animationScale: scale,
      removable: removable,
      removed: removed,
    );
  }

  Future<void> setAnimationScale(double scale) async {
    final value = scale == scale.roundToDouble()
        ? scale.toInt().toString()
        : '$scale';
    for (final key in _animationKeys) {
      await client.shell('settings put global $key $value');
    }
  }

  /// Removes [package] for the TV user only; it stays restorable.
  Future<void> remove(String package) async {
    if (bloatAppFor(package) == null) {
      throw AdbException('$package is not on the safe list');
    }
    final output = await client.shell('pm uninstall -k --user 0 $package');
    if (!output.contains('Success')) {
      throw AdbException("Couldn't remove $package");
    }
  }

  Future<void> restore(String package) async {
    if (!RegExp(r'^[A-Za-z0-9_.]+$').hasMatch(package)) {
      throw AdbException('Invalid package');
    }
    final output = await client.shell('pm install-existing $package');
    if (!output.contains('installed')) {
      throw AdbException("Couldn't restore $package");
    }
  }

  /// Stops cached background apps; returns the bytes of memory freed.
  Future<int> freeMemory() async {
    final before = parseMemInfo(await client.shell('cat /proc/meminfo')).free;
    await client.shell('am kill-all');
    final after = parseMemInfo(await client.shell('cat /proc/meminfo')).free;
    return after - before;
  }

  Future<void> restart() => client
      .shell('reboot', timeout: const Duration(seconds: 5))
      .then((_) {}, onError: (_) {});
}

final tvTuneUpProvider = Provider<TvTuneUp?>((ref) {
  final connected =
      ref.watch(fullControlProvider.select((s) => s.status)) ==
      FullControlStatus.connected;
  return connected
      ? TvTuneUp(ref.read(fullControlProvider.notifier).connectedClient)
      : null;
});
