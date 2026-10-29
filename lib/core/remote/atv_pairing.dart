/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';

import 'atv_certificate.dart';
import 'atv_framing.dart';
import 'proto/polo.pb.dart';

/// An error during Android TV pairing.
enum PairingFailureKind { unreachable, wrongCode, expired }

class AtvPairingException implements Exception {
  const AtvPairingException(this.message, [this.kind = PairingFailureKind.expired]);
  final PairingFailureKind kind;
  final String message;
  @override
  String toString() => 'AtvPairingException: $message';
}

Uint8List _hexBytes(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

Uint8List _integerBytes(BigInt value) {
  var hex = value.toRadixString(16).toUpperCase();
  if (hex.length.isOdd) hex = '0$hex';
  return _hexBytes(hex);
}

void _validateCode(String code) {
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(code)) {
    throw const AtvPairingException(
      'Pairing code must contain six hexadecimal digits',
      PairingFailureKind.wrongCode,
    );
  }
}

/// Computes the pairing secret from both certificate keys and the code.
Uint8List computePairingSecret({
  required String clientCertPem,
  required String serverCertPem,
  required String code,
}) {
  _validateCode(code);
  List<int> keyBytes(String pem) {
    final data = X509Utils.x509CertificateFromPem(pem);
    final key = CryptoUtils.rsaPublicKeyFromDERBytes(
      _hexBytes(data.tbsCertificate!.subjectPublicKeyInfo.bytes!),
    );
    return [..._integerBytes(key.modulus!), ..._integerBytes(key.exponent!)];
  }

  return Uint8List.fromList(
    sha256.convert([
      ...keyBytes(clientCertPem),
      ...keyBytes(serverCertPem),
      ..._hexBytes(code.substring(2)),
    ]).bytes,
  );
}

/// Checks the verification byte embedded in a pairing code.
bool pairingCodeMatches({
  required String clientCertPem,
  required String serverCertPem,
  required String code,
}) =>
    computePairingSecret(
      clientCertPem: clientCertPem,
      serverCertPem: serverCertPem,
      code: code,
    )[0] ==
    int.parse(code.substring(0, 2), radix: 16);

SecurityContext atvSecurityContext(AtvCertificate certificate) =>
    SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(certificate.certPem))
      ..usePrivateKeyBytes(utf8.encode(certificate.privateKeyPem));

/// Performs the Android TV pairing handshake over TLS.
class AtvPairingClient {
  AtvPairingClient({
    required this.host,
    required this.certificate,
    this.port = 6467,
    this.clientName = 'Xiaomi Remote',
  });
  final String host;
  final int port;
  final String clientName;
  final AtvCertificate certificate;
  SecureSocket? _socket;
  Completer<void>? _pending;
  final FrameDecoder _decoder = FrameDecoder();
  int _step = 0;
  bool _closed = false;
  Timer? _codeTimer;
  String? tvCertSha256;

  void close() {
    if (_closed) return;
    _closed = true;
    _codeTimer?.cancel();
    _fail('Pairing closed');
    _socket?.destroy();
    _socket = null;
  }

  OuterMessage _message() =>
      OuterMessage(protocolVersion: 2, status: OuterMessage_Status.STATUS_OK);
  void _send(OuterMessage message) =>
      _socket!.add(frame(Uint8List.fromList(message.writeToBuffer())));

