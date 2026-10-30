/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/adb/adb_client.dart';
import 'package:xiaomi_remote/core/adb/adb_key.dart';
import 'package:xiaomi_remote/core/adb/tv_tuneup.dart';

import 'transfer_test.dart' show FakeDaemon;

const _meminfo =
    'MemTotal:        2034840 kB\nMemFree:          190760 kB\nMemAvailable:     830468 kB\n';
const _df =
    'Filesystem 1K-blocks Used Available Use% Mounted on\n/dev/block/data 5292456 3166860 2076444 61% /data\n';

void main() {
  test('parsers read memory, storage, packages and scale', () {
    expect(TvTuneUp.parseMemInfo(_meminfo), (
      free: 830468 * 1024,
      total: 2034840 * 1024,
    ));
    expect(TvTuneUp.parseDf(_df), (
      free: 2076444 * 1024,
      total: 5292456 * 1024,
    ));
    expect(TvTuneUp.parsePackages('package:a.b\r\npackage:c.d\nnoise'), {
      'a.b',
      'c.d',
    });
    expect(TvTuneUp.parseScale('null'), 1.0);
    expect(TvTuneUp.parseScale('0.5\n'), 0.5);
  });

  test('catalog covers model auto-installers and nothing essential', () {
    expect(
      bloatAppFor('android.autoinstalls.config.xioami.mibox4')?.group,
      BloatGroup.xiaomi,
    );
    for (final essential in [
      'com.google.android.tv.remote.service',
      'com.google.android.gms',
      'com.google.android.tvlauncher',
      'com.android.vending',
      'com.google.android.katniss',
      'com.google.android.youtube.tv',
    ]) {
      expect(bloatAppFor(essential), isNull, reason: essential);
    }
  });

  group('with a TV', () {
    late FakeDaemon daemon;
    late AdbClient client;
    setUp(() async {
      daemon = FakeDaemon(
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      )..start();
      client = AdbClient(
        host: '127.0.0.1',
        port: daemon.server.port,
        key: AdbKey.generate(),
      );
      await client.connect();
    });
    tearDown(() async {
      await client.disconnect();
      await daemon.close();
    });

    test('scan lists installed bloat and removed packages', () async {
      daemon.shellResponses.addAll({
        'cat /proc/meminfo': _meminfo,
        'df -k /data': _df,
        'settings get global window_animation_scale': '0.5',
        'pm list packages': 'package:com.netflix.ninja\npackage:tv.alphonso.alphonso_eula\npackage:com.google.android.gms\n',
        'pm list packages -u': 'package:com.netflix.ninja\npackage:tv.alphonso.alphonso_eula\npackage:com.google.android.gms\npackage:com.android.camera2\n',
      });
      final report = await TvTuneUp(client).scan();
      expect(report.removable.map((a) => a.package), [
        'tv.alphonso.alphonso_eula',
        'com.netflix.ninja',
      ]);
      expect(report.removed, ['com.android.camera2']);
      expect(report.animationScale, 0.5);
      expect(report.health.memoryFree, 830468 * 1024);
    });

    test(
      'remove only touches the safe list and restore validates names',
      () async {
        final tuneUp = TvTuneUp(client);
        daemon.shellResponses['pm uninstall -k --user 0 com.android.camera2'] =
            'Success\n';
        await tuneUp.remove('com.android.camera2');
        await expectLater(
          tuneUp.remove('com.google.android.gms'),
          throwsA(isA<AdbException>()),
        );
        await expectLater(
          tuneUp.restore('a; reboot'),
          throwsA(isA<AdbException>()),
        );
        daemon.shellResponses['pm install-existing com.android.camera2'] =
            'Package com.android.camera2 installed for user: 0\n';
        await tuneUp.restore('com.android.camera2');
        await tuneUp.setAnimationScale(0.5);
        expect(daemon.commands.where((c) => c.startsWith('pm ')), [
          'pm uninstall -k --user 0 com.android.camera2',
          'pm install-existing com.android.camera2',
        ]);
        expect(
          daemon.commands.where((c) => c.startsWith('settings put')).length,
          3,
        );
      },
    );
  });
}
