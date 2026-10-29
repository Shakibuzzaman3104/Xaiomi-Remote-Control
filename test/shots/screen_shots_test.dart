/**
 * @author Shakib
 * @since 29/10/26
 */
@Tags(['shots'])
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/ui/apps/app_actions_sheet.dart';
import 'package:xiaomi_remote/ui/apps/apps_screen.dart';
import 'package:xiaomi_remote/ui/onboarding/discover_screen.dart';
import 'package:xiaomi_remote/ui/onboarding/pair_screen.dart';
import 'package:xiaomi_remote/ui/onboarding/unlock_screen.dart';
import 'package:xiaomi_remote/ui/remote/remote_models.dart';
import 'package:xiaomi_remote/ui/remote/remote_screen.dart';
import 'package:xiaomi_remote/ui/settings/settings_view.dart';
import 'package:xiaomi_remote/ui/sheets/keyboard_sheet.dart';
import 'package:xiaomi_remote/ui/sheets/voice_sheet.dart';
import 'package:xiaomi_remote/ui/theme/app_theme.dart';

const _size = Size(412, 915);
const _ratio = 1152 / 412;

Future<void> _loadFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Widget _demoRemote() => RemoteScreen(
  state: const RemoteViewState(
    deviceName: 'Living Room · Mi Box S',
    connected: true,
    reconnecting: false,
    nowPlaying: NowPlaying(
      title: 'Me at the zoo',
      position: Duration(seconds: 12),
      duration: Duration(seconds: 19),
      playing: true,
    ),
    volumeLevel: 12,
    muted: false,
  ),
  onButton: (_) {},
  onSwitchDevice: () {},
  onOpenNowPlaying: () {},
  onApps: () {},
  onKeyboard: () {},
  onVoice: () {},
  onRetry: () {},
  onAppSettings: () {},
  onPointerMove: (_) {},
  onScroll: (_) {},
  onClick: (_) {},
  onAirMouseChanged: (_) {},
);

const _appNames = [
  'YouTube',
  'Netflix',
  'Hoichoi',
  'Toffee',
  'VLC',
  'Plex',
  'Stremio',
  'Hotstar',
  'SonyLIV',
  'Prime Video',
  'Play Store',
  'Settings',
  'Chorki',
  'Smarters',
  'OTT Play',
  'Send files',
];
const _favourites = {
  'YouTube',
  'Netflix',
  'Toffee',
  'Plex',
  'Hotstar',
  'Chorki',
};

List<TvAppItem> _demoApps() => [
  for (final name in _appNames)
    TvAppItem(
      package: 'pkg.${name.toLowerCase()}',
      label: name,
      icon: CircleAvatar(child: Text(name[0])),
      isFavourite: _favourites.contains(name),
    ),
];

Widget _demoAppsScreen() => AppsScreen(
  deviceName: 'Living Room · Mi Box S',
  connected: true,
  onSwitchDevice: () {},
  onTvSettings: () {},
  onAppSettings: () {},
  onBack: () {},
  apps: _demoApps(),
  onOpen: (_) {},
  onShowActions: (_) {},
);

/// Screens rendered at the design canvas size, for side-by-side comparison.
final shots = <String, Widget Function()>{
  'discover': () => DiscoverScreen(
    devices: const [
      DiscoverItem(
        id: '1',
        title: 'Android TV · Mi Box S',
        subtitle: '192.168.0.103',
      ),
      DiscoverItem(
        id: '2',
        title: 'Bedroom TV · Google TV',
        subtitle: '192.168.0.120',
      ),
    ],
    searching: true,
    onSelect: (_) {},
    onEnterIp: () {},
  ),
  'pair': () => PairScreen(
    deviceName: 'Mi Box S',
    onSubmit: (_) async => null,
    onBack: () {},
    onReadAutomatically: () {},
  ),
  'unlock': () => UnlockScreen(
    statusText: 'Full control: not connected',
    connecting: false,
    connected: false,
    onConnect: () {},
    onSkip: () {},
  ),
  'settings': () => SettingsView(
    deviceName: 'Living Room · Mi Box S',
    connected: true,
    onSwitchDevice: () {},
    onTvSettings: () {},
    onAppSettings: () {},
    devices: const [
      SettingsDevice(
        id: '1',
        name: 'Living Room · Mi Box S',
        subtitle: 'Connected',
        isActive: true,
      ),
    ],
    onSelectDevice: (_) {},
    onRemoveDevice: (_) {},
    onAddTv: () {},
    hapticsEnabled: true,
    onHapticsChanged: (_) {},
    volumeKeysEnabled: true,
    onVolumeKeysChanged: (_) {},
    swipeSensitivity: .5,
    onSwipeSensitivityChanged: (_) {},
    micButtonLabel: 'Ask Assistant',
    onMicButtonTap: () {},
    speechLanguageLabel: 'English + বাংলা',
    onSpeechLanguageTap: () {},
    adbConnected: true,
    onNetworkDebuggingTap: () {},
    companionInstalled: false,
    onCompanionTap: () {},
    themeLabel: 'System',
    onThemeTap: () {},
    appVersion: '1.0.0',
    onAboutTap: () {},
  ),
  'apps': _demoAppsScreen,
  'app_actions': () => _WithSheet(
    background: _demoAppsScreen,
    sheet: AppActionsSheet(
      app: _demoApps()[1],
      sizeLabel: '182 MB',
      onOpen: () {},
      onToggleFavourite: () {},
      onForceStop: () {},
      onClearCache: () {},
      onAppInfo: () {},
      onUninstall: () {},
    ),
  ),
  'keyboard': () => _WithSheet(
    sheet: KeyboardSheet(
      fieldLabel: 'YouTube search',
      initialText: 'bangla natok',
      onChanged: (_) {},
      onSend: () {},
      onClear: () {},
      onClose: () {},
    ),
  ),
  'voice': () => _WithSheet(
    sheet: VoiceSheet(
      listening: true,
      transcript: 'weather in Dhaka',
      target: VoiceTarget.search,
      onTargetChanged: (_) {},
      onMicTap: () {},
      onCancel: () {},
    ),
  ),
};

class _WithSheet extends StatefulWidget {
  const _WithSheet({required this.sheet, this.background = _demoRemote});
  final Widget sheet;
  final Widget Function() background;
  @override
  State<_WithSheet> createState() => _WithSheetState();
}

class _WithSheetState extends State<_WithSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        builder: (_) => widget.sheet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.background();
}

void main() {
  setUpAll(_loadFonts);
  for (final dark in [false, true]) {
    for (final entry in shots.entries) {
      final name = '${entry.key}${dark ? '_dark' : ''}';
      testWidgets(name, (tester) async {
        tester.view
          ..physicalSize = _size * _ratio
          ..devicePixelRatio = _ratio;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: entry.value(),
          ),
        );
        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            final image = element.widget as Image;
            await precacheImage(image.image, element);
          }
        });
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
