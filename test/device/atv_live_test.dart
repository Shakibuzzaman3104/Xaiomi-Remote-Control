/**
 * @author Shakib
 * @since 29/10/26
 */
@Tags(['device'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/remote/atv_certificate.dart';
import 'package:xiaomi_remote/core/remote/atv_remote.dart';

void main() {
  final host = Platform.environment['ATV_HOST'];
  final certDir = Platform.environment['ATV_CERT_DIR'];

  test('connects to a real TV, reads state and presses a key', () async {
    final certificate = AtvCertificate(
      certPem: File('$certDir/cert.pem').readAsStringSync(),
      privateKeyPem: File('$certDir/key.pem').readAsStringSync(),
    );
    final client = AtvRemoteClient(host: host!, certificate: certificate);
    await client.connect();
    await Future<void>.delayed(const Duration(seconds: 2));
    final state = client.state;
    stdout.writeln('state: connected=${state.connected} on=${state.isOn} app=${state.currentApp} '
        'model=${state.deviceModel} features=${state.supportedFeatures}');
    expect(state.connected, isTrue);
    expect(state.supportedFeatures & 2, 2);
    client.sendKey(RemoteKeyCode.KEYCODE_HOME);
    await Future<void>.delayed(const Duration(seconds: 1));
    await client.disconnect();
  }, skip: host == null ? 'set ATV_HOST and ATV_CERT_DIR' : false);
}
