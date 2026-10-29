/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/discovery/tv_discovery.dart';
import '../../core/session/providers.dart';
import 'discover_screen.dart';
import 'pair_screen.dart';

/// Finds a TV on the network and pairs with it.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key, this.onCancel});
  final VoidCallback? onCancel;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  DiscoveredTv? _pairingTv;
  String? _startError;
  bool _starting = false;

  Future<void> _startPairing(DiscoveredTv tv) async {
    setState(() {
      _pairingTv = tv;
      _starting = true;
      _startError = null;
    });
    try {
      await ref.read(pairingFlowProvider).begin(tv);
    } catch (error) {
      if (mounted) setState(() => _startError = _describe(error));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<String?> _submitCode(String code) async {
    if (_startError != null) return _startError;
    try {
      final paired = await ref.read(pairingFlowProvider).complete(code);
      await ref.read(pairedTvsProvider.notifier).add(paired);
      return null;
    } catch (error) {
      return _describe(error);
    }
  }

  String _describe(Object error) => switch (error) {
    SocketException() => "Couldn't reach the TV. Check it's on the same Wi-Fi.",
    HandshakeException() => 'The TV refused the connection. Try again.',
    _ => 'That code didn\'t work. Check the code on the TV and try again.',
  };

  Future<void> _enterIpManually() async {
    final controller = TextEditingController();
    final host = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('TV IP address'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '192.168.0.103'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    final ip = host?.trim();
    if (ip == null || InternetAddress.tryParse(ip) == null) return;
    await _startPairing(DiscoveredTv(name: 'Android TV', host: ip));
  }

  void _backToDiscovery() {
    ref.read(pairingFlowProvider).cancel();
    setState(() {
      _pairingTv = null;
      _startError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tv = _pairingTv;
    if (tv != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _backToDiscovery();
        },
        child: PairScreen(
          deviceName: tv.model ?? tv.friendlyName ?? tv.name,
          busy: _starting,
          onSubmit: _submitCode,
          onBack: _backToDiscovery,
        ),
      );
    }
    final discovered = ref.watch(discoveredTvsProvider);
    final devices = discovered.asData?.value ?? const <DiscoveredTv>[];
    return DiscoverScreen(
      devices: [
        for (final device in devices)
          DiscoverItem(
            id: device.host,
            title: [
              device.friendlyName ?? device.name,
              ?device.model,
            ].join(' · '),
            subtitle: device.host,
          ),
      ],
      searching: !discovered.hasError,
      onSelect: (item) =>
          _startPairing(devices.firstWhere((d) => d.host == item.id)),
      onEnterIp: _enterIpManually,
    );
  }
}
