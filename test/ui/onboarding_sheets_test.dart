/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xiaomi_remote/core/discovery/tv_discovery.dart';
import 'package:xiaomi_remote/core/session/pairing_flow.dart';
import 'package:xiaomi_remote/core/session/providers.dart';
import 'package:xiaomi_remote/core/storage/paired_tv_store.dart';
import 'package:xiaomi_remote/ui/onboarding/discover_screen.dart';
import 'package:xiaomi_remote/ui/onboarding/onboarding_flow.dart';
import 'package:xiaomi_remote/ui/onboarding/pair_screen.dart';
import 'package:xiaomi_remote/ui/onboarding/step_dots.dart';
import 'package:xiaomi_remote/ui/onboarding/unlock_screen.dart';
import 'package:xiaomi_remote/ui/sheets/keyboard_sheet.dart';
import 'package:xiaomi_remote/ui/sheets/voice_sheet.dart';
import 'package:xiaomi_remote/ui/theme/app_theme.dart';
import 'package:xiaomi_remote/ui/theme/theme_mode_provider.dart';

class _MemoryStore implements KeyValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _Pairing extends PairingFlow {
  _Pairing(PairedTvStore store) : super(store: store);
  @override
  Future<void> begin(DiscoveredTv tv) async {}
  @override
  Future<PairedTv> complete(String code) async => PairedTv(
    id: 'tv',
    name: 'Living room',
    host: '192.168.1.2',
    certPem: 'cert',
    privateKeyPem: 'key',
    pairedAt: DateTime(2026),
  );
  @override
  Future<void> cancel() async {}
}

