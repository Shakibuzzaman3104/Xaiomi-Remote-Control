/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';

class AdbKey {
  const AdbKey({required this.privateKeyPem, required this.publicKeyPem});
  final String privateKeyPem;
  final String publicKeyPem;

  static AdbKey generate() {
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    return AdbKey(
      privateKeyPem: CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(
        pair.privateKey as RSAPrivateKey,
      ),
      publicKeyPem: CryptoUtils.encodeRSAPublicKeyToPem(
        pair.publicKey as RSAPublicKey,
      ),
    );
  }

  Uint8List signToken(Uint8List token) {
    if (token.length != 20) throw ArgumentError('ADB token must be 20 bytes');
    final key = CryptoUtils.rsaPrivateKeyFromPemPkcs1(privateKeyPem);
    final digestInfo = <int>[
      0x30,
      0x21,
      0x30,
      0x09,
      0x06,
      0x05,
      0x2b,
      0x0e,
      0x03,
      0x02,
      0x1a,
      0x05,
      0x00,
      0x04,
      0x14,
      ...token,
    ];
    final block = Uint8List(256)
      ..[0] = 0
      ..[1] = 1;
    block.fillRange(2, 256 - digestInfo.length - 1, 0xff);
    block.setRange(256 - digestInfo.length, 256, digestInfo);
    var value = BigInt.zero;
    for (final byte in block) {
      value = (value << 8) | BigInt.from(byte);
    }
    value = value.modPow(key.privateExponent!, key.modulus!);
    final signature = Uint8List(256);
    for (var i = 255; i >= 0; i--) {
      signature[i] = (value & BigInt.from(255)).toInt();
      value >>= 8;
    }
    return signature;
  }

  String androidPublicKey() {
    final key = CryptoUtils.rsaPublicKeyFromPem(publicKeyPem);
    final n = key.modulus!;
    final word = BigInt.one << 32;
    final n0inv = (word - (n % word).modInverse(word)) % word;
    final rr = (BigInt.one << 4096) % n;
    final bytes = Uint8List(524);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, 64, Endian.little);
    data.setUint32(4, n0inv.toInt(), Endian.little);
    for (var i = 0; i < 64; i++) {
      data.setUint32(
        8 + i * 4,
        ((n >> (32 * i)) & (word - BigInt.one)).toInt(),
        Endian.little,
      );
      data.setUint32(
        264 + i * 4,
        ((rr >> (32 * i)) & (word - BigInt.one)).toInt(),
        Endian.little,
      );
    }
    data.setUint32(520, key.exponent!.toInt(), Endian.little);
    return '${base64Encode(bytes)} xiaomi_remote@phone\u0000';
  }
}
