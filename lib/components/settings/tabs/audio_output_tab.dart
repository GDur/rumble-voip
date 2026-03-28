import 'package:flutter/material.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/src/rust/mumble/hardware/audio.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

// Component: audio-output-tab
class AudioOutputTab extends StatelessWidget {
  final SettingsService settings;
  final MumbleService mumbleService;
  final StateSetter onUpdate;

  const AudioOutputTab({
    super.key,
    required this.settings,
    required this.mumbleService,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio Output',
            style: theme.textTheme.large.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Output Device',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: mumbleService,
            builder: (context, _) {
              final devices = mumbleService.outputDevices;
              final playbackDeviceId = settings.playbackDeviceId;
              final hasCurrent =
                  playbackDeviceId == null ||
                  devices.any((d) => d.id == playbackDeviceId);

              return ShadSelect<String?>(
                placeholder: const Text('Default Output'),
                initialValue: playbackDeviceId,
                onChanged: (value) async {
                  settings.setPlaybackDeviceId(value);
                  await mumbleService.updateAudioSettings(
                    playbackDeviceId: value,
                  );
                  onUpdate(() {});
                },
                options: [
                  const ShadOption<String?>(
                    value: null,
                    child: Text('Default Output'),
                  ),
                  if (!hasCurrent)
                    ShadOption<String?>(
                      value: playbackDeviceId,
                      child: const Text('Current Device'),
                    ),
                  ...devices.map(
                    (d) => ShadOption<String?>(value: d.id, child: Text(d.name)),
                  ),
                ],
                selectedOptionBuilder: (context, value) {
                  if (value == null) return const Text('Default Output');
                  final device = devices.cast<AudioDevice?>().firstWhere(
                    (d) => d?.id == value,
                    orElse: () => null,
                  );
                  return Text(device?.name ?? value);
                },
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Output Volume',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ShadSlider(
                    initialValue: settings.outputVolume,
                    min: 0.0,
                    max: 1.5,
                    thumbRadius: 10,
                    onChanged: (v) {
                      settings.setOutputVolume(v);
                      mumbleService.updateAudioSettings(outputVolume: v);
                      onUpdate(() {});
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: Text(
                  '${(settings.outputVolume * 100).round()}%',
                  style: theme.textTheme.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Show volume indicator',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ShadSwitch(
                value: settings.showVolumeIndicator,
                onChanged: (v) {
                  settings.setShowVolumeIndicator(v);
                  onUpdate(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Jitter Buffer',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ShadSlider(
                    initialValue: settings.incomingJitterBufferMs.toDouble(),
                    min: 0.0,
                    max: 500.0,
                    divisions: 50,
                    thumbRadius: 10,
                    onChanged: (v) {
                      final ms = v.round();
                      settings.setIncomingJitterBufferMs(ms);
                      mumbleService.updateAudioSettings(
                        incomingJitterBufferMs: ms,
                      );
                      onUpdate(() {});
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: Text(
                  '${settings.incomingJitterBufferMs} ms',
                  style: theme.textTheme.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Output Delay (Hardware Buffer)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ShadSlider(
                    initialValue: settings.playbackHwBufferMs.toDouble(),
                    min: 0.0,
                    max: 100.0,
                    divisions: 20,
                    thumbRadius: 10,
                    onChanged: (v) {
                      final ms = v.round();
                      settings.setPlaybackHwBufferMs(ms);
                      mumbleService.updateAudioSettings(
                        playbackHwBufferMs: ms,
                      );
                      onUpdate(() {});
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: Text(
                  settings.playbackHwBufferMs == 0
                      ? 'Default'
                      : '${settings.playbackHwBufferMs} ms',
                  style: theme.textTheme.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Increase if audio is choppy/crackly. 0 = OS Default.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