  Future<void> startPairing() async {
    if (_socket != null) {
      throw const AtvPairingException('Pairing already started');
    }
    try {
      final socket = await SecureSocket.connect(
        host,
        port,
        context: atvSecurityContext(certificate),
        onBadCertificate: (_) => true,
        timeout: const Duration(seconds: 10),
      );
      if (_closed) {
        socket.destroy();
        throw const AtvPairingException('Pairing closed');
      }
      _socket = socket;
      final peer = socket.peerCertificate;
      if (peer == null) {
        throw const AtvPairingException('Server certificate is missing', PairingFailureKind.unreachable);
      }
      tvCertSha256 = sha256.convert(peer.der).toString();
      _socket!.listen(
        _receive,
        onError: (Object e) => _connectionLost(
          'Connection error: $e',
          PairingFailureKind.unreachable,
        ),
        onDone: () => _connectionLost('Connection closed'),
      );
      _step = 1;
      _pending = Completer<void>();
      final message = _message();
      message.pairingRequest = PairingRequest(
        serviceName: 'atvremote',
        clientName: clientName,
      );
      _send(message);
      await _pending!.future.timeout(const Duration(seconds: 10));
      if (_closed) throw const AtvPairingException('Pairing closed');
      _codeTimer = Timer(const Duration(minutes: 3), close);
    } catch (e) {
      _socket?.destroy();
      _socket = null;
      if (e is AtvPairingException) rethrow;
      throw AtvPairingException('Unable to start pairing: $e', PairingFailureKind.unreachable);
    }
  }

  Future<void> finishPairing(String code) async {
    _validateCode(code);
    if (_socket == null || _step != 4) {
      throw const AtvPairingException('Pairing has not started');
    }
    final serverPem = _socket!.peerCertificate?.pem;
    if (serverPem == null) {
      throw const AtvPairingException('Server certificate is missing');
    }
    final secret = computePairingSecret(
      clientCertPem: certificate.certPem,
      serverCertPem: serverPem,
      code: code,
    );
    if (secret[0] != int.parse(code.substring(0, 2), radix: 16)) {
      throw const AtvPairingException('Incorrect pairing code', PairingFailureKind.wrongCode);
    }
    _codeTimer?.cancel();
    _step = 5;
    _pending = Completer<void>();
    try {
      _send(_message()..secret = Secret(secret: secret));
      await _pending!.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      if (e is AtvPairingException) rethrow;
      throw AtvPairingException(
        'Unable to finish pairing: $e',
        PairingFailureKind.unreachable,
      );
    } finally {
      _pending = null;
      close();
    }
  }

  void _receive(List<int> data) {
    try {
      for (final bytes in _decoder.add(data)) {
        final message = OuterMessage.fromBuffer(bytes);
        if (message.status != OuterMessage_Status.STATUS_OK) {
          if (_step == 5) {
            final pending = _pending;
            if (pending != null && !pending.isCompleted) {
              pending.completeError(AtvPairingException(
                'Pairing status: ${message.status}', PairingFailureKind.wrongCode,
              ));
            }
            close();
            return;
          }
          throw AtvPairingException('Pairing status: ${message.status}');
        }
        if (_step == 1 && message.hasPairingRequestAck()) {
          final options = Options(
            preferredRole: Options_RoleType.ROLE_TYPE_INPUT,
          );
          options.inputEncodings.add(
            Options_Encoding(
              type: Options_Encoding_EncodingType.ENCODING_TYPE_HEXADECIMAL,
              symbolLength: 6,
            ),
          );
          _step = 2;
          _send(_message()..options = options);
        } else if (_step == 2 && message.hasOptions()) {
          _step = 3;
          _send(
            _message()
              ..configuration = Configuration(
                clientRole: Options_RoleType.ROLE_TYPE_INPUT,
                encoding: Options_Encoding(
                  type: Options_Encoding_EncodingType.ENCODING_TYPE_HEXADECIMAL,
                  symbolLength: 6,
                ),
              ),
          );
        } else if (_step == 3 && message.hasConfigurationAck()) {
          _step = 4;
          _pending!.complete();
        } else if (_step == 5 && message.hasSecretAck()) {
          _step = 6;
          _pending!.complete();
        } else {
          throw const AtvPairingException('Unexpected pairing message');
        }
      }
    } catch (e) {
      _connectionLost('$e');
    }
  }

  void _fail(String message, [PairingFailureKind? kind]) {
    if (_pending != null && !_pending!.isCompleted) {
      _pending!.completeError(AtvPairingException(
        message,
        kind ?? (_step < 4 && !_closed ? PairingFailureKind.unreachable : PairingFailureKind.expired),
      ));
    }
  }

  void _connectionLost(String message, [PairingFailureKind? kind]) {
    _fail(message, kind);
    close();
  }
}