void main() {
  testWidgets('Pairing shows Full control and Skip finishes onboarding', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = PairedTvStore(_MemoryStore());
    var finished = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pairedTvStoreProvider.overrideWithValue(store),
          keyValueStoreProvider.overrideWithValue(_MemoryStore()),
          pairingFlowProvider.overrideWithValue(_Pairing(store)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: OnboardingFlow(
            initialTv: const DiscoveredTv(
              name: 'Living room',
              host: '192.168.1.2',
            ),
            onFinished: () => finished = true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Unlock Full control'), findsOneWidget);
    expect(finished, isFalse);
    await tester.tap(find.text('Skip for now'));
    expect(finished, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Discovery times out and can retry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var searches = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveredTvsProvider.overrideWith((ref) {
            searches++;
            return Stream.value([]);
          }),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const OnboardingFlow()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('No TVs found'), findsOneWidget);
    expect(find.text('Searching…'), findsNothing);
    await tester.ensureVisible(find.text('Search again'));
    await tester.tap(find.text('Search again'));
    await tester.pump();
    expect(searches, 2);
    expect(find.text('Searching…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Manual IP dialog validates and cancels safely', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveredTvsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const OnboardingFlow()),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Enter IP address manually'));
    await tester.tap(find.text('Enter IP address manually'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'invalid');
    await tester.tap(find.widgetWithText(FilledButton, 'Pair'));
    await tester.pump();
    expect(find.text('Enter an IP address like 192.168.1.20'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '192.168.1.20');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('StepDots renders correctly without error', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(child: StepDots(current: 2, total: 3)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'DiscoverScreen renders, searches and handles selection and IP entry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      DiscoverItem? selectedItem;
      var ipTapped = false;

      const devices = [
        DiscoverItem(
          id: 'tv-1',
          title: 'Android TV · Mi Box S',
          subtitle: '192.168.0.103',
        ),
        DiscoverItem(
          id: 'tv-2',
          title: 'Bedroom TV · Google TV',
          subtitle: '192.168.0.120',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DiscoverScreen(
              devices: devices,
              searching: true,
              onSelect: (item) => selectedItem = item,
              onEnterIp: () => ipTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Find your TV'), findsOneWidget);
      expect(
        find.text('Make sure your phone and TV are on the same Wi-Fi.'),
        findsOneWidget,
      );
      expect(find.text('Android TV · Mi Box S'), findsOneWidget);
      expect(find.text('192.168.0.103'), findsOneWidget);
      expect(find.text('Bedroom TV · Google TV'), findsOneWidget);
      expect(find.text('Still looking for more TVs…'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap device row
      await tester.tap(find.text('Android TV · Mi Box S'));
      await tester.pump();
      expect(selectedItem, equals(devices[0]));

      await tester.ensureVisible(find.text('Enter IP address manually'));
      await tester.pump();
      await tester.tap(find.text('Enter IP address manually'));
      await tester.pump();
      expect(ipTapped, isTrue);

      // Empty + searching shows only searching row
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DiscoverScreen(
              devices: const [],
              searching: true,
              onSelect: (_) {},
              onEnterIp: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Android TV · Mi Box S'), findsNothing);
      expect(find.text('Searching…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PairScreen: entering "a72a9e" shows "A72A9E", Pair calls onSubmit, error shows and clears, non-hex ignored',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? submittedCode;
      var returnError = false;
      var backTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PairScreen(
              deviceName: 'Mi Box S',
              onSubmit: (code) async {
                submittedCode = code;
                if (returnError) return 'Wrong code';
                return null;
              },
              onBack: () => backTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pair with Mi Box\u00A0S'), findsOneWidget);
      expect(find.text('Enter the code shown on your TV.'), findsOneWidget);
      expect(
        find.text(
          "Can't see a code? Turn on the TV and keep it on the home screen.",
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Non-hex chars are ignored, hex chars are auto-uppercased
      await tester.enterText(find.byType(TextField), 'a72z!a9e');
      await tester.pump();

      // "a72z!a9e" -> only hex characters allowed -> "a72a9e" -> uppercased -> "A72A9E"
      // Verify code boxes display "A", "7", "2", "A", "9", "E"
      expect(find.text('A'), findsNWidgets(2));
      expect(find.text('7'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('E'), findsOneWidget);

      // The sixth character submits automatically.
      expect(submittedCode, equals('A72A9E'));

      // Test error returned from onSubmit
      returnError = true;
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      expect(find.text('Wrong code'), findsOneWidget);
      for (final digit in ['1', '2', '3', '4', '5', '6']) {
        expect(find.text(digit), findsNothing);
      }

      // Test back
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pump();
      expect(backTapped, isTrue);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UnlockScreen renders checklist, status, connecting and skip', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var connectTapped = false;
    var skipTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: UnlockScreen(
            statusText: 'Full control: not connected',
            connecting: false,
            connected: false,
            onConnect: () => connectTapped = true,
            onSkip: () => skipTapped = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Unlock Full control'), findsOneWidget);
    expect(
      find.text('Click Build 7 times to become a developer'),
      findsOneWidget,
    );
    expect(find.text('Full control: not connected'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Connect'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pump();
    expect(connectTapped, isTrue);

    await tester.tap(find.text('Skip for now'));
    await tester.pump();
    expect(skipTapped, isTrue);

    // Connected state
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: UnlockScreen(
            statusText: 'Full control: connected',
            connecting: false,
            connected: true,
            onConnect: () {},
            onSkip: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
    expect(find.text('Full control: connected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KeyboardSheet typing calls onChanged, clear and send work', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var currentText = 'initial';
    var sendTapped = false;
    var clearTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: KeyboardSheet(
            fieldLabel: 'YouTube search',
            initialText: currentText,
            onChanged: (val) => currentText = val,
            onSend: () => sendTapped = true,
            onClear: () => clearTapped = true,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Typing on TV · YouTube search'), findsOneWidget);
    expect(find.text('initial'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Typing calls onChanged
    await tester.enterText(find.byType(TextField), 'bangla natok');
    await tester.pump();
    expect(currentText, equals('bangla natok'));

    // Send button
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(sendTapped, isTrue);

    // Clear button
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(clearTapped, isTrue);
    expect(currentText, equals(''));

    expect(tester.takeException(), isNull);
  });

  testWidgets('VoiceSheet target selection, mic tap and cancel work', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    VoiceTarget currentTarget = VoiceTarget.search;
    var micTapped = false;
    var cancelTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: VoiceSheet(
            listening: false,
            transcript: '',
            target: currentTarget,
            onTargetChanged: (t) => currentTarget = t,
            onMicTap: () => micTapped = true,
            onCancel: () => cancelTapped = true,
            typeIntoFieldAvailable: true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Tap the mic to speak'), findsOneWidget);
    expect(find.text('Search YouTube'), findsOneWidget);
    expect(find.text('Type into field'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tap mic
    await tester.tap(find.bySemanticsLabel('Start listening'));
    await tester.pump();
    expect(micTapped, isTrue);

    // Tap "Type into field" chip
    await tester.tap(find.text('Type into field'));
    await tester.pump();
    expect(currentTarget, equals(VoiceTarget.typeIntoField));

    // Tap cancel
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(cancelTapped, isTrue);

    // Test listening and transcript display
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: VoiceSheet(
            listening: true,
            transcript: 'weather in Dhaka',
            target: VoiceTarget.search,
            onTargetChanged: (_) {},
            onMicTap: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('weather in Dhaka'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
