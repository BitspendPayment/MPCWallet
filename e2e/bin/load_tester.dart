/// MPC Wallet Load Tester
///
/// Uses the real MpcClient and TcpHardwareSigner, exactly as the E2E tests
/// do, to drive concurrent DKG sessions against the live server.
///
/// Usage:
///   dart run bin/load_tester.dart [options]
///
/// Options:
///   --server       gRPC server address  (default: 127.0.0.1:50051)
///   --signer-host  Signer-server host   (default: 127.0.0.1)
///   --signer-port  Base TCP port for signer-server instances (default: 9090)
///   --sessions     Total number of DKG sessions to run  (default: 10)
///   --concurrency  Max sessions in flight simultaneously (default: 5)
///   --hive-dir     Directory for Hive storage             (default: /tmp/mpc_load_test_hive)

import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'package:client/client.dart';
import 'package:client/hardware_signer.dart';
import 'package:grpc/grpc.dart';
import 'package:hive/hive.dart';

// ---------------------------------------------------------------------------
// Tiny inline logger (mirrors e2e/lib/logger.dart without the package dep)
// ---------------------------------------------------------------------------

final bool _color = stdout.supportsAnsiEscapes;
String _c(String code, String t) => _color ? '\x1B[${code}m$t\x1B[0m' : t;

String get _ts {
  final n = DateTime.now();
  return _c('90',
      '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}');
}

void _header(String t) {
  const w = 54;
  final line = '── $t ' + '─' * (w - t.length - 4);
  print(_c('1', line));
}

void _info(String m) => print('$_ts ${_c('36', 'INFO')}  $m');
void _ok(String m) => print('$_ts ${_c('32', ' OK ')}  $m');
void _err(String m) => stderr.writeln('$_ts ${_c('31', 'ERR ')}  $m');
void _sep() => print(_c('90', '─' * 54));

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

ArgResults _parseArgs(List<String> argv) {
  final parser = ArgParser()
    ..addOption('server',
        defaultsTo: '127.0.0.1:50051', help: 'gRPC server host:port')
    ..addOption('signer-host',
        defaultsTo: '127.0.0.1', help: 'Signer-server host')
    ..addOption('signer-port',
        defaultsTo: '9090',
        help: 'TCP port for signer-server')
    ..addFlag('multi-signer',
        defaultsTo: false,
        help: 'If true, each session uses port = base + index (default: false)')
    ..addOption('sessions',
        defaultsTo: '10', help: 'Total DKG sessions to run')
    ..addOption('concurrency',
        defaultsTo: '5', help: 'Max concurrent sessions')
    ..addOption('hive-dir',
        defaultsTo: '/tmp/mpc_load_test_hive', help: 'Hive storage directory')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help');

  final results = parser.parse(argv);
  if (results['help'] as bool) {
    print('MPC Wallet Load Tester\n');
    print(parser.usage);
    exit(0);
  }
  return results;
}

// ---------------------------------------------------------------------------
// Pre-flight checks
// ---------------------------------------------------------------------------

Future<void> _preflightCheck(String serverAddr, String signerHost, int signerPort) async {
  _info('Performing pre-flight connectivity checks…');
  
  // 1. Check Signer
  try {
    final s = await Socket.connect(signerHost, signerPort, timeout: const Duration(seconds: 2));
    await s.close();
    _ok('Signer reachable at $signerHost:$signerPort');
  } catch (e) {
    _err('Cannot reach Signer at $signerHost:$signerPort: $e');
    exit(1);
  }

  // 2. Check gRPC Server
  final parts = serverAddr.split(':');
  final host = parts[0];
  final port = int.parse(parts.length > 1 ? parts[1] : '50051');
  try {
    final s = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
    await s.close();
    _ok('gRPC Server reachable at $host:$port');
  } catch (e) {
    _err('Cannot reach gRPC Server at $host:$port: $e');
    exit(1);
  }
}

// ---------------------------------------------------------------------------
// Per-session logic
// ---------------------------------------------------------------------------

