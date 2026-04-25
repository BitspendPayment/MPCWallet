import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Password-based encryption for signer backup blobs.
///
/// Format (all multi-byte fields big-endian):
///   offset 0:  4 bytes  magic "MPCB"
///   offset 4:  1 byte   version = 0x01
///   offset 5:  1 byte   kdf_id = 0x01 (Argon2id)
///   offset 6:  1 byte   aead_id = 0x01 (XChaCha20-Poly1305)
///   offset 7:  1 byte   reserved = 0x00
///   offset 8:  4 bytes  memory_kib (uint32)
///   offset 12: 4 bytes  iterations (uint32)
///   offset 16: 1 byte   parallelism
///   offset 17: 1 byte   salt_len = 16
///   offset 18: 1 byte   nonce_len = 24
///   offset 19: 1 byte   reserved = 0x00
///   offset 20: 16 bytes salt
///   offset 36: 24 bytes nonce
///   offset 60: N bytes  ciphertext || 16-byte Poly1305 tag
///
/// Header bytes (0..60) are fed as associated data to the AEAD so any tamper
/// with parameters fails decryption.

const List<int> _magic = [0x4D, 0x50, 0x43, 0x42]; // "MPCB"
const int _version = 0x01;
const int _kdfArgon2id = 0x01;
const int _aeadXChaCha20Poly1305 = 0x01;
const int _saltLen = 16;
const int _nonceLen = 24;
const int _headerLen = 60;

/// OWASP mobile recommendation — ~500 ms on a mid-range phone.
const int defaultMemoryKib = 64 * 1024; // 64 MiB
const int defaultIterations = 3;
const int defaultParallelism = 4;
const int defaultHashLength = 32;

class BadPasswordException implements Exception {
  final String message;
  BadPasswordException([this.message = 'decryption failed: bad password or tampered blob']);
  @override
  String toString() => 'BadPasswordException: $message';
}

class MalformedBlobException implements Exception {
  final String message;
  MalformedBlobException(this.message);
  @override
  String toString() => 'MalformedBlobException: $message';
}

class UnsupportedVersionException implements Exception {
  final int version;
  UnsupportedVersionException(this.version);
  @override
  String toString() => 'UnsupportedVersionException: version=$version';
}

/// Encrypt a JSON-serializable map into a versioned backup blob.
Future<Uint8List> encryptBackup(
  Map<String, dynamic> plaintextJson,
  String password, {
  int memoryKib = defaultMemoryKib,
  int iterations = defaultIterations,
  int parallelism = defaultParallelism,
  List<int>? salt,
  List<int>? nonce,
}) async {
  final rng = Random.secure();
  final saltBytes = salt != null
      ? Uint8List.fromList(salt)
      : _randomBytes(rng, _saltLen);
  final nonceBytes = nonce != null
      ? Uint8List.fromList(nonce)
      : _randomBytes(rng, _nonceLen);

  if (saltBytes.length != _saltLen) {
    throw ArgumentError('salt must be $_saltLen bytes');
  }
  if (nonceBytes.length != _nonceLen) {
    throw ArgumentError('nonce must be $_nonceLen bytes');
  }

  final header = _buildHeader(
    memoryKib: memoryKib,
    iterations: iterations,
    parallelism: parallelism,
    salt: saltBytes,
    nonce: nonceBytes,
  );

  final key = await _deriveKey(
    password: password,
    salt: saltBytes,
    memoryKib: memoryKib,
    iterations: iterations,
    parallelism: parallelism,
  );

  final plaintext = utf8.encode(jsonEncode(plaintextJson));

  final aead = Xchacha20.poly1305Aead();
  final box = await aead.encrypt(
    plaintext,
    secretKey: SecretKey(key),
    nonce: nonceBytes,
    aad: header,
  );

  final out = BytesBuilder(copy: false);
  out.add(header);
  out.add(box.cipherText);
  out.add(box.mac.bytes);
  return out.toBytes();
}

