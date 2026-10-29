/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_preferences.dart';
import '../haptics.dart';

class PreferencesSync extends ConsumerWidget {
  const PreferencesSync({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppHaptics.enabled = ref.watch(appPreferencesProvider).haptics;
    return child;
  }
}
