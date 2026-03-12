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
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndStart();
  }

  Future<void> _checkPermissionAndStart() async {
    // Check using our utility AND the recorder's own check
    final statusGranted = await PermissionUtils.isMicrophonePermissionGranted();
    final recorderGranted = await _audioRecorder.hasPermission();
    final granted = statusGranted || recorderGranted;
    
    debugPrint('[AudioInputIndicator] Permission check: status=$statusGranted, recorder=$recorderGranted');
    
    if (mounted) {
      if (granted && !_hasPermission) {
        setState(() => _hasPermission = true);
        _startMonitoring();
        _statusTimer?.cancel(); // Stop checking once granted
      } else if (!granted && _statusTimer == null) {
        // Start polling every second if we don't have permission yet
        _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _checkPermissionAndStart();
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant AudioInputIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkPermissionAndStart();
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

        try {
          final isRecording = await _audioRecorder.isRecording();
          if (!isRecording && _hasPermission) {
             // Try to restart if it stopped for some reason
             final tempDir = await getTemporaryDirectory();
             final path = '${tempDir.path}/rumble_mic_monitor.m4a';
             await _audioRecorder.start(const RecordConfig(), path: path);
          }

          final amplitude = await _audioRecorder.getAmplitude();
          if (mounted) {
            setState(() {
              // We want to show movement even for quiet sounds
              // Range: -50dB (silence) to 0dB (loud)
              // If current is -160, it means no data
              if (amplitude.current <= -100) {
                 _currentVolume = 0.0;
              } else {
                double volume = (amplitude.current + 50) / 50;
                _currentVolume = volume.clamp(0.0, 1.0);
              }
            });
          }
        } catch (e) {
          debugPrint('[AudioInputIndicator] Monitoring error: $e');
        }
      });
    } catch (e) {
      debugPrint('[AudioInputIndicator] Error monitoring audio: $e');
      _isMonitoring = false;
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _isMonitoring = false;
    _amplitudeSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    
    return Container(
      width: 140, // Increased width
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.popover.withAlpha(220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MIC STATUS',
                style: theme.textTheme.muted.copyWith(
                  fontSize: 10, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              if (_isMonitoring)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // The "Progress" item
          Container(
            height: 10, // Thicker bar
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(30),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _hasPermission ? _currentVolume : 1.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 40), // Faster response
                    decoration: BoxDecoration(
                      color: _hasPermission 
                          ? Colors.green.withAlpha(180) // More solid green
                          : Colors.grey.withAlpha(80), // Pure gray for no permission
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: _hasPermission && _currentVolume > 0.1 ? [
                        BoxShadow(
                          color: Colors.green.withAlpha(150),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ] : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_hasPermission) ...[
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Awaiting Permission',
                style: theme.textTheme.muted.copyWith(
                  fontSize: 9, 
                  color: Colors.orange.withAlpha(200),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
