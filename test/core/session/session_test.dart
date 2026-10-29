/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/discovery/tv_discovery.dart';
import 'package:xiaomi_remote/core/remote/atv_certificate.dart';
import 'package:xiaomi_remote/core/remote/atv_pairing.dart';
import 'package:xiaomi_remote/core/remote/atv_remote.dart';
import 'package:xiaomi_remote/core/session/key_mapping.dart';
import 'package:xiaomi_remote/core/session/pairing_flow.dart';
import 'package:xiaomi_remote/core/session/remote_button.dart';
import 'package:xiaomi_remote/core/session/tv_session.dart';
import 'package:xiaomi_remote/core/storage/paired_tv_store.dart';

const cert = AtvCertificate(certPem: 'cert', privateKeyPem: 'key');
final tv = PairedTv(
  id: 'host',
  name: 'TV',
  host: 'host',
  certPem: 'cert',
  privateKeyPem: 'key',
  pairedAt: DateTime(2026),
);

class FakeRemote extends AtvRemoteClient {
  FakeRemote({this.fail = false}) : super(host: 'host', certificate: cert);
  final bool fail;
  final controller = StreamController<AtvState>.broadcast();
  AtvState current = const AtvState();
  RemoteKeyCode? key;
  RemoteDirection? direction;
  @override
  Stream<AtvState> get states => controller.stream;
  @override
  AtvState get state => current;
  @override
  Future<void> connect() async {
    if (fail) throw const AtvConnectionLostException('failed');
    current = const AtvState(connected: true);
    controller.add(current);
  }

  void lose() => controller.addError(const AtvConnectionLostException('lost'));
  @override
  Future<void> disconnect() async {
    await controller.close();
  }

  @override
  void sendKey(
    RemoteKeyCode code, {
    RemoteDirection direction = RemoteDirection.SHORT,
  }) {
    key = code;
    this.direction = direction;
  }
}

class MemoryStore implements KeyValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FakePairing extends AtvPairingClient {
  FakePairing() : super(host: 'host', certificate: cert);
  bool started = false;
  @override
  Future<void> startPairing() async {
    started = true;
  }

  @override
  Future<void> finishPairing(String code) async {
    if (code != '123456') throw const AtvPairingException('Incorrect code');
  }
}

Future<void> waitFor(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(condition(), isTrue);
}

void main() {
  test('all buttons map to the expected keys', () {
    final expected = [
      RemoteKeyCode.KEYCODE_DPAD_UP,
      RemoteKeyCode.KEYCODE_DPAD_DOWN,
      RemoteKeyCode.KEYCODE_DPAD_LEFT,
      RemoteKeyCode.KEYCODE_DPAD_RIGHT,
      RemoteKeyCode.KEYCODE_DPAD_CENTER,
      RemoteKeyCode.KEYCODE_BACK,
      RemoteKeyCode.KEYCODE_HOME,
      RemoteKeyCode.KEYCODE_SETTINGS,
      RemoteKeyCode.KEYCODE_VOLUME_UP,
      RemoteKeyCode.KEYCODE_VOLUME_DOWN,
      RemoteKeyCode.KEYCODE_VOLUME_MUTE,
      RemoteKeyCode.KEYCODE_MEDIA_PLAY_PAUSE,
      RemoteKeyCode.KEYCODE_MEDIA_REWIND,
      RemoteKeyCode.KEYCODE_MEDIA_FAST_FORWARD,
      RemoteKeyCode.KEYCODE_POWER,
      RemoteKeyCode.KEYCODE_CHANNEL_UP,
      RemoteKeyCode.KEYCODE_CHANNEL_DOWN,
      RemoteKeyCode.KEYCODE_0,
      RemoteKeyCode.KEYCODE_1,
      RemoteKeyCode.KEYCODE_2,
      RemoteKeyCode.KEYCODE_3,
      RemoteKeyCode.KEYCODE_4,
      RemoteKeyCode.KEYCODE_5,
      RemoteKeyCode.KEYCODE_6,
      RemoteKeyCode.KEYCODE_7,
      RemoteKeyCode.KEYCODE_8,
      RemoteKeyCode.KEYCODE_9,
      RemoteKeyCode.KEYCODE_ENTER,
      RemoteKeyCode.KEYCODE_DEL,
    ];
    expect(RemoteButton.values.map(keyCodeFor), expected);
  });

  test('connects, sends a key, and reconnects after loss', () async {
    final clients = <FakeRemote>[];
    final session = TvSession(
      tv: tv,
      backoff: (_) => const Duration(milliseconds: 5),
      clientFactory: (_) {
        final c = FakeRemote();
        clients.add(c);
        return c;
      },
    );
    await session.start();
    expect(session.isConnected, isTrue);
    session.press(RemoteButton.ok);
    expect(clients.first.key, RemoteKeyCode.KEYCODE_DPAD_CENTER);
    expect(clients.first.direction, RemoteDirection.SHORT);
    clients.first.lose();
    await waitFor(() => session.state.status == SessionStatus.reconnecting);
    await waitFor(() => clients.length == 2 && session.isConnected);
    await session.dispose();
  });

  test('stops after six failures and retries on demand', () async {
    var fail = true;
    var count = 0;
    final session = TvSession(
      tv: tv,
      backoff: (_) => const Duration(milliseconds: 1),
      clientFactory: (_) {
        count++;
        return FakeRemote(fail: fail);
      },
    );
    await session.start();
    await waitFor(() => session.state.status == SessionStatus.offline);
    expect(count, 6);
    expect(session.state.attempt, 6);
    session.press(RemoteButton.ok);
    session.sendText('hello');
    expect(await session.startVoice(), -1);
    fail = false;
    session.retryNow();
    await waitFor(() => session.isConnected);
    expect(count, 7);
    await session.dispose();
  });

  test('pairing persists the TV and selection', () async {
    final store = PairedTvStore(MemoryStore());
    final client = FakePairing();
    final flow = PairingFlow(
      store: store,
      certificateFactory: () => cert,
      pairingClientFactory: (_, _) => client,
    );
    await flow.begin(
      const DiscoveredTv(
        name: 'Device',
        host: 'host',
        friendlyName: 'Living room',
        model: 'Box',
      ),
    );
    expect(client.started, isTrue);
    await expectLater(
      flow.complete('bad'),
      throwsA(isA<AtvPairingException>()),
    );
    final paired = await flow.complete('123456');
    expect(paired.name, 'Living room');
    expect(paired.model, 'Box');
    expect(await store.loadAll(), [paired]);
    expect(await store.loadLastUsedId(), 'host');
  });
}
