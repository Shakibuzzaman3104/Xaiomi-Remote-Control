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
}
