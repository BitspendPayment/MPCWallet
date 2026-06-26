/// End-to-end test for the software signer + ephemeral recovery flow.
///
/// Proves the full path against a real co-signing server:
///   1. SoftwareSigner drives a real DKG → group key established server-side
///   2. exportEncryptedBackup produces a blob that round-trips
///   3. A fresh SoftwareSigner from the blob carries the DKG KeyPackage
///   4. doRestore() with a re-hydrated signer reproduces the same group
///      verifying key (the hallmark of recovery)
///
/// Differs from full_system_test.dart in two ways:
///   * No Rust signer-server process needed — SoftwareSigner is in-process.
///   * Drive backup is simulated by a local Uint8List variable; the BackupStore
///     interface lives in the ap package which e2e doesn't depend on. This
///     test exercises SoftwareSigner.exportEncryptedBackup + fromEncryptedBackup
///     directly, which is the only contract the Drive layer relies on.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_core/bitcoin.dart';
import 'package:app_core/client.dart';
import 'package:app_core/software_signer.dart';
import 'package:e2e/logger.dart';
import 'package:e2e/regtest_helper.dart';
import 'package:hive/hive.dart';
import 'package:test/test.dart';

void main() {
  Process? serverProcess;
  late RegtestHelper btc;
  late Directory tempDir;
  late Directory serverTempDir;
  late int serverPort;

  setUpAll(() async {
    Log.header('Setup (software signer e2e)');

    tempDir = await Directory.systemTemp.createTemp('mpc_sw_e2e_');
    Hive.init(tempDir.path);

    // Bitcoind + Electrs (same containers full_system_test uses).
    Log.info('Starting Docker (Bitcoind)…');
    var dRes = await Process.run('docker', ['compose', 'up', '-d', 'bitcoind']);
    if (dRes.exitCode != 0) {
      throw Exception("Docker Bitcoind failed: ${dRes.stderr}");
    }
    Log.info("Waiting for Bitcoind (10s)…");
    await Future.delayed(const Duration(seconds: 10));

    Log.info('Starting Docker (Electrs)…');
    dRes = await Process.run('docker', ['compose', 'up', '-d', 'electrs']);
    if (dRes.exitCode != 0) {
      throw Exception("Docker Electrs failed: ${dRes.stderr}");
    }
    Log.info("Waiting for Electrs (20s)…");
    await Future.delayed(const Duration(seconds: 20));

    btc = RegtestHelper();
    try {
      try {
        await btc.createWallet("default");
      } catch (e) {
        if (!e.toString().contains("already loaded")) rethrow;
      }
      btc = RegtestHelper(rpcUrl: "http://127.0.0.1:18443/wallet/default");
      await btc.getNewAddress();
      Log.ok("Docker Regtest operational.");
    } catch (e) {
      throw Exception("Docker started but RPC unreachable: $e");
    }

    // MPC co-signing server.
    Log.info('Starting MPC Server…');
    final portSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    serverPort = portSocket.port;
    await portSocket.close();
    serverTempDir = await Directory.systemTemp.createTemp('mpc_sw_server_');
    final serverReady = Completer<void>();
    final serverFailed = Completer<void>();
    serverProcess = await Process.start(
      '../cosigner-runtime/target/release/cosigner-runtime',
      [
        '--port', serverPort.toString(),
      ],
      mode: ProcessStartMode.normal,
      environment: {
        'ELECTRUM_URL': '127.0.0.1',
        'ELECTRUM_PORT': '50001',
        'BITCOIN_RPC_USER': 'admin1',
        'BITCOIN_RPC_PASSWORD': '123',
        'HOME': serverTempDir.path,
      },
    );
    final stdoutBuf = StringBuffer();
    serverProcess!.stdout.transform(utf8.decoder).listen((data) {
      stdoutBuf.write(data);
      Log.server(data);
      if (!serverReady.isCompleted &&
          stdoutBuf.toString().contains('MPC Wallet Server listening on')) {
        serverReady.complete();
      }
    }, onDone: () {
      if (!serverReady.isCompleted && !serverFailed.isCompleted) {
        serverFailed.complete();
      }
    });
    final stderrBuf = StringBuffer();
    serverProcess!.stderr.transform(utf8.decoder).listen((data) {
      stderrBuf.write(data);
      Log.server(data);
      if (!serverReady.isCompleted &&
          stderrBuf.toString().contains('MPC Wallet Server listening on')) {
        serverReady.complete();
      }
    }, onDone: () {
      if (!serverReady.isCompleted && !serverFailed.isCompleted) {
        serverFailed.complete();
      }
    });

    try {
      await Future.any([
        serverReady.future,
        serverFailed.future.then((_) {
          throw Exception("MPC Server failed to start");
        }),
      ]).timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception("MPC Server did not become ready in time");
      });
    } catch (e) {
      serverProcess?.kill();
      try {
        await serverTempDir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
    Log.ok('Setup complete.');
    Log.separator();
  });

  tearDownAll(() async {
    serverProcess?.kill();
    try {
      await serverTempDir.delete(recursive: true);
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  /// Build an MpcClient for [signer]. Software signer is intentionally
  /// nullable on the client; for ops that need it we pass it here, for
  /// passive sessions we pass null.
  MpcClient buildClient({SoftwareSigner? signer, required String storageId}) {
    return MpcClient.rest(
      'http://127.0.0.1:$serverPort',
      hardwareSigner: signer,
      storageId: storageId,
    );
  }

  test(
    'SoftwareSigner e2e: DKG → backup → wipe → rehydrate → restore',
    () async {
      // ----- 1. DKG with an in-process software signer ----------------------
      Log.step(1, 'Initial DKG with SoftwareSigner');
      const password = 'correct-horse-battery-staple';
      final signer1 = SoftwareSigner();
      await signer1.connect();

      final client1 =
          buildClient(signer: signer1, storageId: 'sw_e2e_initial');
      await client1.doDkg();
      Log.ok('DKG complete (group key established server-side).');

      final wallet = MpcBitcoinWallet(client1, networkName: 'regtest');
      await wallet.init();
      final originalAddress = wallet.toAddress();
      Log.info('Wallet address: $originalAddress');

      expect(signer1.hasBackupableState, isTrue,
          reason: 'DKG must populate the signer with a secret + KeyPackage');

      // ----- 2. Export → "upload" → wipe ------------------------------------
      Log.step(2, 'Export encrypted backup, upload to in-memory store, wipe');
      Uint8List? backupBlob =
          await signer1.exportEncryptedBackup(password); // simulated upload
      expect(backupBlob, isNotNull);
      expect(backupBlob.length, greaterThan(60),
          reason: 'blob must include header + ciphertext + tag');

      // Detach signer from the client so the share can no longer be reached.
      client1.hardwareSigner = null;
      await signer1.wipe();
      expect(signer1.hasBackupableState, isFalse,
          reason: 'wipe() must clear all in-memory recovery state');

      // ----- 3. The client stays usable signer-less for normal sessions -----
      // We don't fund the wallet here (keeps the test scope tight), just
      // assert the API: the client runs without a signer attached.
      expect(client1.hardwareSigner, isNull,
          reason: 'client should run signer-less for normal sessions');

      // ----- 4. Re-hydrate from blob and confirm the KeyPackage round-trips -
      Log.step(3, 'Re-hydrate signer from blob; verify KeyPackage survives');

      final signer2 =
          await SoftwareSigner.fromEncryptedBackup(blob: backupBlob, password: password);
      await signer2.connect();
      final info = await signer2.getInfo();
      expect(info.hasKeyPackage, isTrue,
          reason: 'rehydrated signer must carry the KeyPackage from DKG');
      expect(info.identifierHex, isNotNull);
      await signer2.wipe();
      Log.ok('Signer rehydrated from blob with intact KeyPackage.');

      // Wrong password must reject without leaking state.
      await expectLater(
        SoftwareSigner.fromEncryptedBackup(
            blob: backupBlob, password: 'definitely-not-the-password'),
        throwsA(isA<Object>()),
        reason: 'wrong password must throw',
      );

      // ----- 5. Full restore (re-DKG) reproduces the same group key ---------
      Log.step(4, 'doRestore() with rehydrated signer must yield same address');
      final signer3 =
          await SoftwareSigner.fromEncryptedBackup(blob: backupBlob, password: password);
      await signer3.connect();
      final client2 =
          buildClient(signer: signer3, storageId: 'sw_e2e_restore');
      try {
        await client2.doRestore();
      } finally {
        // Update the blob to reflect the refreshed share post-restore, then
        // wipe. (In production this is done by MpcService._maybeUploadBackup.)
        if (signer3.hasBackupableState) {
          backupBlob = await signer3.exportEncryptedBackup(password);
        }
        client2.hardwareSigner = null;
        await signer3.wipe();
      }

      final wallet2 = MpcBitcoinWallet(client2, networkName: 'regtest');
      await wallet2.init();
      final restoredAddress = wallet2.toAddress();
      Log.info('Restored address: $restoredAddress');
      expect(restoredAddress, equals(originalAddress),
          reason:
              'doRestore with rehydrated software signer must reproduce the same Bitcoin address — '
              'this is the core invariant of recovery');

      // ----- 6. After restore the (refreshed) blob is still usable ---------
      // Sanity: the post-restore blob can be loaded back. We don't drive
      // another DKG round, just confirm decryption + state shape.
      final signer4 =
          await SoftwareSigner.fromEncryptedBackup(blob: backupBlob, password: password);
      await signer4.connect();
      final info2 = await signer4.getInfo();
      expect(info2.hasKeyPackage, isTrue,
          reason:
              'post-restore blob must carry the refreshed KeyPackage');
      await signer4.wipe();

      Log.separator();
      Log.ok('SoftwareSigner e2e passed.');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
