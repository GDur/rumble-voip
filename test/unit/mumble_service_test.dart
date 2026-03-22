import 'package:flutter_test/flutter_test.dart';
import 'package:rumble/services/mumble_service.dart';

void main() {
  testWidgets('MumbleService initialization', (WidgetTester tester) async {
    // We use testWidgets even for logic because MumbleService creates an AudioRecorder
    // which internally calls MethodChannels. MethodChannels need the test environment.

    final mumbleService = MumbleService();
    expect(mumbleService.isConnected, isFalse);
    expect(mumbleService.isTalking, isFalse);
  });
}
