/**
 * @author Shakib
 * @since 29/10/26
 */

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Represents an Android TV device paired with this app.
class PairedTv {
  final String id;
  final String name;
  final String host;
  final String? model;
  final String certPem;
  final String privateKeyPem;
  final DateTime pairedAt;
  final DateTime? lastConnectedAt;

  const PairedTv({
    required this.id,
    required this.name,
    required this.host,
    this.model,
    required this.certPem,
    required this.privateKeyPem,
    required this.pairedAt,
    this.lastConnectedAt,
  });

  PairedTv copyWith({
    String? id,
    String? name,
    String? host,
    String? model,
    String? certPem,
    String? privateKeyPem,
    DateTime? pairedAt,
    DateTime? lastConnectedAt,
  }) {
    return PairedTv(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      model: model ?? this.model,
      certPem: certPem ?? this.certPem,
      privateKeyPem: privateKeyPem ?? this.privateKeyPem,
      pairedAt: pairedAt ?? this.pairedAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'model': model,
      'certPem': certPem,
      'privateKeyPem': privateKeyPem,
      'pairedAt': pairedAt.toIso8601String(),
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
    };
  }

  factory PairedTv.fromJson(Map<String, dynamic> json) {
    return PairedTv(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      model: json['model'] as String?,
      certPem: json['certPem'] as String,
      privateKeyPem: json['privateKeyPem'] as String,
      pairedAt: DateTime.parse(json['pairedAt'] as String),
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.parse(json['lastConnectedAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairedTv &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          host == other.host &&
          model == other.model &&
          certPem == other.certPem &&
          privateKeyPem == other.privateKeyPem &&
          pairedAt == other.pairedAt &&
          lastConnectedAt == other.lastConnectedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    host,
    model,
    certPem,
    privateKeyPem,
    pairedAt,
    lastConnectedAt,
  );
}

/// Abstract contract for asynchronous key-value persistence.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// KeyValueStore implementation backed by FlutterSecureStorage.
class SecureKeyValueStore implements KeyValueStore {
  final FlutterSecureStorage _storage;

  SecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Manages persistence of paired TV devices and session state.
class PairedTvStore {
  static const String _pairedTvsKey = 'paired_tvs';
  static const String _lastUsedIdKey = 'last_used_id';

  final KeyValueStore _store;

  PairedTvStore(this._store);

  Future<List<PairedTv>> loadAll() async {
    final raw = await _store.read(_pairedTvsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) => PairedTv.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> save(PairedTv tv) async {
    final list = await loadAll();
    final index = list.indexWhere((item) => item.id == tv.id);
    if (index >= 0) {
      list[index] = tv;
    } else {
      list.add(tv);
    }
    final encoded = jsonEncode(list.map((item) => item.toJson()).toList());
    await _store.write(_pairedTvsKey, encoded);
  }

  Future<void> remove(String id) async {
    final list = await loadAll();
    list.removeWhere((item) => item.id == id);
    final encoded = jsonEncode(list.map((item) => item.toJson()).toList());
    await _store.write(_pairedTvsKey, encoded);
  }

  Future<String?> loadLastUsedId() => _store.read(_lastUsedIdKey);

  Future<void> saveLastUsedId(String id) => _store.write(_lastUsedIdKey, id);
}
