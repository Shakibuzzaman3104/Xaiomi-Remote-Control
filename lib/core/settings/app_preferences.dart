/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/theme/theme_mode_provider.dart';

enum VoiceTargetPreference { askAssistant, typeIntoField }

class AppPreferences {
  const AppPreferences({
    this.haptics = true,
    this.volumeKeysControlTv = true,
    this.swipeSensitivity = 0.5,
    this.micButton = VoiceTargetPreference.askAssistant,
    this.speechLocale = 'en_US',
  });

  final bool haptics;
  final bool volumeKeysControlTv;
  final double swipeSensitivity;
  final VoiceTargetPreference micButton;
  final String speechLocale;

  AppPreferences copyWith({
    bool? haptics,
    bool? volumeKeysControlTv,
    double? swipeSensitivity,
    VoiceTargetPreference? micButton,
    String? speechLocale,
  }) => AppPreferences(
    haptics: haptics ?? this.haptics,
    volumeKeysControlTv: volumeKeysControlTv ?? this.volumeKeysControlTv,
    swipeSensitivity: swipeSensitivity ?? this.swipeSensitivity,
    micButton: micButton ?? this.micButton,
    speechLocale: speechLocale ?? this.speechLocale,
  );

  Map<String, dynamic> toJson() => {
    'haptics': haptics,
    'volumeKeysControlTv': volumeKeysControlTv,
    'swipeSensitivity': swipeSensitivity,
    'micButton': micButton.name,
    'speechLocale': speechLocale,
  };

  factory AppPreferences.fromJson(Map<String, dynamic> json) => AppPreferences(
    haptics: json['haptics'] is bool ? json['haptics'] as bool : true,
    volumeKeysControlTv: json['volumeKeysControlTv'] is bool
        ? json['volumeKeysControlTv'] as bool
        : true,
    swipeSensitivity: json['swipeSensitivity'] is num
        ? (json['swipeSensitivity'] as num).toDouble().clamp(0.0, 1.0)
        : 0.5,
    micButton:
        VoiceTargetPreference.values
            .where((v) => v.name == json['micButton'])
            .firstOrNull ??
        VoiceTargetPreference.askAssistant,
    speechLocale: json['speechLocale'] is String
        ? json['speechLocale'] as String
        : 'en_US',
  );
}

class AppPreferencesNotifier extends Notifier<AppPreferences> {
  static const _key = 'app_preferences';
  int _revision = 0;
  Future<void> _writes = Future.value();

  @override
  AppPreferences build() {
    _load();
    return const AppPreferences();
  }

  Future<void> _load() async {
    final revision = _revision;
    try {
      final raw = await ref.read(keyValueStoreProvider).read(_key);
      if (raw != null && revision == _revision && ref.mounted) {
        state = AppPreferences.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Keep defaults if stored preferences cannot be read.
    }
  }

  Future<void> _update(AppPreferences value) {
    _revision++;
    state = value;
    final store = ref.read(keyValueStoreProvider);
    final encoded = jsonEncode(value.toJson());
    _writes = _writes
        .catchError((Object _) {})
        .then((_) => store.write(_key, encoded));
    return _writes;
  }

  Future<void> setHaptics(bool value) =>
      _update(state.copyWith(haptics: value));
  Future<void> setVolumeKeysControlTv(bool value) =>
      _update(state.copyWith(volumeKeysControlTv: value));
  Future<void> setSwipeSensitivity(double value) =>
      _update(state.copyWith(swipeSensitivity: value.clamp(0.0, 1.0)));
  Future<void> setMicButton(VoiceTargetPreference value) =>
      _update(state.copyWith(micButton: value));
  Future<void> setSpeechLocale(String value) =>
      _update(state.copyWith(speechLocale: value));
}

final appPreferencesProvider =
    NotifierProvider<AppPreferencesNotifier, AppPreferences>(
      AppPreferencesNotifier.new,
    );
