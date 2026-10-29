/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/session/providers.dart';
import '../../core/adb/full_control.dart';
import '../../core/session/tv_session.dart';
import '../../core/settings/app_preferences.dart';
import '../motion.dart';
import '../sheets/keyboard_sheet.dart';
import '../sheets/voice_sheet.dart';
import 'connected_remote_page.dart';
import 'remote_models.dart';

/// Remote screen plus the keyboard and voice sheets it opens.
class RemoteHome extends ConsumerStatefulWidget {
  const RemoteHome({
    super.key,
    required this.onAddTv,
    required this.onAppSettings,
    this.onPairAgain,
  });
  final VoidCallback onAddTv, onAppSettings;
  final VoidCallback? onPairAgain;

  @override
  ConsumerState<RemoteHome> createState() => _RemoteHomeState();
}

class _RemoteHomeState extends ConsumerState<RemoteHome> {
  bool _keyboardOpen = false;
  bool _volumeHandlerRegistered = false;
  final _hardwareVolume = ValueNotifier<RemoteButton?>(null);

  void _syncVolumeHandler(bool enabled) {
    if (enabled == _volumeHandlerRegistered) return;
    _volumeHandlerRegistered = enabled;
    if (enabled) {
      HardwareKeyboard.instance.addHandler(_handleVolumeKey);
    } else {
      HardwareKeyboard.instance.removeHandler(_handleVolumeKey);
    }
  }

  bool _handleVolumeKey(KeyEvent event) {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final button = switch (event.logicalKey) {
      LogicalKeyboardKey.audioVolumeUp => RemoteButton.volumeUp,
      LogicalKeyboardKey.audioVolumeDown => RemoteButton.volumeDown,
      LogicalKeyboardKey.audioVolumeMute => RemoteButton.mute,
      _ => null,
    };
    if (button == null) return false;
    _session?.press(button);
    _hardwareVolume.value = null;
    _hardwareVolume.value = button;
    return true;
  }

  @override
  void dispose() {
    _syncVolumeHandler(false);
    _hardwareVolume.dispose();
    super.dispose();
  }

  TvSession? get _session => ref.read(tvSessionProvider);

  void _sendFieldText(String text) => _session?.sendText(text);

  Future<void> showKeyboard() async {
    if (_keyboardOpen) return;
    _keyboardOpen = true;
    final atv = ref.read(tvSessionStateProvider).asData?.value.atv;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: sheetAnimation(context),
      showDragHandle: false,
      builder: (sheetContext) => KeyboardSheet(
        fieldLabel: atv?.imeLabel ?? '',
        initialText: atv?.imeValue ?? '',
        imeActive: atv?.imeActive ?? false,
        onChanged: (text) {
          if (atv?.imeActive ?? false) _sendFieldText(text);
        },
        onClear: () {},
        onSend: () {
          if (atv?.imeActive ?? false) _session?.submitText();
          Navigator.of(sheetContext).pop();
        },
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    );
    _keyboardOpen = false;
  }

  Future<void> showVoice() async {
    final prefs = ref.read(appPreferencesProvider);
    final imeActive =
        ref.read(tvSessionStateProvider).asData?.value.atv.imeActive ?? false;
    final query = await showModalBottomSheet<_VoiceResult>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: sheetAnimation(context),
      showDragHandle: false,
      builder: (_) => _VoiceSheetHost(
        typeIntoFieldAvailable: imeActive,
        defaultTarget: prefs.micButton,
        speechLocale: prefs.speechLocale,
        tvSearchAvailable:
            ref.read(fullControlProvider).status == FullControlStatus.connected,
      ),
    );
    final session = _session;
    if (query == null || query.text.isEmpty || session == null) return;
    if (query.target == VoiceTarget.typeIntoField) {
      session
        ..sendText(query.text)
        ..submitText();
    } else if (query.target == VoiceTarget.searchTv) {
      await ref.read(fullControlProvider.notifier).globalSearch(query.text);
    } else {
      session.launchLink(
        'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(query.text)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncVolumeHandler(ref.watch(appPreferencesProvider).volumeKeysControlTv);
    ref.listen(tvSessionStateProvider, (previous, next) {
      final was = previous?.asData?.value.atv.imeActive ?? false;
      final now = next.asData?.value.atv.imeActive ?? false;
      if (!was && now) unawaited(showKeyboard());
    });
    return ConnectedRemotePage(
      onSwitchDevice: widget.onAddTv,
      onAppSettings: widget.onAppSettings,
      onKeyboard: showKeyboard,
      onVoice: showVoice,
      onPairAgain: widget.onPairAgain,
      hardwareVolume: _hardwareVolume,
    );
  }
}

class _VoiceResult {
  const _VoiceResult(this.text, this.target);
  final String text;
  final VoiceTarget target;
}

class _VoiceSheetHost extends StatefulWidget {
  const _VoiceSheetHost({
    required this.typeIntoFieldAvailable,
    required this.defaultTarget,
    required this.speechLocale,
    required this.tvSearchAvailable,
  });
  final bool typeIntoFieldAvailable;
  final VoiceTargetPreference defaultTarget;
  final String speechLocale;
  final bool tvSearchAvailable;

  @override
  State<_VoiceSheetHost> createState() => _VoiceSheetHostState();
}

class _VoiceSheetHostState extends State<_VoiceSheetHost> {
  final _speech = SpeechToText();
  late VoiceTarget _target =
      widget.typeIntoFieldAvailable &&
          widget.defaultTarget == VoiceTargetPreference.typeIntoField
      ? VoiceTarget.typeIntoField
      : VoiceTarget.search;
  String _transcript = '';
  bool _listening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_startListening());
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() => _error = null);
    final ready = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == SpeechToText.doneStatus && _transcript.isNotEmpty) {
          Navigator.of(context).pop(_VoiceResult(_transcript, _target));
        }
        setState(() => _listening = status == SpeechToText.listeningStatus);
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _listening = false;
            _error = error.errorMsg.contains('permission')
                ? 'Microphone or speech permission is off. Turn it on in Settings to use voice.'
                : "Couldn't hear that. Tap the mic to try again.";
          });
        }
      },
    );
    if (!mounted) return;
    if (!ready) {
      setState(
        () => _error = 'Microphone or speech permission is off. Turn it on in Settings to use voice.',
      );
      return;
    }
    await _speech.listen(
      onResult: (result) {
        if (mounted) setState(() => _transcript = result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        localeId: widget.speechLocale,
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
    } else {
      await _startListening();
    }
  }

  @override
  Widget build(BuildContext context) => VoiceSheet(
    listening: _listening,
    transcript: _transcript,
    target: _target,
    typeIntoFieldAvailable: widget.typeIntoFieldAvailable,
    tvSearchAvailable: widget.tvSearchAvailable,
    errorText: _error,
    onTargetChanged: (target) => setState(() => _target = target),
    onMicTap: _toggleListening,
    onCancel: () => Navigator.of(context).pop(),
  );
}
