/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';
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
  bool _timedOut = false;
  Timer? _discoveryTimer;

  @override
  void initState() {
    super.initState();
    _startDiscoveryTimer();
  }

  void _startDiscoveryTimer() {
    _discoveryTimer?.cancel();
    _timedOut = false;
    _discoveryTimer = Timer(const Duration(seconds: 10), () {
      if (mounted &&
          (ref.read(discoveredTvsProvider).asData?.value.isEmpty ?? true)) {
        setState(() => _timedOut = true);
      }
    });
  }

  void _retryDiscovery() {
    ref.invalidate(discoveredTvsProvider);
    setState(_startDiscoveryTimer);
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    super.dispose();
  }

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
    final host = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualIpDialog(),
    );
    if (!mounted || host == null) return;
    await _startPairing(DiscoveredTv(name: 'Android TV', host: host));
  }

  void _backToDiscovery() {
    ref.read(pairingFlowProvider).cancel();
    setState(() {
      _startDiscoveryTimer();
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
      timedOut: _timedOut,
      errorText: discovered.hasError
          ? "Couldn't search the network. Check Wi-Fi and try again."
          : null,
      onRetry: _retryDiscovery,
      onClose:
          widget.onCancel ??
          (Navigator.of(context).canPop()
              ? () => Navigator.of(context).pop()
              : null),
      onSelect: (item) =>
          _startPairing(devices.firstWhere((d) => d.host == item.id)),
      onEnterIp: _enterIpManually,
    );
  }
}

class _ManualIpDialog extends StatefulWidget {
  const _ManualIpDialog();

  @override
  State<_ManualIpDialog> createState() => _ManualIpDialogState();
}

class _ManualIpDialogState extends State<_ManualIpDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final ip = _controller.text.trim();
    if (InternetAddress.tryParse(ip) == null) {
      setState(() => _error = 'Enter an IP address like 192.168.1.20');
      return;
    }
    Navigator.of(context).pop(ip);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('TV IP address'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(hintText: '192.168.1.20', errorText: _error),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Pair')),
    ],
  );
}
