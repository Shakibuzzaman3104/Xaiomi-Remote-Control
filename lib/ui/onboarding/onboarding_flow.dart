/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adb/full_control.dart';
import '../../core/discovery/tv_discovery.dart';
import '../../core/remote/atv_pairing.dart';
import '../../core/session/pairing_flow.dart';
import '../../core/session/providers.dart';
import '../fade_switcher.dart';
import '../motion.dart';
import 'discover_screen.dart';
import 'pair_screen.dart';
import 'unlock_screen.dart';

/// Finds a TV on the network and pairs with it.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({
    super.key,
    this.onCancel,
    this.onFinished,
    this.initialTv,
  });
  final VoidCallback? onCancel;
  final VoidCallback? onFinished;
  final DiscoveredTv? initialTv;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  static const _successHold = Duration(milliseconds: 900);
  static const _successHoldReduced = Duration(milliseconds: 400);

  late final PairingFlow _pairingFlow;
  DiscoveredTv? _pairingTv;
  String? _startError;
  bool _starting = false;
  bool _timedOut = false;
  bool _paired = false;
  bool _showUnlock = false;
  Timer? _discoveryTimer;

  @override
  void initState() {
    super.initState();
    _pairingFlow = ref.read(pairingFlowProvider);
    if (widget.initialTv != null) {
      Future.microtask(() {
        if (mounted) _startPairing(widget.initialTv!);
      });
    } else {
      _startDiscoveryTimer();
    }
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
    unawaited(ref.read(tvDiscoveryProvider).restart().catchError((_) {}));
    ref.invalidate(discoveredTvsProvider);
    setState(_startDiscoveryTimer);
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    unawaited(_pairingFlow.cancel());
    super.dispose();
  }

  Future<void> _startPairing(DiscoveredTv tv) async {
    setState(() {
      _pairingTv = tv;
      _starting = true;
      _startError = null;
    });
    try {
      await _pairingFlow.begin(tv);
    } catch (error) {
      if (mounted && _pairingTv == tv) {
        setState(() => _startError = _describe(error));
      }
    } finally {
      if (mounted && _pairingTv == tv) setState(() => _starting = false);
    }
  }

  Future<String?> _submitCode(String code) async {
    if (_startError != null) {
      final tv = _pairingTv;
      if (tv != null) await _startPairing(tv);
      return _startError ?? 'The code expired. Get a new one.';
    }
    try {
      final tv = _pairingTv;
      final paired = await _pairingFlow.complete(code);
      if (!mounted) return null;
      setState(() => _paired = true);
      await Future<void>.delayed(
        reduceMotion(context) ? _successHoldReduced : _successHold,
      );
      if (!mounted || _pairingTv != tv) return null;
      await ref.read(pairedTvsProvider.notifier).add(paired);
      if (mounted) setState(() => _showUnlock = true);
      return null;
    } catch (error) {
      if (mounted) setState(() => _paired = false);
      return _describe(error);
    }
  }

  String _describe(Object error) => switch (error) {
    AtvPairingException(kind: PairingFailureKind.wrongCode) =>
      "That code didn't work. Check the TV and try again.",
    AtvPairingException(kind: PairingFailureKind.expired) =>
      'The code expired. Get a new one.',
    _ => "Couldn't reach the TV. Check it's on and on the same Wi-Fi.",
  };

  Future<void> _enterIpManually() async {
    final host = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualIpDialog(),
    );
    if (!mounted || host == null) return;
    final devices =
        ref.read(discoveredTvsProvider).asData?.value ?? const <DiscoveredTv>[];
    final matching = devices.where((device) => device.host == host);
    await _startPairing(
      matching.isNotEmpty
          ? matching.first
          : DiscoveredTv(name: host, host: host),
    );
  }

  void _backToDiscovery() {
    if (widget.initialTv != null) {
      widget.onCancel?.call();
      return;
    }
    _pairingFlow.cancel();
    setState(() {
      _startDiscoveryTimer();
      _pairingTv = null;
      _startError = null;
      _paired = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tv = _pairingTv;
    return FadeSwitcher(
      scale: 1,
      expand: true,
      child: _showUnlock
          ? _buildUnlock()
          : tv != null
          ? _buildPair(tv)
          : _buildDiscover(),
    );
  }

  Widget _buildUnlock() {
    final control = ref.watch(fullControlProvider);
    final status = control.status;
    final connected = status == FullControlStatus.connected;
    final statusText = switch (status) {
      FullControlStatus.off => 'Full control: not connected',
      FullControlStatus.connecting => 'Connecting…',
      FullControlStatus.waitingForApproval => 'Choose Allow on the TV',
      FullControlStatus.connected => 'Full control: connected',
      FullControlStatus.failed =>
        control.error ?? 'Full control connection failed',
    };
    return PopScope(
      key: const ValueKey('unlock'),
      canPop: false,
      child: UnlockScreen(
        statusText: statusText,
        connecting:
            status == FullControlStatus.connecting ||
            status == FullControlStatus.waitingForApproval,
        connected: connected,
        onConnect: connected
            ? _finish
            : () => ref.read(fullControlProvider.notifier).connect(),
        onSkip: _finish,
      ),
    );
  }

  void _finish() => widget.onFinished?.call();

  Widget _buildPair(DiscoveredTv tv) {
    return PopScope(
      key: const ValueKey('pair'),
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToDiscovery();
      },
      child: PairScreen(
        deviceName: tv.model ?? tv.friendlyName ?? tv.name,
        busy: _starting,
        startError: _startError,
        onRetryStart: () => _startPairing(tv),
        success: _paired,
        onSubmit: _submitCode,
        onBack: _backToDiscovery,
      ),
    );
  }

  Widget _buildDiscover() {
    final discovered = ref.watch(discoveredTvsProvider);
    final devices = discovered.asData?.value ?? const <DiscoveredTv>[];
    return DiscoverScreen(
      key: const ValueKey('discover'),
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
    if (InternetAddress.tryParse(ip)?.type != InternetAddressType.IPv4) {
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: '192.168.1.20',
        helperText: 'On the TV: Settings › Device Preferences › About › Status › IP address',
        helperMaxLines: 3,
        errorText: _error,
      ),
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
