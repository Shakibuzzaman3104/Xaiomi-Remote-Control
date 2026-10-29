/**
 * @author Shakib
 * @since 29/10/26
 */

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/core/storage/paired_tv_store.dart';

/// In-memory KeyValueStore fake for testing.
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

void main() {
  group('PairedTvStore', () {
    late InMemoryKeyValueStore memoryStore;
    late PairedTvStore store;

    setUp(() {
      memoryStore = InMemoryKeyValueStore();
      store = PairedTvStore(memoryStore);
    });

    test('save and loadAll round-trip with all fields including dates', () async {
      final pairedAt = DateTime.parse('2026-10-29T20:00:00.000Z');
      final lastConnectedAt = DateTime.parse('2026-10-29T20:30:00.000Z');

      final tv = PairedTv(
        id: '192.168.1.100',
        name: 'Living Room TV',
        host: '192.168.1.100',
        model: 'MIBOX4',
        certPem: '-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----',
        privateKeyPem: '-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----',
        pairedAt: pairedAt,
        lastConnectedAt: lastConnectedAt,
      );

      await store.save(tv);
      final list = await store.loadAll();

      expect(list.length, 1);
      expect(list.first.id, tv.id);
      expect(list.first.name, tv.name);
      expect(list.first.host, tv.host);
      expect(list.first.model, tv.model);
      expect(list.first.certPem, tv.certPem);
      expect(list.first.privateKeyPem, tv.privateKeyPem);
      expect(list.first.pairedAt, tv.pairedAt);
      expect(list.first.lastConnectedAt, tv.lastConnectedAt);
      expect(list.first, equals(tv));
    });

    test('save replaces existing device by id', () async {
      final tv1 = PairedTv(
        id: '192.168.1.101',
        name: 'Old Name',
        host: '192.168.1.101',
        certPem: 'cert1',
        privateKeyPem: 'key1',
        pairedAt: DateTime.parse('2026-10-20T10:00:00Z'),
      );

      final tv2 = PairedTv(
        id: '192.168.1.101',
        name: 'New Name',
        host: '192.168.1.101',
        model: 'MIBOXS',
        certPem: 'cert2',
        privateKeyPem: 'key2',
        pairedAt: DateTime.parse('2026-10-21T10:00:00Z'),
      );

      await store.save(tv1);
      var list = await store.loadAll();
      expect(list.length, 1);
      expect(list.first.name, 'Old Name');

      await store.save(tv2);
      list = await store.loadAll();
      expect(list.length, 1);
      expect(list.first.name, 'New Name');
      expect(list.first.model, 'MIBOXS');
      expect(list.first.certPem, 'cert2');
    });

    test('remove deletes entry by id', () async {
      final tv1 = PairedTv(
        id: '192.168.1.10',
        name: 'TV 1',
        host: '192.168.1.10',
        certPem: 'c1',
        privateKeyPem: 'k1',
        pairedAt: DateTime.now(),
      );
      final tv2 = PairedTv(
        id: '192.168.1.11',
        name: 'TV 2',
        host: '192.168.1.11',
        certPem: 'c2',
        privateKeyPem: 'k2',
        pairedAt: DateTime.now(),
      );

      await store.save(tv1);
      await store.save(tv2);

      var list = await store.loadAll();
      expect(list.length, 2);

      await store.remove('192.168.1.10');
      list = await store.loadAll();
      expect(list.length, 1);
      expect(list.first.id, '192.168.1.11');
    });

    test('last-used id persistence', () async {
      expect(await store.loadLastUsedId(), isNull);

      await store.saveLastUsedId('192.168.1.200');
      expect(await store.loadLastUsedId(), '192.168.1.200');

      await store.saveLastUsedId('192.168.1.201');
      expect(await store.loadLastUsedId(), '192.168.1.201');
    });

    test('JSON round-trip of PairedTv with Bangla name "বসার ঘর"', () {
      final tv = PairedTv(
        id: '192.168.1.50',
        name: 'বসার ঘর',
        host: '192.168.1.50',
        model: 'MIBOX4',
        certPem: 'test_cert',
        privateKeyPem: 'test_key',
        pairedAt: DateTime.parse('2026-10-29T12:00:00Z'),
        lastConnectedAt: DateTime.parse('2026-10-29T14:30:00Z'),
      );

      final jsonMap = tv.toJson();
      final serialized = jsonEncode(jsonMap);
      final deserialized = jsonDecode(serialized) as Map<String, dynamic>;
      final result = PairedTv.fromJson(deserialized);

      expect(result.name, 'বসার ঘর');
      expect(result.id, tv.id);
      expect(result.host, tv.host);
      expect(result.model, tv.model);
      expect(result.certPem, tv.certPem);
      expect(result.privateKeyPem, tv.privateKeyPem);
      expect(result.pairedAt, tv.pairedAt);
      expect(result.lastConnectedAt, tv.lastConnectedAt);
      expect(result, equals(tv));
    });
  });
}
