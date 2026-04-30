/// HID report chunking protocol.
///
/// Splits JSON messages into 64-byte HID reports and reassembles them.
/// Mirrors the firmware's `chunking.rs` implementation exactly.
///
/// Report layout (64 bytes):
///   Bytes 0-1:  Channel ID (0x01, 0x01)
///   Byte  2:    Command tag (0x05 = MSG)
///   Bytes 3-4:  Sequence number (big-endian u16)
///   Bytes 5+:   Payload
///
/// First packet (seq 0): bytes 5-6 = total message length, bytes 7-63 = payload
/// Continuation (seq >= 1): bytes 5-63 = payload
library;

import 'dart:typed_data';

const int _reportSize = 64;
const int _channelHi = 0x01;
const int _channelLo = 0x01;
const int _cmdMsg = 0x05;
const int _headerSize = 5; // 2 channel + 1 cmd + 2 seq
const int _firstPayload = _reportSize - _headerSize - 2; // 57
const int _contPayload = _reportSize - _headerSize; // 59

/// Chunk a message into 64-byte HID reports.
List<Uint8List> chunkMessage(Uint8List message) {
  final reports = <Uint8List>[];
  int offset = 0;
  int seq = 0;

  // First report
  final first = Uint8List(_reportSize);
  first[0] = _channelHi;
  first[1] = _channelLo;
  first[2] = _cmdMsg;
  first[3] = (seq >> 8) & 0xFF;
  first[4] = seq & 0xFF;
  first[5] = (message.length >> 8) & 0xFF;
  first[6] = message.length & 0xFF;
  final chunk0 =
      message.length < _firstPayload ? message.length : _firstPayload;
  first.setRange(7, 7 + chunk0, message, 0);
  offset += chunk0;
  reports.add(first);
  seq++;

  // Continuation reports
  while (offset < message.length) {
    final report = Uint8List(_reportSize);
    report[0] = _channelHi;
    report[1] = _channelLo;
    report[2] = _cmdMsg;
    report[3] = (seq >> 8) & 0xFF;
    report[4] = seq & 0xFF;
    final remaining = message.length - offset;
    final chunk = remaining < _contPayload ? remaining : _contPayload;
    report.setRange(5, 5 + chunk, message, offset);
    offset += chunk;
    reports.add(report);
    seq++;
  }

  return reports;
}

/// Reassembler for incoming HID reports.
class HidReassembler {
  final _buffer = BytesBuilder();
  int _expectedLen = 0;
  int _nextSeq = 0;
  bool _active = false;

  void reset() {
    _buffer.clear();
    _expectedLen = 0;
    _nextSeq = 0;
    _active = false;
  }

  /// Feed a 64-byte report. Returns the complete message when done, or null.
  Uint8List? feed(Uint8List report) {
    if (report.length != _reportSize) {
      throw ArgumentError('report must be $_reportSize bytes');
    }
    if (report[0] != _channelHi || report[1] != _channelLo) {
      throw StateError('invalid channel');
    }
    if (report[2] != _cmdMsg) {
      throw StateError('invalid command tag');
    }

    final seq = (report[3] << 8) | report[4];

    if (seq == 0) {
      reset();
      _expectedLen = (report[5] << 8) | report[6];
      final chunk =
          _expectedLen < _firstPayload ? _expectedLen : _firstPayload;
      _buffer.add(report.sublist(7, 7 + chunk));
      _nextSeq = 1;
      _active = true;
    } else {
      if (!_active || seq != _nextSeq) {
        reset();
        throw StateError('unexpected sequence number');
      }
      final remaining = _expectedLen - _buffer.length;
      final chunk = remaining < _contPayload ? remaining : _contPayload;
      _buffer.add(report.sublist(5, 5 + chunk));
      _nextSeq++;
    }

    if (_buffer.length >= _expectedLen) {
      final len = _expectedLen;
      final msg = _buffer.takeBytes();
      reset();
      return Uint8List.fromList(msg.sublist(0, len));
    }
    return null;
  }
}
