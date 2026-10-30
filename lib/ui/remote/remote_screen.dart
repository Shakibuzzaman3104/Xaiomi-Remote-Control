/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../fade_switcher.dart';
import '../motion.dart';
import 'expanded_pad_page.dart';
import 'remote_models.dart';
import 'widgets/device_header.dart';
import 'widgets/app_controls.dart';
import 'widgets/mouse_unavailable.dart';
import 'widgets/now_playing_line.dart';
import 'widgets/trackpad.dart';
import 'widgets/mode_switcher.dart';
import 'widgets/dpad.dart';
import 'widgets/swipe_pad.dart';
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
    this.onButtonDown,
    this.onButtonUp,
    this.onModeChanged,
    this.onExactVolumeChanged,
    required this.onSwitchDevice,
    this.onOpenNowPlaying,
    this.onSeekBy,
    this.onAppSearch,
    required this.onApps,
    required this.onKeyboard,
    required this.onVoice,
    required this.onRetry,
    this.onPairAgain,
    required this.onAppSettings,
    required this.onPointerMove,
    required this.onScroll,
    required this.onClick,
    required this.onAirMouseChanged,
    this.onPointerLongPress,
    this.mouseAvailable = true,
    this.mouseSetup,
  });
  final RemoteViewState state;
  final RemoteMode initialMode;
  final double swipeSensitivity;
  final ValueChanged<RemoteButton> onButton;
  final ValueChanged<RemoteButton>? onButtonDown, onButtonUp;
  final ValueChanged<RemoteMode>? onModeChanged;
  final ValueChanged<int>? onExactVolumeChanged;
  final VoidCallback onSwitchDevice,
      onApps,
      onKeyboard,
      onVoice,
      onRetry,
      onAppSettings;
  final VoidCallback? onPairAgain, onOpenNowPlaying;
  final ValueChanged<Duration>? onSeekBy;
  final VoidCallback? onAppSearch;
  final ValueChanged<Offset> onPointerMove;
  final ValueChanged<double> onScroll;
  final ValueChanged<bool> onClick, onAirMouseChanged;
  final VoidCallback? onPointerLongPress;
  final bool mouseAvailable;
  final MouseSetupPrompt? mouseSetup;
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

  @override
  void didUpdateWidget(covariant RemoteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode) mode = widget.initialMode;
  }

  static const double _minPadGap = 16;
  static const double _minActionsGap = 12;
  static const double _landscapeGap = 32;
  static const double _minLandscapePad = 120;
  static const double _minActionsWidth = 280;
  static const double _controlsAroundPad = 160 + 32 * 2 + 20 * 2;

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
            retrying: s.reconnecting,
            offlineLabel: s.needsPairing
                ? 'Not paired'
                : s.reconnecting
                ? 'Reconnecting…'
                : 'Offline',
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
            child: s.connected || (s.reconnecting && s.attempt < 2)
                ? const SizedBox.shrink(key: ValueKey('connected'))
                : Column(
                    key: const ValueKey('disconnected'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      DisconnectedBanner(
                        onRetry: widget.onRetry,
                        onPairAgain: s.needsPairing ? widget.onPairAgain : null,
                      ),
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
          FadeSwitcher(
            scale: 1,
            alignment: Alignment.topCenter,
            child: s.connected && s.appControls != null
                ? AppControls(
                    key: ValueKey(s.appControls!.package),
                    data: s.appControls!,
                    onSeekBy: widget.onSeekBy ?? (_) {},
                    onButton: widget.onButton,
                    onSearch: widget.onAppSearch ?? widget.onKeyboard,
                  )
                : const SizedBox.shrink(key: ValueKey('no-app-controls')),
          ),
          const SizedBox(height: 12),
          _whenConnected(ModeSwitcher(mode: mode, onChanged: _changeMode)),
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
                      physics:
                          mode == RemoteMode.swipe || mode == RemoteMode.mouse
                          ? const NeverScrollableScrollPhysics()
                          : null,
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
                    physics:
                        mode == RemoteMode.swipe || mode == RemoteMode.mouse
                        ? const NeverScrollableScrollPhysics()
                        : null,
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
            const SizedBox(height: 12),
            _whenConnected(actionBar),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  double _padSizeFor(BoxConstraints constraints) {
    final byWidth = (constraints.maxWidth * .9).clamp(0.0, 360.0);
    final byHeight =
        constraints.maxHeight -
        _controlsAroundPad *
            MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return byWidth < byHeight ? byWidth : byHeight.clamp(168.0, byWidth);
  }

  Widget _whenConnected(Widget child) {
    final connected = widget.state.connected;
    return AnimatedOpacity(
      opacity: connected ? 1 : .4,
      duration: AppMotion.standard,
      curve: AppMotion.easeOut,
      child: ExcludeSemantics(
        excluding: !connected,
        child: IgnorePointer(
          ignoring: !connected,
          child: KeyedSubtree(key: ValueKey(connected), child: child),
        ),
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
      RemoteMode.dpad => Dpad(
        onButton: widget.onButton,
        onButtonDown: widget.onButtonDown,
        onButtonUp: widget.onButtonUp,
      ),
      RemoteMode.swipe => SwipePad(
        onButton: widget.onButton,
        onButtonDown: widget.onButtonDown,
        onButtonUp: widget.onButtonUp,
        sensitivity: widget.swipeSensitivity,
        onExpand: (rect) => _expandPad(RemoteMode.swipe, rect),
      ),
      RemoteMode.mouse when !widget.mouseAvailable => MouseUnavailable(
        prompt:
            widget.mouseSetup ??
            const MouseSetupPrompt(
              title: 'Mouse needs Full control',
              message: 'Turn on Full control in Settings to use a pointer on the TV.',
            ),
        onUseSwipe: () => _changeMode(RemoteMode.swipe),
      ),
      RemoteMode.mouse => Trackpad(
        onPointerMove: widget.onPointerMove,
        onScroll: widget.onScroll,
        onClick: widget.onClick,
        onAirMouseChanged: widget.onAirMouseChanged,
        onLongPress: widget.onPointerLongPress,
        onExpand: (rect) => _expandPad(RemoteMode.mouse, rect),
      ),
      RemoteMode.numpad => Numpad(onButton: widget.onButton),
    };
  }

  void _expandPad(RemoteMode mode, Rect origin) {
    Navigator.of(context).push(
      ExpandedPadPage.route(
        mode: mode,
        origin: origin,
        onButton: widget.onButton,
        onButtonDown: widget.onButtonDown,
        onButtonUp: widget.onButtonUp,
        onPointerMove: widget.onPointerMove,
        onScroll: widget.onScroll,
        onClick: widget.onClick,
        onPointerLongPress: widget.onPointerLongPress,
        sensitivity: widget.swipeSensitivity,
      ),
    );
  }

  void _changeMode(RemoteMode value) {
    setState(() => mode = value);
    widget.onModeChanged?.call(value);
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
            icon: Icons.arrow_back_rounded,
            onPressed: () => widget.onButton(RemoteButton.back),
            onLongDown: widget.onButtonDown == null
                ? null
                : () => widget.onButtonDown!(RemoteButton.back),
            onLongUp: widget.onButtonUp == null
                ? null
                : () => widget.onButtonUp!(RemoteButton.back),
          ),
          RoundActionButton(
            label: 'Home',
            icon: Icons.home_outlined,
            onPressed: () => widget.onButton(RemoteButton.home),
            onLongDown: widget.onButtonDown == null
                ? null
                : () => widget.onButtonDown!(RemoteButton.home),
            onLongUp: widget.onButtonUp == null
                ? null
                : () => widget.onButtonUp!(RemoteButton.home),
          ),
          RoundActionButton(
            label: playing ? 'Pause' : 'Play',
            icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
