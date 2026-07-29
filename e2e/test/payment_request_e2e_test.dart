import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_core/client.dart';
import 'package:app_core/passkey/session_token_source.dart';
import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';
import 'package:test/test.dart';

/// Request-to-pay E2E: one wallet allowlists another, the other bills it, and the payer decides.
///
/// The assertion that matters most is that the intent's payee address equals the REQUESTER'S OWN
/// Ark address. That address is derived by the payer's cosigner from the requester's group key and
/// is never supplied by the requester — and getting it wrong is not a cosmetic bug: paying a
/// wrongly-derived address sends funds somewhere the requester cannot spend, silently. (That is
/// exactly what happened when the requester was identified by its share key instead of its group
/// key, which this test now pins down.)
///
/// Needs arkd — deriving the payee address requires ASP info — but no funding: nothing is paid,
/// so the test stays fast and deterministic.

/// The dev token secret pinned by the Makefile's regtest targets.
const _devTokenSecret =
    '6d706377616c6c65742d6465762d746f6b656e2d7365637265742d3332622121';

Future<Process> startRuntime(int port, Directory dataDir) async {
  final ready = Completer<void>();
  final failed = Completer<void>();
  final env = {
    'BITCOIN_NETWORK': 'regtest',
    'HOME': dataDir.path,
    'ASP_URL': Platform.environment['ASP_URL'] ?? 'http://127.0.0.1:7070',
    // The Makefile exports REDIS_URL for its own targets; default it so a direct
    // `dart test test/payment_request_e2e_test.dart` works too.
    'REDIS_URL': Platform.environment['REDIS_URL'] ??
        'redis://:testpass@127.0.0.1:6379',
    'WEBAUTH_TOKEN_SECRET': _devTokenSecret,
  };
  final proc = await Process.start(
    '../cosigner-runtime/target/release/cosigner-runtime',
    ['--port', port.toString()],
    environment: env,
  );
  void watch(Stream<List<int>> s) {
    s.transform(utf8.decoder).listen((data) {
      print('[Server]: $data');
      if (!ready.isCompleted && data.contains('MPC Wallet Server listening on')) {
        ready.complete();
      }
    }, onDone: () {
      if (!ready.isCompleted && !failed.isCompleted) failed.complete();
    });
  }

  watch(proc.stdout);
  watch(proc.stderr);
  await Future.any([
    ready.future,
    failed.future.then((_) => throw Exception('runtime failed to start')),
  ]).timeout(const Duration(seconds: 30),
      onTimeout: () => throw Exception('runtime not ready'));
  return proc;
}

/// Mint the session token these endpoints require.
///
/// Most Ark routes authenticate against the id in the URL rather than a body signature, so a
/// token is the only credential that works (the app gets one from a passkey assertion). In
/// regtest the signing secret is a known dev value, so the test mints its own.
Future<String> mintSessionToken(String subject) async {
  String b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final header = b64(utf8.encode('{"alg":"EdDSA","typ":"JWT"}'));
  final payload = b64(utf8.encode(jsonEncode({
    'sub': subject,
    'exp': now + 3600,
    'iat': now,
    'jti': 'e2e-$now',
  })));
  final signingInput = '$header.$payload';

  final seed = List<int>.generate(
    _devTokenSecret.length ~/ 2,
    (i) => int.parse(_devTokenSecret.substring(i * 2, i * 2 + 2), radix: 16),
  );
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(seed);
  final sig = await algorithm.sign(utf8.encode(signingInput), keyPair: keyPair);
  return '$signingInput.${b64(sig.bytes)}';
}

