import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class MumblePingResponse {
  final int latency;
  final int users;
  final int maxUsers;

  MumblePingResponse({
    required this.latency,
    required this.users,
    required this.maxUsers,
  });
}

class MumblePingService {
  static Future<MumblePingResponse> ping(String host, int port) async {
    final Completer<MumblePingResponse> completer = Completer();
    final RawDatagramSocket socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );

    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final ByteData packet = ByteData(12);
    packet.setUint32(0, 0); // Type 0 (Ping)
    packet.setUint64(4, timestamp); // Identifier/Timestamp

    InternetAddress? address;
    try {
      final List<InternetAddress> addresses = await InternetAddress.lookup(
        host,
      );
      if (addresses.isEmpty) throw Exception('Could not resolve host');
      address = addresses.first;
    } catch (e) {
      socket.close();
      rethrow;
    }

    socket.send(packet.buffer.asUint8List(), address, port);

    Timer? timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Ping timed out'));
        socket.close();
      }
    });

    socket.listen(
      (RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final Datagram? dg = socket.receive();
          if (dg != null && dg.data.length >= 24) {
            final ByteData response = ByteData.sublistView(dg.data);
            final int receivedTimestamp = response.getUint64(4);

            if (receivedTimestamp == timestamp) {
              final int users = response.getUint32(12);
              final int maxUsers = response.getUint32(16);
              final int latency =
                  DateTime.now().millisecondsSinceEpoch - timestamp;

              if (!completer.isCompleted) {
                completer.complete(
                  MumblePingResponse(
                    latency: latency,
                    users: users,
                    maxUsers: maxUsers,
                  ),
                );
                timeoutTimer?.cancel();
                socket.close();
              }
            }
          }
        }
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
          timeoutTimer?.cancel();
          socket.close();
        }
      },
    );

    return completer.future;
  }
}
