/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../motion.dart';
import '../physics.dart';
import '../theme/app_theme.dart';
import 'remote_models.dart';
import 'widgets/seek_bar.dart';

class NowPlayingSheet extends StatefulWidget {
  const NowPlayingSheet({super.key, required this.playing, required this.onSeekTo, required this.onSeekBy, required this.onButton, required this.onOpenApp});
  final ValueListenable<NowPlaying?> playing;
  final ValueChanged<Duration> onSeekTo, onSeekBy;
  final ValueChanged<RemoteButton> onButton;
  final ValueChanged<String> onOpenApp;

  @override
  State<NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<NowPlayingSheet> {
  Timer? timer;
  bool closing = false;
  @override
  void initState() {
    super.initState();
    widget.playing.addListener(_changed);
    timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (widget.playing.value?.playing ?? false) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant NowPlayingSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) {
      oldWidget.playing.removeListener(_changed);
      widget.playing.addListener(_changed);
    }
  }

  void _changed() {
    if (widget.playing.value == null && !closing) {
      closing = true;
      Navigator.of(context).pop();
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.playing.removeListener(_changed);
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = widget.playing.value;
    if (playing == null) return const SizedBox.shrink();
    return SafeArea(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        SpringIn(child: Text(playing.title, style: context.appTextTheme.titleLarge)),
        if (playing.subtitle?.isNotEmpty ?? false) Text(playing.subtitle!, style: context.appTextTheme.bodyMedium),
        if (playing.appName?.isNotEmpty ?? false) Text(playing.appName!, style: context.appTextTheme.bodyMedium),
        const SizedBox(height: 12),
        SeekBar(playing: playing, position: playing.positionAt(DateTime.now()), onSeekTo: widget.onSeekTo),
        SpringIn(delay: const Duration(milliseconds: 80), child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _SheetPress(child: IconButton(tooltip: 'Previous', onPressed: () => widget.onButton(RemoteButton.previous), icon: const Icon(Icons.skip_previous_rounded))),
            _SheetPress(child: IconButton(tooltip: 'Back 10 seconds', onPressed: () => widget.onSeekBy(const Duration(seconds: -10)), icon: const Icon(Icons.replay_10_rounded))),
            _SheetPress(child: IconButton(tooltip: 'Play-Pause', onPressed: () => widget.onButton(RemoteButton.playPause), icon: Icon(playing.playing ? Icons.pause_rounded : Icons.play_arrow_rounded))),
            _SheetPress(child: IconButton(tooltip: 'Forward 10 seconds', onPressed: () => widget.onSeekBy(const Duration(seconds: 10)), icon: const Icon(Icons.forward_10_rounded))),
            _SheetPress(child: IconButton(tooltip: 'Next', onPressed: () => widget.onButton(RemoteButton.next), icon: const Icon(Icons.skip_next_rounded))),
          ],
        )),
        if (playing.package?.isNotEmpty ?? false)
          FilledButton.tonal(onPressed: () { widget.onOpenApp(playing.package!); Navigator.of(context).pop(); }, child: const Text('Open app')),
      ]),
    ));
  }
}

class _SheetPress extends StatefulWidget {
  const _SheetPress({required this.child});
  final Widget child;
  @override
  State<_SheetPress> createState() => _SheetPressState();
}

class _SheetPressState extends State<_SheetPress> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => pressed = true),
    onPointerUp: (_) => setState(() => pressed = false),
    onPointerCancel: (_) => setState(() => pressed = false),
    child: SpringPress(pressed: pressed && !reduceMotion(context), child: widget.child),
  );
}
