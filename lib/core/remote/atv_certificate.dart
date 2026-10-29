/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/asymmetric/api.dart';

/// A client certificate and its private key in PEM format.
class AtvCertificate {
  const AtvCertificate({required this.certPem, required this.privateKeyPem});
  final String certPem;
  final String privateKeyPem;

  static AtvCertificate generate({String commonName = 'xiaomi_remote'}) {
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final privateKey = pair.privateKey as RSAPrivateKey;
    final publicKey = pair.publicKey as RSAPublicKey;
    final csr = X509Utils.generateRsaCsrPem(
      {'CN': commonName},
      privateKey,
      publicKey,
    );
    return AtvCertificate(
      certPem: X509Utils.generateSelfSignedCertificate(
        privateKey,
        csr,
        3650,
        sans: [commonName],
        cA: true,
        pathLenConstraint: 0,
        serialNumber: '1000',
      ),
      privateKeyPem: CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(privateKey),
    );
  }
}
