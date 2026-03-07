/// Shared logger for MPC Wallet E2E tests and tools.
///
/// Provides timestamped, colour-coded output:
///   Log.header('Setup')           → bold banner
///   Log.step(1, 'MPC Setup')      → numbered step
///   Log.info('message')           → cyan INFO
///   Log.ok('DKG Complete')        → green OK
///   Log.warn('retrying...')       → yellow WARN
///   Log.error('failed')           → red ERROR
///   Log.server(line)              → grey [server] prefix
///   Log.debug('verbose detail')   → dark grey DEBUG
library logger;

import 'dart:io';

class Log {
  // ---------------------------------------------------------------------------
  // ANSI helpers (disabled automatically when stdout is not a TTY)
  // ---------------------------------------------------------------------------
  static final bool _color = stdout.supportsAnsiEscapes;

  static String _c(String code, String text) =>
      _color ? '\x1B[${code}m$text\x1B[0m' : text;

  static String _bold(String t) => _c('1', t);
  static String _grey(String t) => _c('90', t);
  static String _cyan(String t) => _c('36', t);
  static String _green(String t) => _c('32', t);
  static String _yellow(String t) => _c('33', t);
  static String _red(String t) => _c('31', t);
  static String _magenta(String t) => _c('35', t);
  static String _darkGrey(String t) => _c('2;37', t);

  // ---------------------------------------------------------------------------
  // Timestamp  HH:MM:SS
  // ---------------------------------------------------------------------------
  static String get _ts {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return _grey('$h:$m:$s');
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Bold banner, e.g. ── Setup ────────────────────────────────
  static void header(String title) {
    const width = 50;
    final line = '── $title ' + '─' * (width - title.length - 4);
    print(_bold(line));
  }

  /// Numbered step line, e.g.  ❯ [1] MPC Setup
  static void step(int n, String label) {
    final num = _magenta('[${n.toString().padLeft(2)}]');
    final arrow = _bold('❯');
    print('$_ts $arrow $num ${_bold(label)}');
  }

  /// Informational message.
  static void info(String msg) {
    print('$_ts ${_cyan('INFO')}  $msg');
  }

  /// Success / completion message.
  static void ok(String msg) {
    print('$_ts ${_green(' OK ')}  $msg');
  }

  /// Warning / retry message.
  static void warn(String msg) {
    print('$_ts ${_yellow('WARN')}  $msg');
  }

  /// Error message.
  static void error(String msg) {
    stderr.writeln('$_ts ${_red('ERR ')}  $msg');
  }

  /// Output from the Rust server subprocess (filtered and dedented).
  static void server(String raw) {
    // Split multi-line chunks the process delivers at once
    final lines = raw.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      print('$_ts ${_darkGrey('[server]')} $trimmed');
    }
  }

  /// Debug / verbose detail (only shown when LOG_DEBUG env var is set).
  static void debug(String msg) {
    if (Platform.environment.containsKey('LOG_DEBUG')) {
      print('$_ts ${_darkGrey('DBG ')}  ${_darkGrey(msg)}');
    }
  }

  // ---------------------------------------------------------------------------
  // Section separator
  // ---------------------------------------------------------------------------

  /// Light horizontal rule.
  static void separator() {
    print(_grey('─' * 54));
  }
}