/// Decrypt a backup blob. Throws [BadPasswordException] on tamper/wrong-password.
Future<Map<String, dynamic>> decryptBackup(
  Uint8List blob,
  String password,
) async {
  if (blob.length < _headerLen + 16) {
    throw MalformedBlobException('blob too short');
  }

  // Validate magic + version + algorithm ids
  for (var i = 0; i < _magic.length; i++) {
    if (blob[i] != _magic[i]) {
      throw MalformedBlobException('bad magic');
    }
  }
  final version = blob[4];
  if (version != _version) {
    throw UnsupportedVersionException(version);
  }
  final kdfId = blob[5];
  if (kdfId != _kdfArgon2id) {
    throw MalformedBlobException('unsupported KDF id: $kdfId');
  }
  final aeadId = blob[6];
  if (aeadId != _aeadXChaCha20Poly1305) {
    throw MalformedBlobException('unsupported AEAD id: $aeadId');
  }

  final view = ByteData.sublistView(blob);
  final memoryKib = view.getUint32(8, Endian.big);
  final iterations = view.getUint32(12, Endian.big);
  final parallelism = blob[16];
  final saltLen = blob[17];
  final nonceLen = blob[18];

  if (saltLen != _saltLen || nonceLen != _nonceLen) {
    throw MalformedBlobException('unexpected salt/nonce length');
  }

  final salt = Uint8List.sublistView(blob, 20, 20 + _saltLen);
  final nonce = Uint8List.sublistView(blob, 36, 36 + _nonceLen);
  final header = Uint8List.sublistView(blob, 0, _headerLen);

  // ciphertext || 16-byte Poly1305 tag
  final macStart = blob.length - 16;
  if (macStart < _headerLen) {
    throw MalformedBlobException('ciphertext+mac too short');
  }
  final cipherText = Uint8List.sublistView(blob, _headerLen, macStart);
  final mac = Uint8List.sublistView(blob, macStart);

  final key = await _deriveKey(
    password: password,
    salt: salt,
    memoryKib: memoryKib,
    iterations: iterations,
    parallelism: parallelism,
  );

  final aead = Xchacha20.poly1305Aead();
  final List<int> plaintext;
  try {
    plaintext = await aead.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(key),
      aad: header,
    );
  } on SecretBoxAuthenticationError {
    throw BadPasswordException();
  }

  final decoded = jsonDecode(utf8.decode(plaintext));
  if (decoded is! Map<String, dynamic>) {
    throw MalformedBlobException('plaintext is not a JSON object');
  }
  return decoded;
}

Uint8List _buildHeader({
  required int memoryKib,
  required int iterations,
  required int parallelism,
  required Uint8List salt,
  required Uint8List nonce,
}) {
  final header = Uint8List(_headerLen);
  header.setRange(0, 4, _magic);
  header[4] = _version;
  header[5] = _kdfArgon2id;
  header[6] = _aeadXChaCha20Poly1305;
  header[7] = 0x00;
  final view = ByteData.sublistView(header);
  view.setUint32(8, memoryKib, Endian.big);
  view.setUint32(12, iterations, Endian.big);
  header[16] = parallelism;
  header[17] = _saltLen;
  header[18] = _nonceLen;
  header[19] = 0x00;
  header.setRange(20, 20 + _saltLen, salt);
  header.setRange(36, 36 + _nonceLen, nonce);
  return header;
}

Future<List<int>> _deriveKey({
  required String password,
  required List<int> salt,
  required int memoryKib,
  required int iterations,
  required int parallelism,
}) async {
  final kdf = Argon2id(
    parallelism: parallelism,
    memory: memoryKib,
    iterations: iterations,
    hashLength: defaultHashLength,
  );
  final derived = await kdf.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,
  );
  return derived.extractBytes();
}

Uint8List _randomBytes(Random rng, int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = rng.nextInt(256);
  }
  return bytes;
}
