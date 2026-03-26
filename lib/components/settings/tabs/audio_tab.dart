import 'package:flutter/material.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/settings_service.dart';
import 'package:rumble/src/rust/mumble/hardware/audio.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

// Component: audio-tab
class AudioTab extends StatelessWidget {
  final SettingsService settings;
  final MumbleService mumbleService;
  final StateSetter onUpdate;

  const AudioTab({
    super.key,
    required this.settings,
    required this.mumbleService,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    const double volumeMultiplier = 10.0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio Input',
            style: theme.textTheme.large.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Input Device',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: mumbleService,
            builder: (context, _) {
              final devices = mumbleService.inputDevices;
              final captureDeviceId = settings.captureDeviceId;
              final hasCurrent =
                  captureDeviceId == null ||
                  devices.any((d) => d.id == captureDeviceId);

              return ShadSelect<String?>(
                placeholder: const Text('Default Device'),
                initialValue: captureDeviceId,
                onChanged: (value) async {
                  settings.setCaptureDeviceId(value);
                  await mumbleService.updateAudioSettings(captureDeviceId: value);
                },
                options: [
                  const ShadOption<String?>(
                    value: null,
                    child: Text('Default Input'),
                  ),
                  if (!hasCurrent)
                    ShadOption<String?>(
                      value: captureDeviceId,
                      child: const Text('Unknown Device'),
                    ),
                  ...devices.map(
                    (d) =>
                        ShadOption<String?>(value: d.id, child: Text(d.name)),
                  ),
                ],
                selectedOptionBuilder: (context, value) {
                  if (value == null) return const Text('Default Input');
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
          const Text('Quality', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ShadSlider(
                    initialValue: settings.outgoingAudioBitrate / 1000,
                    min: 32.0,
                    max: 192.0,
                    divisions: ((192.0 - 32.0) / 16.0).toInt(),
                    thumbRadius: 10,
                    onChanged: (v) {
                      final bitrate = (v * 1000).round();
                      settings.setOutgoingAudioBitrate(bitrate);
                      mumbleService.updateAudioSettings(
                        outgoingAudioBitrate: bitrate,
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
                  '${(settings.outgoingAudioBitrate / 1000).round()} kb/s',
                  style: theme.textTheme.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Audio per packet',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ShadTabs<int>(
            value: settings.outgoingAudioMsPerPacket,
            onChanged: (v) {
              settings.setOutgoingAudioMsPerPacket(v);
              mumbleService.updateAudioSettings(outgoingAudioMsPerPacket: v);
              onUpdate(() {});
            },
            tabs: [
              ShadTab(
                value: 10,
                child: const Text('10ms'),
              ),
              ShadTab(
                value: 20,
                child: const Text('20ms'),
              ),
              ShadTab(
                value: 40,
                child: const Text('40ms'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Input Gain',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ShadSlider(
                    initialValue: settings.inputGain,
                    min: 0.0,
                    max: 2.0,
                    thumbRadius: 10,
                    onChanged: (v) {
                      settings.setInputGain(v);
                      mumbleService.updateAudioSettings(inputGain: v);
                      onUpdate(() {});
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: Text(
                  '${(settings.inputGain * 100).round()}%',
                  style: theme.textTheme.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Microphone Test',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<double>(
            valueListenable: mumbleService.volumeNotifier,
            builder: (context, volume, child) {
              final displayVolume = (volume * volumeMultiplier).clamp(0.0, 1.0);
              return Container(
                height: 24,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: displayVolume,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.greenAccent, Colors.green],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Speak into your mic to see the level.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 40),
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
                    (d) =>
                        ShadOption<String?>(value: d.id, child: Text(d.name)),
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
        ],
      ),
    );
  }
}
