import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/services/mumble_service.dart';
import 'package:rumble/services/settings_service.dart';

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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Input Device',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: mumbleService,
            builder: (context, _) {
              final devices = mumbleService.inputDevices;
              final inputDeviceId = settings.inputDeviceId;
              final hasCurrent =
                  inputDeviceId == null ||
                  devices.any((d) => d.name == inputDeviceId);

              return ShadSelect<String?>(
                placeholder: const Text('Default Device'),
                initialValue: inputDeviceId,
                onChanged: (value) async {
                  settings.setInputDeviceId(value);
                  await mumbleService.updateAudioSettings(inputDeviceId: value);
                },
                options: [
                  const ShadOption<String?>(
                    value: null,
                    child: Text('Default Input'),
                  ),
                  if (!hasCurrent)
                    ShadOption<String?>(
                      value: inputDeviceId,
                      child: const Text('Unknown Device'),
                    ),
                  ...devices.map(
                    (d) => ShadOption<String?>(
                      value: d.name,
                      child: Text(d.name),
                    ),
                  ),
                ],
                selectedOptionBuilder: (context, value) {
                  if (value == null) return const Text('Default Input');
                  final dev = devices.cast<dynamic>().firstWhere(
                    (d) => d.name == value,
                    orElse: () => null,
                  );
                  return Text(dev?.name ?? 'Current Device');
                },
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Output Device',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: mumbleService,
            builder: (context, _) {
              final devices = mumbleService.outputDevices;
              final outputDeviceId = settings.outputDeviceId;
              final hasCurrent =
                  outputDeviceId == null ||
                  devices.any((d) => d.toString() == outputDeviceId);

              return ShadSelect<String?>(
                placeholder: const Text('Default Output'),
                initialValue: outputDeviceId,
                onChanged: (value) async {
                  settings.setOutputDeviceId(value);
                  await mumbleService.updateAudioSettings(
                    outputDeviceId: value,
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
                      value: outputDeviceId,
                      child: const Text('Current Device'),
                    ),
                  ...devices.map(
                    (d) => ShadOption<String?>(
                      value: d.toString(),
                      child: Text(d.toString()),
                    ),
                  ),
                ],
                selectedOptionBuilder: (context, value) {
                  if (value == null) return const Text('Default Output');
                  return Text(value);
                },
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Input Gain',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ShadSlider(
                  initialValue: settings.inputGain,
                  min: 0.0,
                  max: 2.0,
                  onChanged: (v) {
                    settings.setInputGain(v);
                    mumbleService.updateAudioSettings(inputGain: v);
                    onUpdate(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(settings.inputGain * 100).round()}%',
                style: theme.textTheme.muted,
              ),
            ],
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
                child: ShadSlider(
                  initialValue: settings.outputVolume,
                  min: 0.0,
                  max: 1.5,
                  onChanged: (v) {
                    settings.setOutputVolume(v);
                    mumbleService.updateAudioSettings(outputVolume: v);
                    onUpdate(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(settings.outputVolume * 100).round()}%',
                style: theme.textTheme.muted,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Microphone Test',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: mumbleService,
            builder: (context, _) {
              final volume = mumbleService.currentVolume;
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
                      widthFactor: volume.clamp(0.0, 1.0),
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
        ],
      ),
    );
  }
}