Future<void> runSession({
  required int sessionId,
  required String serverAddress,
  required String signerHost,
  required int signerPort,
}) async {
  final parts = serverAddress.split(':');
  final grpcHost = parts[0];
  final grpcPort = int.parse(parts.length > 1 ? parts[1] : '50051');

  final channel = ClientChannel(
    grpcHost,
    port: grpcPort,
    options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
  );

  final signer = TcpHardwareSigner(host: signerHost, port: signerPort);
  
  final id = '#${sessionId.toString().padLeft(2, '0')}';
  _info('[$id ▶]  Connecting to signer at $signerHost:$signerPort…');
  await signer.connect();

  try {
    final client = MpcClient(
      channel,
      hardwareSigner: signer,
      storageId: 'load_test_session_$sessionId',
    );

    await client.doDkg();
  } finally {
    try {
      await signer.disconnect().timeout(const Duration(seconds: 5));
    } catch (_) {}
    try {
      await channel.terminate();
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Semaphore helper (limits concurrency)
// ---------------------------------------------------------------------------

class _Semaphore {
  final int maxCount;
  int _count = 0;
  final _waiters = <Completer<void>>[];

  _Semaphore(this.maxCount);

  Future<void> acquire() async {
    if (_count < maxCount) {
      _count++;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future;
    _count++;
  }

  void release() {
    _count--;
    if (_waiters.isNotEmpty) {
      final c = _waiters.removeAt(0);
      c.complete();
    }
  }
}

// ---------------------------------------------------------------------------
// Result tracking
// ---------------------------------------------------------------------------

class _Result {
  final int sessionId;
  final Duration elapsed;
  final String? error;

  _Result(this.sessionId, this.elapsed, [this.error]);

  bool get ok => error == null;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

Future<void> main(List<String> argv) async {
  final args = _parseArgs(argv);

  final serverAddress = args['server'] as String;
  final signerHost = args['signer-host'] as String;
  final signerBasePort = int.parse(args['signer-port'] as String);
  final multiSigner = args['multi-signer'] as bool;
  final sessions = int.parse(args['sessions'] as String);
  final concurrency = int.parse(args['concurrency'] as String);
  final hiveDir = args['hive-dir'] as String;

  await Directory(hiveDir).create(recursive: true);
  Hive.init(hiveDir);

  _header('MPC Wallet Dart Load Tester');
  _info('Server      : $serverAddress');
  _info('Signer host : $signerHost  (base port $signerBasePort)');
  _info('Sessions    : $sessions  (concurrency $concurrency)');
  _info('Multi-signer: $multiSigner');
  _sep();

  await _preflightCheck(serverAddress, signerHost, signerBasePort);
  _sep();

  final sem = _Semaphore(concurrency);
  final futures = <Future<_Result>>[];
  final overallStart = DateTime.now();

  for (int i = 0; i < sessions; i++) {
    final signerPort = multiSigner ? (signerBasePort + i) : signerBasePort;

    await sem.acquire();

    final sessionId = i;
    final id = '#${sessionId.toString().padLeft(2, '0')}';
    futures.add(() async {
      final start = DateTime.now();
      String? err;
      try {
        await runSession(
          sessionId: sessionId,
          serverAddress: serverAddress,
          signerHost: signerHost,
          signerPort: signerPort,
        );
        final ms = DateTime.now().difference(start).inMilliseconds;
        _ok('[$id ✓]  Done in ${ms}ms');
      } catch (e) {
        err = e.toString();
        _err('[$id ✗]  FAILED: $err');
      } finally {
        sem.release();
      }
      return _Result(sessionId, DateTime.now().difference(start), err);
    }());
  }

  final results = await Future.wait(futures);
  final totalTime = DateTime.now().difference(overallStart);

  final successes = results.where((r) => r.ok).toList();
  final failures = results.where((r) => !r.ok).toList();

  final latencies = successes.map((r) => r.elapsed.inMilliseconds).toList()
    ..sort();

  _sep();
  _header('Results');

  // Formatted table
  String _row(String label, String value) =>
      '  ${label.padRight(16)} $value';

  final totalSec = (totalTime.inMilliseconds / 1000).toStringAsFixed(2);
  print(_row('Total time',    '${totalSec}s'));
  print(_row('Sessions',      '$sessions'));
  print(_row('Successes',     _c('32', '${successes.length}')));
  print(_row('Failures',
      failures.isEmpty ? '${failures.length}' : _c('31', '${failures.length}')));

  if (latencies.isNotEmpty) {
    final avg = latencies.fold(0, (a, b) => a + b) ~/ latencies.length;
    final p50 = latencies[(latencies.length * 0.50).floor()];
    final p95 = latencies[(latencies.length * 0.95).floor()];
    final p99 = latencies[((latencies.length * 0.99).floor()).clamp(0, latencies.length - 1)];
    _sep();
    print(_row('Latency avg',   '${avg}ms'));
    print(_row('Latency p50',   '${p50}ms'));
    print(_row('Latency p95',   '${p95}ms'));
    print(_row('Latency p99',   '${p99}ms'));
  }

  if (totalTime.inSeconds > 0) {
    final rps = sessions / totalTime.inMilliseconds * 1000;
    print(_row('Sessions/sec',  rps.toStringAsFixed(2)));
  }

  if (failures.isNotEmpty) {
    _sep();
    _err('Failed sessions:');
    for (final f in failures) {
      _err('  [#${f.sessionId.toString().padLeft(2, '0')}] ${f.error}');
    }
    _sep();
    exit(1);
  }

  _sep();
  exit(0);
}
