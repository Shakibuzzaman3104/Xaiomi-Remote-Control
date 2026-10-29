/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import 'remote_models.dart';
import 'widgets/device_header.dart';
import 'widgets/now_playing_line.dart';
import 'widgets/mode_switcher.dart';
import 'widgets/dpad.dart';
import 'widgets/swipe_pad.dart';
import 'widgets/trackpad.dart';
import 'widgets/numpad.dart';
import 'widgets/round_action_button.dart';
import 'widgets/volume_pill.dart';
import 'widgets/bottom_action_bar.dart';
import 'widgets/disconnected_banner.dart';

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({
    super.key,
    required this.state,
    this.initialMode = RemoteMode.dpad,
    required this.onButton,
    required this.onSwitchDevice,
    required this.onOpenNowPlaying,
    required this.onApps,
    required this.onKeyboard,
    required this.onVoice,
    required this.onRetry,
    required this.onAppSettings,
    required this.onPointerMove,
    required this.onScroll,
    required this.onClick,
    required this.onAirMouseChanged,
  });
  final RemoteViewState state;
  final RemoteMode initialMode;
  final ValueChanged<RemoteButton> onButton;
  final VoidCallback onSwitchDevice,
      onOpenNowPlaying,
      onApps,
      onKeyboard,
      onVoice,
      onRetry,
      onAppSettings;
  final ValueChanged<Offset> onPointerMove;
  final ValueChanged<double> onScroll;
  final ValueChanged<bool> onClick, onAirMouseChanged;
  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  late RemoteMode mode;
  @override
  void initState() {
    super.initState();
    mode = widget.initialMode;
  }

  static const double _padGap = 28;
  static const double _controlsAroundPad = 180 + _padGap * 2;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              DeviceHeader(
                name: s.deviceName,
                connected: s.connected,
                onSwitchDevice: widget.onSwitchDevice,
                onTvSettings: () => widget.onButton(RemoteButton.settings),
                onAppSettings: widget.onAppSettings,
                onPower: s.connected
                    ? () => widget.onButton(RemoteButton.power)
                    : null,
              ),
              if (!s.connected) ...[
                const SizedBox(height: 8),
                DisconnectedBanner(onRetry: widget.onRetry),
              ],
              if (s.connected && s.nowPlaying != null) ...[
                const SizedBox(height: 10),
                NowPlayingLine(
                  playing: s.nowPlaying!,
                  onTap: widget.onOpenNowPlaying,
                ),
              ],
              const SizedBox(height: 12),
              _whenConnected(
                ModeSwitcher(
                  mode: mode,
                  onChanged: (v) => setState(() => mode = v),
                ),
              ),
              Expanded(
                child: _whenConnected(
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final padSize = _padSizeFor(constraints);
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(child: _buildControls(padSize)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const Divider(height: 12),
              _whenConnected(
                BottomActionBar(
                  onKeyboard: widget.onKeyboard,
                  onVoice: widget.onVoice,
                  onApps: widget.onApps,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  double _padSizeFor(BoxConstraints constraints) {
    final byWidth = (constraints.maxWidth * .9).clamp(0.0, 320.0);
    final byHeight = constraints.maxHeight - _controlsAroundPad;
    return byWidth < byHeight ? byWidth : byHeight.clamp(168.0, byWidth);
  }

  Widget _whenConnected(Widget child) {
    final connected = widget.state.connected;
    return Opacity(
      opacity: connected ? 1 : .4,
      child: IgnorePointer(
        ignoring: !connected,
        child: KeyedSubtree(key: ValueKey(connected), child: child),
      ),
    );
  }

  Widget _buildControls(double padSize) {
    final s = widget.state;
    final playing = s.nowPlaying?.playing ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: _padGap),
        SizedBox(
          width: padSize,
          height: padSize,
          child: switch (mode) {
            RemoteMode.dpad => Dpad(onButton: widget.onButton),
            RemoteMode.swipe => SwipePad(onButton: widget.onButton),
            RemoteMode.mouse => Trackpad(
              onPointerMove: widget.onPointerMove,
              onScroll: widget.onScroll,
              onClick: widget.onClick,
              onAirMouseChanged: widget.onAirMouseChanged,
            ),
            RemoteMode.numpad => Numpad(onButton: widget.onButton),
          },
        ),
        const SizedBox(height: _padGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            RoundActionButton(
              label: 'Back',
              icon: Icons.arrow_back,
              onPressed: () => widget.onButton(RemoteButton.back),
            ),
            RoundActionButton(
              label: 'Home',
              icon: Icons.home_outlined,
              onPressed: () => widget.onButton(RemoteButton.home),
            ),
            RoundActionButton(
              label: playing ? 'Pause' : 'Play',
              icon: playing ? Icons.pause : Icons.play_arrow,
              onPressed: () => widget.onButton(RemoteButton.playPause),
            ),
          ],
        ),
        const SizedBox(height: 8),
        VolumePill(
          level: s.volumeLevel,
          muted: s.muted,
          onButton: widget.onButton,
        ),
      ],
    );
  }
}
