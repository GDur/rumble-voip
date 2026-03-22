import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// Opus Constants
const int opusOk = 0;
const int opusApplicationVoip = 2048;
const int opusApplicationAudio = 2049;
const int opusApplicationLowDelay = 2051;

/// A wrapper around a FFI-allocated Int16List that is managed manually.
class FfiInt16Buffer {
  final int capacity;
  late final Pointer<Int16> pointer;
  late final Int16List list;

  FfiInt16Buffer(this.capacity) {
    pointer = malloc.allocate<Int16>(capacity * Int16List.bytesPerElement);
    list = pointer.asTypedList(capacity);
  }

  void dispose() {
    malloc.free(pointer);
  }
}

/// A wrapper around a FFI-allocated Uint8List that is managed manually.
class FfiUint8Buffer {
  final int capacity;
  late final Pointer<Uint8> pointer;
  late final Uint8List list;

  FfiUint8Buffer(this.capacity) {
    pointer = malloc.allocate<Uint8>(capacity);
    list = pointer.asTypedList(capacity);
  }

  void dispose() {
    malloc.free(pointer);
  }
}
