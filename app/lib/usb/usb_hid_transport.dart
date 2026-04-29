/// USB HID transport layer.
///
/// Bridges Flutter platform channels (Android USB Host API) with the
/// HID chunking protocol to send/receive JSON commands to the HW Signer.
library;

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:client/usb/hid_chunking.dart';

class UsbHidTransport {
  static const _channel = MethodChannel('com.mpcwallet.ap/usb_hid');
  final _reassembler = HidReassembler();
  bool _connected = false;

  /// Discover connected HW Signer devices.
  Future<List<Map<String, dynamic>>> enumerate() async {
    final result = await _channel.invokeMethod('enumerate');
    return (result as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Open a connection to the first matching device.
  Future<void> open() async {
    await _channel.invokeMethod('open');
    _connected = true;
  }

  /// Close the connection.
  Future<void> close() async {
    try {
      await _channel.invokeMethod('close');
    } finally {
      _connected = false;
    }
  }

  /// Send a JSON command and receive the JSON response.
  Future<Map<String, dynamic>> sendCommand(Map<String, dynamic> cmd) async {
    if (!_connected) throw StateError('Not connected');

    final jsonBytes = utf8.encode(jsonEncode(cmd));
    final reports = chunkMessage(Uint8List.fromList(jsonBytes));

    // Send all reports
    for (var i = 0; i < reports.length; i++) {
      await _channel.invokeMethod('writeReport', reports[i]);
    }

    // Read response reports until reassembly completes
    _reassembler.reset();
    while (true) {
      final result = await _channel.invokeMethod('readReport');
      final report = Uint8List.fromList(List<int>.from(result));
      final message = _reassembler.feed(report);
      if (message != null) {
        if (message.isEmpty) {
          throw StateError('Received empty message from device');
        }
        final json =
            jsonDecode(utf8.decode(message)) as Map<String, dynamic>;
        if (json.containsKey('error')) {
          throw Exception('Signer error: ${json['error']}');
        }
        return json;
      }
    }
  }

  bool get isConnected => _connected;
}