/// DKG a wallet and give it a session token bound to the id it addresses the API by.
Future<MpcClient> newWallet(int port, String storageId) async {
  final c = MpcClient.rest('http://127.0.0.1:$port', storageId: storageId);
  await c.doDkg();
  final id = c.userId;
  if (id == null) {
    throw StateError('$storageId: no user id after DKG');
  }
  // `sub` must match the URL id and the body `user_id`; the runtime checks the token first.
  c.setSessionTokenSource(StaticSessionToken(await mintSessionToken(id)));
  return c;
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  late Directory tempDir;
  late Directory serverTempDir;
  Process? proc;
  late int port;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('mpc_payreq_');
    Hive.init(tempDir.path);
    serverTempDir = await Directory.systemTemp.createTemp('mpc_payreq_server_');
    final sock = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    port = sock.port;
    await sock.close();
    proc = await startRuntime(port, serverTempDir);
  });

  tearDownAll(() async {
    proc?.kill();
    for (final d in [serverTempDir, tempDir]) {
      try {
        await d.delete(recursive: true);
      } catch (_) {}
    }
  });

  test('allowlist gates requests; the payee address is the requester\'s own', () async {
    final alice = await newWallet(port, 'alice'); // the payer
    final bob = await newWallet(port, 'bob'); // asks to be paid
    final aliceKey = alice.userId!;
    final bobKey = bob.userId!;
    final bobGroupKey = bob.groupKeyHex!; // canonical identity the cosigner resolves ids to
    print('1. alice=${aliceKey.substring(0, 12)} bob=${bobKey.substring(0, 12)}');

    // A stranger cannot bill alice. This is the whole security model: `verify_auth` proves key
    // possession but does NOT bind a signer to the actor it addresses, so the allowlist is the
    // only thing standing between bob and alice's inbox.
    await expectLater(
      bob.requestPayment(aliceKey, 1000, memo: 'should be refused'),
      throwsA(isA<Exception>()),
      reason: 'a non-contact must not be able to create a request',
    );
    print('2. Un-allowlisted request refused');

    // Add bob by the id he addresses the API with; the cosigner canonicalises it to his GROUP
    // key, so the stored allowlist entry is that — not the id we passed in. Pinning this keeps
    // the allowlist comparable no matter which of a wallet's ids a caller uses.
    await alice.contactAdd(bobKey, 'Bob');
    final contacts = await alice.contactList();
    expect(contacts.map((c) => _hex(c.verifyingKey)), contains(bobGroupKey));
    print('3. alice allowlisted bob (stored canonically as his group key)');

    final intent = await bob.requestPayment(aliceKey, 25000, memo: 'coffee');
    expect(intent.amountSats.toInt(), 25000);
    expect(_hex(intent.fromVerifyingKey), bobGroupKey);
    expect(intent.status, 'pending');
    expect(intent.memo, 'coffee');

    // THE regression guard: the cosigner must derive the payee address from bob's GROUP key, so
    // it has to equal the address bob himself would hand out. Any other key yields an address bob
    // cannot spend, and the payment would appear to succeed.
    final bobsOwnAddress = await bob.getArkAddress();
    expect(intent.toArkAddress, bobsOwnAddress,
        reason: 'payee address must be the requester\'s own Ark address');
    print('4. Request created; payee address == bob\'s own address');

    final inbox = await alice.paymentRequests();
    expect(inbox.map((i) => i.id), contains(intent.id));
    print('5. Request is in alice\'s inbox');

    await alice.declinePaymentRequest(intent.id);
    final afterDecline = await alice.paymentRequests();
    expect(
      afterDecline.firstWhere((i) => i.id == intent.id).status,
      'declined',
    );
    print('6. alice declined it');

    // Revoking must also drop that contact's pending requests — otherwise revocation would stop
    // new requests but leave old ones sitting in the inbox.
    final second = await bob.requestPayment(aliceKey, 500, memo: 'another');
    await alice.contactRemove(bobKey);
    final afterRevoke = await alice.paymentRequests();
    expect(afterRevoke.where((i) => i.id == second.id), isEmpty,
        reason: 'revoking a contact must discard their pending requests');
    await expectLater(
      bob.requestPayment(aliceKey, 100, memo: 'after revoke'),
      throwsA(isA<Exception>()),
      reason: 'a revoked contact must not be able to create a request',
    );
    print('7. Revoke closed the gate and dropped the pending request');

    print('Payment-request E2E complete.');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
