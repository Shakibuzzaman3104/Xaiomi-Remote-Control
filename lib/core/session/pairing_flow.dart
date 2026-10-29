/**
 * @author Shakib
 * @since 29/10/26
 */
import '../discovery/tv_discovery.dart';
import '../remote/atv_certificate.dart';
import '../remote/atv_pairing.dart';
import '../storage/paired_tv_store.dart';

class PairingFlow {
  PairingFlow({
    required this.store,
    AtvPairingClient Function(String host, AtvCertificate cert)?
    pairingClientFactory,
    AtvCertificate Function()? certificateFactory,
  }) : _clientFactory = pairingClientFactory ?? _defaultClient,
       _certificateFactory = certificateFactory ?? AtvCertificate.generate;

  final PairedTvStore store;
  final AtvPairingClient Function(String, AtvCertificate) _clientFactory;
  final AtvCertificate Function() _certificateFactory;
  AtvPairingClient? _client;
  AtvCertificate? _certificate;
  DiscoveredTv? _tv;
  int _generation = 0;

  static AtvPairingClient _defaultClient(String host, AtvCertificate cert) =>
      AtvPairingClient(host: host, certificate: cert);

  Future<void> begin(DiscoveredTv tv) async {
    final generation = ++_generation;
    _client?.close();
    _client = null;
    _tv = null;
    final cert = _certificateFactory();
    final client = _clientFactory(tv.host, cert);
    _client = client;
    try {
      await client.startPairing();
    } catch (_) {
      client.close();
      rethrow;
    }
    if (generation != _generation) {
      client.close();
      return;
    }
    _certificate = cert;
    _tv = tv;
  }

  Future<PairedTv> complete(String code) async {
    final client = _client;
    final tv = _tv;
    final cert = _certificate;
    final generation = _generation;
    if (client == null || tv == null || cert == null) {
      throw const AtvPairingException('Pairing has not started');
    }
    await client.finishPairing(code);
    if (generation != _generation) {
      throw const AtvPairingException('Pairing was cancelled');
    }
    final paired = PairedTv(
      id: tv.host,
      name: tv.friendlyName ?? tv.name,
      host: tv.host,
      model: tv.model,
      serviceName: tv.name,
      tvCertSha256: client.tvCertSha256,
      certPem: cert.certPem,
      privateKeyPem: cert.privateKeyPem,
      pairedAt: DateTime.now(),
    );
    await store.save(paired);
    await store.saveLastUsedId(paired.id);
    _client = null;
    _tv = null;
    _certificate = null;
    return paired;
  }

  Future<void> cancel() async {
    ++_generation;
    _client?.close();
    _client = null;
    _tv = null;
    _certificate = null;
  }
}
