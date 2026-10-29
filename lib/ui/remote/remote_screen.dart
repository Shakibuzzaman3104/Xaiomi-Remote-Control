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
import 'widgets/media_row.dart';
import 'widgets/favourite_apps_row.dart';
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
    required this.onOpenApp,
    required this.onEditFavourites,
    required this.onKeyboard,
    required this.onVoice,
    required this.onRetry,
    required this.onMenu,
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
      onEditFavourites,
      onKeyboard,
      onVoice,
      onRetry,
      onMenu;
  final ValueChanged<FavouriteApp> onOpenApp;
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

  static const double _controlsAroundPad = 408;

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
                onMenu: widget.onMenu,
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
              Expanded(
                child: _whenConnected(
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final padSize = _padSizeFor(constraints);
                      return SingleChildScrollView(
                        child: _buildControls(padSize),
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
                  onPower: () => widget.onButton(RemoteButton.power),
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
    final byWidth = (constraints.maxWidth * .82).clamp(0.0, 264.0);
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
    return Column(
      children: [
        ModeSwitcher(mode: mode, onChanged: (v) => setState(() => mode = v)),
        const SizedBox(height: 12),
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
        const SizedBox(height: 10),
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
              label: 'Settings',
              icon: Icons.settings_outlined,
              onPressed: () => widget.onButton(RemoteButton.settings),
            ),
          ],
        ),
        const SizedBox(height: 8),
        VolumePill(
          level: s.volumeLevel,
          muted: s.muted,
          onButton: widget.onButton,
        ),
        const SizedBox(height: 6),
        MediaRow(
          playing: s.nowPlaying?.playing ?? false,
          onButton: widget.onButton,
        ),
        FavouriteAppsRow(
          apps: s.favourites,
          onOpen: widget.onOpenApp,
          onEdit: widget.onEditFavourites,
        ),
      ],
    );
  }
}
