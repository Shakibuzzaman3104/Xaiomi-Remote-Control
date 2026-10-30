/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/transfer/transfer_page.dart';
import 'transfer_queue.dart';

class ShareIntake extends ConsumerStatefulWidget {
  const ShareIntake({
    super.key,
    required this.navigatorKey,
    required this.child,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  @override
  ConsumerState<ShareIntake> createState() => _ShareIntakeState();
}

class _ShareIntakeState extends ConsumerState<ShareIntake> {
  static const channel = MethodChannel('xr/share');
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'sharedFiles') {
          _receive(call.arguments);
        }
      });
      _takeInitial();
    }
  }

  Future<void> _takeInitial() async {
    try {
      _receive(await channel.invokeMethod<Object?>('takeInitialShare'));
    } on MissingPluginException {
      // Not available on this platform.
    } on PlatformException {
      // The platform could not provide an initial share.
    }
  }

  void _receive(Object? data) {
    if (!mounted || data is! List || data.isEmpty) {
      return;
    }
    final files = <PickedFile>[];
    for (final item in data) {
      if (item is! Map) {
        continue;
      }
      final path = item['path'];
      final name = item['name'];
      final size = item['size'];
      if (path is String && name is String && size is int) {
        files.add(
          PickedFile(
            name: name,
            size: size,
            openRead: () => File(path).openRead(),
          ),
        );
      }
    }
    if (files.isEmpty) {
      return;
    }
    ref.read(transferQueueProvider.notifier).sendFiles(files);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.navigatorKey.currentState?.push(
          MaterialPageRoute<void>(builder: (_) => const TransferPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
