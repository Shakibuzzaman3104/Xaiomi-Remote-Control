/**
 * @author Shakib
 * @since 29/10/26
 */
@Tags(['device'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/adb/adb_client.dart';
import 'package:xiaomi_remote/core/adb/adb_commands.dart';
import 'package:xiaomi_remote/core/adb/adb_key.dart';

void main() {
  final host = Platform.environment['ATV_HOST'];
  final keyDir = Platform.environment['ATV_CERT_DIR'];

  test('dart adb client drives a real TV', () async {
    final privateFile = File('$keyDir/adb_key.pem');
    final publicFile = File('$keyDir/adb_key.pub.pem');
    final key = privateFile.existsSync()
        ? AdbKey(
            privateKeyPem: privateFile.readAsStringSync(),
            publicKeyPem: publicFile.readAsStringSync(),
          )
        : AdbKey.generate();
    privateFile.writeAsStringSync(key.privateKeyPem);
    publicFile.writeAsStringSync(key.publicKeyPem);

    final client = AdbClient(host: host!, key: key);
    client.states.listen((s) => stdout.writeln('adb state: $s'));
    await client.connect(authTimeout: const Duration(seconds: 90));
    stdout.writeln('model: ${client.deviceModel}');
    final commands = AdbCommands(client);
    stdout.writeln('getprop: ${(await client.shell('getprop ro.product.model')).trim()}');
    stdout.writeln('apps: ${(await commands.listLauncherApps()).length}');
    stdout.writeln('volume: ${await commands.musicVolume()}');
    final png = await commands.screencapPng();
    stdout.writeln('screencap bytes: ${png.length}, png=${png[1] == 0x50}');
    final helper = File('assets/tv_helper.jar').readAsBytesSync();
    await client.push(helper, '/data/local/tmp/xr_helper.jar');
    final apps = await client.shell(
      'CLASSPATH=/data/local/tmp/xr_helper.jar app_process / '
      'com.diatomicsoft.xiaomiremote.helper.Main apps 48',
      timeout: const Duration(seconds: 30),
    );
    stdout.writeln('helper apps: ${apps.trim().split('\n').length}');
    await commands.launchApp('com.banglalink.toffeetv');
    await Future<void>.delayed(const Duration(seconds: 4));
    final focus = await client.shell('dumpsys window | grep mCurrentFocus');
    stdout.writeln('focus after launch: ${focus.trim()}');
    expect(focus, contains('toffee'));
    await client.shell('input keyevent KEYCODE_HOME');
    await client.disconnect();
  }, timeout: const Timeout(Duration(minutes: 3)),
      skip: host == null ? 'set ATV_HOST and ATV_CERT_DIR' : false);
}
