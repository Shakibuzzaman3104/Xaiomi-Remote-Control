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

  test(
    'stays connected on TV pings alone',
    () async {
      final client = AtvRemoteClient(
        host: host!,
        certificate: AtvCertificate(
          certPem: File('$certDir/cert.pem').readAsStringSync(),
          privateKeyPem: File('$certDir/key.pem').readAsStringSync(),
        ),
      );
      Object? lost;
      client.states.listen((_) {}, onError: (Object e) => lost = e);
      await client.connect();
      await Future<void>.delayed(const Duration(seconds: 40));
      expect(lost, isNull);
      expect(client.state.connected, isTrue);
      await client.disconnect();
    },
    timeout: const Timeout(Duration(seconds: 60)),
    skip: host == null ? 'set ATV_HOST and ATV_CERT_DIR' : false,
  );
}
