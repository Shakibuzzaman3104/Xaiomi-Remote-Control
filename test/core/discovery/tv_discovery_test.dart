/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/discovery/tv_discovery.dart';

class FakeDiscovery implements BonsoirDiscovery {
  FakeDiscovery({this.initialization, this.startError = false});
  final Future<void>? initialization;
  final bool startError;
  final events = StreamController<BonsoirDiscoveryEvent>.broadcast(sync: true);
  int starts = 0;
  int stops = 0;

  @override
  Future<void> initialize() async {
    await initialization;
  }

  @override
  Future<void> start() async {
    starts++;
    if (startError) throw StateError('start failed');
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Stream<BonsoirDiscoveryEvent> get eventStream => events.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('replays found devices and restart replaces the scan', () async {
    final scans = <FakeDiscovery>[];
    final discovery = TvDiscovery(
      discoveryFactory: (_) {
        final scan = FakeDiscovery();
        scans.add(scan);
        return scan;
      },
    );
    await discovery.start();
    scans.first.events.add(
      BonsoirDiscoveryServiceResolvedEvent(
        service: const BonsoirService.ignoreNorms(
          name: 'TV',
          type: TvDiscovery.remoteServiceType,
          hostAddresses: ['192.168.1.2'],
          port: 6466,
        ),
      ),
    );
    expect((await discovery.devices.first).single.host, '192.168.1.2');
    await discovery.restart();
    expect(scans.length, 6);
    expect(scans.take(3).every((scan) => scan.stops == 1), isTrue);
    expect(scans.skip(3).every((scan) => scan.starts == 1), isTrue);
    expect(await discovery.devices.first, isEmpty);
    await discovery.stop();
    for (final scan in scans) {
      await scan.events.close();
    }
  });

  test('stop during initialization prevents a late start', () async {
    final gate = Completer<void>();
    final scan = FakeDiscovery(initialization: gate.future);
    final discovery = TvDiscovery(discoveryFactory: (_) => scan);
    final starting = discovery.start();
    await Future<void>.delayed(Duration.zero);
    final stopping = discovery.stop();
    gate.complete();
    await starting;
    await stopping;
    expect(scan.starts, 0);
    expect(scan.stops, 1);
    await scan.events.close();
  });

  test('start failure cleans up and permits a later start', () async {
    final scans = <FakeDiscovery>[];
    final discovery = TvDiscovery(
      discoveryFactory: (_) {
        final scan = FakeDiscovery(startError: scans.length == 1);
        scans.add(scan);
        return scan;
      },
    );
    await expectLater(discovery.start(), throwsStateError);
    expect(scans.every((scan) => scan.stops == 1), isTrue);
    await discovery.start();
    expect(scans.length, 5);
    await discovery.stop();
    for (final scan in scans) {
      await scan.events.close();
    }
  });

  test('stop cancels a pending restart', () async {
    final gate = Completer<void>();
    final scan = FakeDiscovery(initialization: gate.future);
    var created = 0;
    final discovery = TvDiscovery(
      discoveryFactory: (_) {
        created++;
        return scan;
      },
    );
    final starting = discovery.start();
    await Future<void>.delayed(Duration.zero);
    final restarting = discovery.restart();
    final stopping = discovery.stop();
    gate.complete();
    await starting;
    await restarting;
    await stopping;
    expect(created, 1);
    expect(scan.starts, 0);
    expect(scan.stops, 1);
    await scan.events.close();
  });
}
