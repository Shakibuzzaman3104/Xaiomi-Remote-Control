/**
 * @author Shakib
 * @since 29/10/26
 */

import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

/// Discovered Android TV device.
class DiscoveredTv {
  final String name;
  final String host;
  final int remotePort;
  final String? model;
  final String? friendlyName;
  final bool hasAdb;

  const DiscoveredTv({
    required this.name,
    required this.host,
    this.remotePort = 6466,
    this.model,
    this.friendlyName,
    this.hasAdb = false,
  });

  DiscoveredTv copyWith({
    String? name,
    String? host,
    int? remotePort,
    String? model,
    String? friendlyName,
    bool? hasAdb,
  }) {
    return DiscoveredTv(
      name: name ?? this.name,
      host: host ?? this.host,
      remotePort: remotePort ?? this.remotePort,
      model: model ?? this.model,
      friendlyName: friendlyName ?? this.friendlyName,
      hasAdb: hasAdb ?? this.hasAdb,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredTv &&
          runtimeType == other.runtimeType &&
          host == other.host;

  @override
  int get hashCode => host.hashCode;
}

/// Discovers Android TV devices on the local network using mDNS.
class TvDiscovery {
  TvDiscovery({BonsoirDiscovery Function(String type)? discoveryFactory})
    : _discoveryFactory = discoveryFactory ?? _createDiscovery;

  static BonsoirDiscovery _createDiscovery(String type) =>
      BonsoirDiscovery(type: type);

  final BonsoirDiscovery Function(String type) _discoveryFactory;
  static const String remoteServiceType = '_androidtvremote2._tcp';
  static const String castServiceType = '_googlecast._tcp';
  static const String adbServiceType = '_adb._tcp';

  final _devicesController = StreamController<List<DiscoveredTv>>.broadcast();

  final List<BonsoirDiscovery> _discoveries = [];
  final List<StreamSubscription<BonsoirDiscoveryEvent>> _subscriptions = [];

  final Map<String, DiscoveredTv> _primaryDevices = {};
  final Map<String, String> _remoteNameToHost = {};
  final Map<String, Map<String, String>> _castAttributes = {};
  final Set<String> _adbHosts = {};

  bool _isSearching = false;
  int _generation = 0;
  Future<void> _operation = Future.value();

  Stream<List<DiscoveredTv>> get devices => Stream.multi((controller) {
    final subscription = _devicesController.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.add(_snapshot());
    controller.onCancel = subscription.cancel;
  });

  Future<void> start() {
    final generation = _generation;
    final result = _operation.then((_) => _start(generation));
    _operation = result.catchError((Object _) {});
    return result;
  }

  Future<void> _start(int generation) async {
    if (generation != _generation) return;
    if (_isSearching) return;
    _isSearching = true;

    _primaryDevices.clear();
    _remoteNameToHost.clear();
    _castAttributes.clear();
    _adbHosts.clear();
    _emitDevices();

    final serviceTypes = [remoteServiceType, castServiceType, adbServiceType];

    try {
      for (final type in serviceTypes) {
        final discovery = _discoveryFactory(type);
        _discoveries.add(discovery);
        await discovery.initialize();
        if (generation != _generation) {
          await _cleanup();
          return;
        }

        final stream = discovery.eventStream;
        if (stream != null) {
          final sub = stream.listen((event) {
            if (generation == _generation) {
              _handleDiscoveryEvent(type, discovery, event);
            }
          }, onError: (_) {});
          _subscriptions.add(sub);
        }
        await discovery.start();
        if (generation != _generation) {
          await _cleanup();
          return;
        }
      }
    } catch (_) {
      await _cleanup();
      rethrow;
    }
  }

  Future<void> stop() {
    ++_generation;
    final result = _operation.then((_) => _cleanup());
    _operation = result.catchError((Object _) {});
    return result;
  }

  Future<void> restart() async {
    final stopping = stop();
    final generation = _generation;
    await stopping;
    if (generation != _generation) return;
    await start();
  }

  Future<void> _cleanup() async {
    _isSearching = false;

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    for (final discovery in _discoveries) {
      try {
        await discovery.stop();
      } catch (_) {}
    }
    _discoveries.clear();

    _primaryDevices.clear();
    _remoteNameToHost.clear();
    _castAttributes.clear();
    _adbHosts.clear();
    _emitDevices();
  }

  void _handleDiscoveryEvent(
    String serviceType,
    BonsoirDiscovery discovery,
    BonsoirDiscoveryEvent event,
  ) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        event.service.resolve(discovery.serviceResolver);
      case BonsoirDiscoveryServiceResolvedEvent():
        final service = event.service;
        final ip = _extractIp(service);
        if (ip == null || ip.isEmpty) return;

        if (serviceType == remoteServiceType) {
          _remoteNameToHost[service.name] = ip;
          final existing = _primaryDevices[ip];
          final port = service.port > 0 ? service.port : 6466;
          final name = service.name.isNotEmpty
              ? service.name
              : (existing?.name ?? 'Android TV');

          final cast = _castAttributes[ip];
          final hasAdb = _adbHosts.contains(ip) || (existing?.hasAdb ?? false);

          _primaryDevices[ip] = DiscoveredTv(
            name: name,
            host: ip,
            remotePort: port,
            model: cast?['md'] ?? existing?.model,
            friendlyName: cast?['fn'] ?? existing?.friendlyName,
            hasAdb: hasAdb,
          );
          _emitDevices();
        } else if (serviceType == castServiceType) {
          final attrs = Map<String, String>.from(service.attributes);
          _castAttributes[ip] = attrs;

          final existing = _primaryDevices[ip];
          if (existing != null) {
            _primaryDevices[ip] = existing.copyWith(
              model: attrs['md'] ?? existing.model,
              friendlyName: attrs['fn'] ?? existing.friendlyName,
            );
            _emitDevices();
          }
        } else if (serviceType == adbServiceType) {
          _adbHosts.add(ip);
          final existing = _primaryDevices[ip];
          if (existing != null) {
            _primaryDevices[ip] = existing.copyWith(hasAdb: true);
            _emitDevices();
          }
        }
      case BonsoirDiscoveryServiceLostEvent():
        if (serviceType == remoteServiceType) {
          final service = event.service;
          final ip = _extractIp(service);
          String? hostToRemove;
          if (ip != null && _primaryDevices.containsKey(ip)) {
            hostToRemove = ip;
          } else if (_remoteNameToHost.containsKey(service.name)) {
            hostToRemove = _remoteNameToHost[service.name];
          } else {
            hostToRemove = _primaryDevices.entries
                .where((entry) => entry.value.name == service.name)
                .map((entry) => entry.key)
                .firstOrNull;
          }

          if (hostToRemove != null) {
            _primaryDevices.remove(hostToRemove);
            _remoteNameToHost.remove(service.name);
            _emitDevices();
          }
        }
      default:
        break;
    }
  }

  String? _extractIp(BonsoirService service) {
    final addresses = service.hostAddresses;
    if (addresses.isEmpty) return null;
    final ipv4 = addresses.where((a) => !a.contains(':')).firstOrNull;
    return ipv4 ?? addresses.first;
  }

  void _emitDevices() {
    if (!_devicesController.isClosed) {
      _devicesController.add(_snapshot());
    }
  }

  List<DiscoveredTv> _snapshot() =>
      _primaryDevices.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}
