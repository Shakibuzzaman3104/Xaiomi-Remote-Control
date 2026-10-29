/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaomi_remote/main.dart';
void main() { testWidgets('shows the remote', (tester) async { await tester.pumpWidget(const XiaomiRemoteApp()); expect(find.text('Living Room · Mi Box S'), findsOneWidget); }); }
