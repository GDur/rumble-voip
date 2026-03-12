import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/utils/permissions.dart';
import 'package:path_provider/path_provider.dart';

class AudioInputIndicator extends StatefulWidget {
  const AudioInputIndicator({super.key});

  @override
  State<AudioInputIndicator> createState() => _AudioInputIndicatorState();
}

class _AudioInputIndicatorState extends State<AudioInputIndicator> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  double _currentVolume = 0.0;
  bool _hasPermission = false;
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndStart();
  }

  Future<void> _checkPermissionAndStart() async {
    final granted = await PermissionUtils.isMicrophonePermissionGranted();
    if (mounted) {
      setState(() {
        _hasPermission = granted;
      });
      if (granted) {
        _startMonitoring();
      }
    }
  }

  Future<void> _startMonitoring() async {
    if (_isMonitoring) return;

    try {
      final tempDir = await getTemporaryDirectory();
      // Using a random-ish name to avoid conflicts, but same name is fine for dummy
      final path = '${tempDir.path}/rumble_mic_monitor.m4a';
      
      // Start recording to a dummy file to enable amplitude polling
      await _audioRecorder.start(const RecordConfig(), path: path);
      
      _isMonitoring = true;
      
      // Polling amplitude every 50ms for smooth animation
      Timer.periodic(const Duration(milliseconds: 50), (timer) async {
        if (!mounted || !_isMonitoring) {
          timer.cancel();
          if (await _audioRecorder.isRecording()) {
            await _audioRecorder.stop();
          }
          return;
        }

        final amplitude = await _audioRecorder.getAmplitude();
        if (mounted) {
          setState(() {
            // Amplitude current value is usually -160 to 0 (dBfs)
            // We want to show movement even for quiet sounds
            // Range: -50dB (silence) to 0dB (loud)
            double volume = (amplitude.current + 50) / 50;
            _currentVolume = volume.clamp(0.0, 1.0);
          });
        }
      });
    } catch (e) {
      debugPrint('Error monitoring audio: $e');
      _isMonitoring = false;
    }
  }

  @override
  void dispose() {
    _isMonitoring = false;
    _amplitudeSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    
    return Container(
      width: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.popover.withAlpha(200),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MIC STATUS',
            style: theme.textTheme.muted.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          // The "Progress" item
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _hasPermission ? Colors.grey.withAlpha(50) : Colors.grey.withAlpha(100),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _hasPermission ? _currentVolume : 1.0, // Full width gray if no permission
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                decoration: BoxDecoration(
                  color: _hasPermission 
                      ? Colors.green.withAlpha(150) // Transparent green
                      : Colors.transparent, // Let the background gray show
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: _hasPermission && _currentVolume > 0.05 ? [
                    BoxShadow(
                      color: Colors.green.withAlpha(100),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ] : null,
                ),
              ),
            ),
          ),
          if (!_hasPermission) ...[
            const SizedBox(height: 4),
            Text(
              'No Access',
              style: theme.textTheme.muted.copyWith(fontSize: 8, color: Colors.orange),
            ),
          ]
        ],
      ),
    );
  }
}
