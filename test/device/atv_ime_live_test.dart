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

/// Needs a focused text field on the TV (e.g. a browser search box).
void main() {
  final host = Platform.environment['ATV_HOST'];
  final certDir = Platform.environment['ATV_CERT_DIR'];

  test(
    'replaces the focused field text',
    () async {
      final client = AtvRemoteClient(
        host: host!,
        certificate: AtvCertificate(
          certPem: File('$certDir/cert.pem').readAsStringSync(),
          privateKeyPem: File('$certDir/key.pem').readAsStringSync(),
        ),
      );
      await client.connect();
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(client.state.imeActive, isTrue);
      await client.replaceText('night sky');
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(client.state.imeValue, 'night sky');
      await client.replaceText('night skies');
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(client.state.imeValue, 'night skies');
      await client.replaceText('বাংলা নাটক');
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(client.state.imeValue, 'বাংলা নাটক');
      await client.disconnect();
    },
    skip: host == null ? 'set ATV_HOST and ATV_CERT_DIR' : false,
  );
}
