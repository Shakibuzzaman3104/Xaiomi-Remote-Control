/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/remote/atv_certificate.dart';
import 'package:xiaomi_remote/core/remote/atv_remote.dart';

void main() {
  test('matches, rejects changes, and records a legacy certificate', () {
    const der = [1, 2, 3];
    const fingerprint =
        '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81';
    expect(verifyTvCertificate(der, fingerprint), fingerprint);
    expect(verifyTvCertificate(der, null), fingerprint);
    expect(
      () => verifyTvCertificate([1, 2, 4], fingerprint),
      throwsA(isA<AtvIdentityChangedException>()),
    );
  });

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
