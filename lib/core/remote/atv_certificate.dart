/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:math';

import 'package:basic_utils/basic_utils.dart';

/// A client certificate and its private key in PEM format.
class AtvCertificate {
  const AtvCertificate({required this.certPem, required this.privateKeyPem});
  final String certPem;
  final String privateKeyPem;

  /// The TV keeps one pairing per common name, so each install needs its own.
  static AtvCertificate generate({String? commonName}) {
    commonName ??= 'xiaomi_remote_${_randomSuffix()}';
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

  static String _randomSuffix() {
    final random = Random.secure();
    return List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
  }
}
