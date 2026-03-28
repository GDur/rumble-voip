import 'package:mocktail/mocktail.dart';
export 'package:mocktail/mocktail.dart';
import 'package:rumble/src/rust/api/client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:rumble/src/rust/mumble/config.dart';
import 'package:rumble/src/rust/mumble/hardware/audio.dart';
import 'package:rumble/services/mumble_service.dart';

class MockRustAudioEngine extends Mock implements RustAudioEngine {}
class MockDeviceLister extends Mock implements DeviceLister {}

Future<void> setupTestDependencies() async {
  // Initialize DotEnv with mock values
  dotenv.loadFromString(envString: 'BRANCH_NAME=TestBranch\nDEBUG_SERVERS=');

  // Register fallback values for mocktail
  registerFallbackValue(const MumbleConfig(
    outgoingAudioBitrate: 0,
    outgoingAudioMsPerPacket: 0,
    incomingJitterBufferMs: 0,
    playbackHwBufferSize: AudioBufferSize.default_(),
    captureHwBufferSize: AudioBufferSize.default_(),
  ));
}
