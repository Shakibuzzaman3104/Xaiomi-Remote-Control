/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/remote/atv_pairing.dart';

void main() {
  test('captured Mi Box secret and verification byte', () {
    final client = File('test/fixtures/client_cert.pem').readAsStringSync();
    final server = File('test/fixtures/server_cert.pem').readAsStringSync();
    final secret = computePairingSecret(
      clientCertPem: client,
      serverCertPem: server,
      code: 'A72A9E',
    );
    expect(
      secret.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      'a764093d894c07c30ec774b65535c8a3694cbbdec98190b282646743eca9bd76',
    );
    expect(
      pairingCodeMatches(
        clientCertPem: client,
        serverCertPem: server,
        code: 'A72A9E',
      ),
      isTrue,
    );
    expect(
      pairingCodeMatches(
        clientCertPem: client,
        serverCertPem: server,
        code: 'B72A9E',
      ),
      isFalse,
    );
  });
}
