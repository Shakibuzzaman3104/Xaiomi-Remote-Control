/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../fade_switcher.dart';
import '../motion.dart';
import 'remote_models.dart';
import 'widgets/device_header.dart';
import 'widgets/now_playing_line.dart';
import 'widgets/mode_switcher.dart';
import 'widgets/mouse_unavailable.dart';
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
    this.swipeSensitivity = 0.5,
    required this.onButton,
    this.onExactVolumeChanged,
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
    this.mouseAvailable = true,
  });
  final RemoteViewState state;
  final RemoteMode initialMode;
  final double swipeSensitivity;
  final ValueChanged<RemoteButton> onButton;
  final ValueChanged<int>? onExactVolumeChanged;
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
  final bool mouseAvailable;
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

  static const double _minPadGap = 16;
  static const double _minActionsGap = 12;
  static const double _landscapeGap = 32;
  static const double _minLandscapePad = 120;
  static const double _minActionsWidth = 280;
  static const double _controlsAroundPad =
      160 + _minPadGap * 2 + _minActionsGap * 2;

  @override
  Widget build(BuildContext context) {
    final actionBar = BottomActionBar(
      onKeyboard: widget.onKeyboard,
      onVoice: widget.onVoice,
      onApps: widget.onApps,
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, screen) => _buildBody(screen, actionBar),
        ),
      ),
    );
  }

  Widget _buildBody(BoxConstraints screen, Widget actionBar) {
    final s = widget.state;
    final landscape =
        screen.maxWidth > screen.maxHeight &&
        screen.maxWidth >=
            _minLandscapePad + _landscapeGap + _minActionsWidth + 40;
    final tablet = screen.maxWidth >= 600;
    return Padding(
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
          FadeSwitcher(
            scale: 1,
            slide: const Offset(0, -0.2),
            alignment: Alignment.topCenter,
            child: s.connected
                ? const SizedBox.shrink(key: ValueKey('connected'))
                : Column(
                    key: const ValueKey('disconnected'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      DisconnectedBanner(onRetry: widget.onRetry),
                    ],
                  ),
          ),
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
                  final padSize = landscape
                      ? math
                            .min(
                              math.min(constraints.maxHeight - 16, 360.0),
                              constraints.maxWidth -
                                  _landscapeGap -
                                  _minActionsWidth,
                            )
                            .clamp(_minLandscapePad, 360.0)
                      : _padSizeFor(constraints);
                  if (!landscape) {
                    final controls = _buildControls(padSize);
                    return CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: tablet
                                ? ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 480,
                                    ),
                                    child: controls,
                                  )
                                : controls,
                          ),
                        ),
                      ],
                    );
                  }
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: _buildLandscapeControls(
                          padSize,
                          constraints,
                          actionBar,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (!landscape) ...[
            const Divider(height: 12),
            _whenConnected(actionBar),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  double _padSizeFor(BoxConstraints constraints) {
    final byWidth = (constraints.maxWidth * .9).clamp(0.0, 360.0);
    final byHeight = constraints.maxHeight - _controlsAroundPad;
    return byWidth < byHeight ? byWidth : byHeight.clamp(168.0, byWidth);
  }

  Widget _whenConnected(Widget child) {
    final connected = widget.state.connected;
    return AnimatedOpacity(
      opacity: connected ? 1 : .4,
      duration: AppMotion.standard,
      curve: AppMotion.easeOut,
      child: IgnorePointer(
        ignoring: !connected,
        child: KeyedSubtree(key: ValueKey(connected), child: child),
      ),
    );
  }

  Widget _buildControls(double padSize) {
    final actions = _buildActions();
    return Column(
      children: [
        ..._flexibleGap(_minPadGap, 6),
        _buildPad(padSize),
        ..._flexibleGap(_minPadGap, 5),
        actions.first,
        ..._flexibleGap(_minActionsGap, 3),
        actions.last,
        ..._flexibleGap(_minActionsGap, 5),
      ],
    );
  }

  List<Widget> _flexibleGap(double min, int flex) => [
    SizedBox(height: min),
    Spacer(flex: flex),
  ];

  Widget _buildLandscapeControls(
    double padSize,
    BoxConstraints constraints,
    Widget actionBar,
  ) {
    final actionsWidth = (constraints.maxWidth - padSize - _landscapeGap).clamp(
      _minActionsWidth,
      360.0,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPad(padSize),
        const SizedBox(width: _landscapeGap),
        SizedBox(
          width: actionsWidth,
          height: constraints.maxHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: actionsWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._buildActions(),
                  const SizedBox(height: 12),
                  actionBar,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPad(double padSize) {
    return SizedBox(
      width: padSize,
      height: padSize,
      child: FadeSwitcher(
        scale: 0.98,
        duration: AppMotion.swap,
        expand: true,
        child: KeyedSubtree(key: ValueKey(mode), child: _padFor(mode)),
      ),
    );
  }

  Widget _padFor(RemoteMode mode) {
    return switch (mode) {
      RemoteMode.dpad => Dpad(onButton: widget.onButton),
      RemoteMode.swipe => SwipePad(
        onButton: widget.onButton,
        sensitivity: widget.swipeSensitivity,
      ),
      RemoteMode.mouse when !widget.mouseAvailable => MouseUnavailable(
        onUseSwipe: () => setState(() => mode = RemoteMode.swipe),
      ),
      RemoteMode.mouse => Trackpad(
        onPointerMove: widget.onPointerMove,
        onScroll: widget.onScroll,
        onClick: widget.onClick,
        onAirMouseChanged: widget.onAirMouseChanged,
      ),
      RemoteMode.numpad => Numpad(onButton: widget.onButton),
    };
  }

  List<Widget> _buildActions() {
    final s = widget.state;
    final playing = s.nowPlaying?.playing ?? false;
    return [
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
      VolumePill(
        level: s.volumeLevel,
        exactIndex: s.exactVolume?.index,
        exactMax: s.exactVolume?.max,
        onExactVolumeChanged: widget.onExactVolumeChanged,
        muted: s.muted,
        onButton: widget.onButton,
      ),
    ];
  }
}
