/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/remote/atv_certificate.dart';

void main() {
  test('generates a 2048-bit RSA certificate', () {
    final certificate = AtvCertificate.generate(commonName: 'Test');
    final modulus = X509Utils.getModulusFromRSAX509Pem(certificate.certPem);
    expect(modulus.bitLength, 2048);
    expect(
      CryptoUtils.rsaPrivateKeyFromPemPkcs1(certificate.privateKeyPem).modulus,
      modulus,
    );
  });

  test('each certificate gets its own common name', () {
    String commonName(AtvCertificate c) =>
        X509Utils.x509CertificateFromPem(c.certPem)
            .tbsCertificate!
            .subject['2.5.4.3']!;
    final first = commonName(AtvCertificate.generate());
    final second = commonName(AtvCertificate.generate());
    expect(first, startsWith('xiaomi_remote_'));
    expect(first, isNot(second));
  });
}
