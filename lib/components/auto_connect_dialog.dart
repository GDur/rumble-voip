import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:rumble/models/server.dart';

class AutoConnectDialog extends StatefulWidget {
  final MumbleServer server;
  final VoidCallback onCancel;
  final VoidCallback onConnect;

  const AutoConnectDialog({
    super.key,
    required this.server,
    required this.onCancel,
    required this.onConnect,
  });

  @override
  State<AutoConnectDialog> createState() => _AutoConnectDialogState();
}

class _AutoConnectDialogState extends State<AutoConnectDialog> {
  int _countdown = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        Navigator.of(context).pop();
        widget.onConnect();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: const Text('Auto-Connecting'),
      description: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
        child: Text(
          'Connecting to ${widget.server.name} in $_countdown seconds...',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      actions: [
        ShadButton.outline(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop();
            widget.onCancel();
          },
          child: const Text('Cancel'),
        ),
        ShadButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop();
            widget.onConnect();
          },
          child: const Text('Connect Now'),
        ),
      ],
    );
  }
}
