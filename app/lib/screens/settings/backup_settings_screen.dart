import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/mpc_service.dart';
import '../../widgets/recovery_password_dialog.dart';

/// Settings panel for the software-signer Google Drive backup.
///
/// Shown when the wallet is using the software signer. Lets the user
/// inspect last-backup time, re-upload, and sign in/out of Drive.
class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  DateTime? _lastModified;
  bool _loading = true;
  bool _working = false;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final svc = context.read<MpcService>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!svc.backupStore.isSignedIn) {
        await svc.backupStore.signInSilently();
      }
      final mod = svc.backupStore.isSignedIn
          ? await svc.backupStore.lastModified()
          : null;
      if (!mounted) return;
      setState(() {
        _lastModified = mod;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _signIn() async {
    final svc = context.read<MpcService>();
    setState(() {
      _working = true;
      _error = null;
      _status = null;
    });
    try {
      final ok = await svc.backupStore.signIn();
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _working = false;
          _error = 'Sign-in cancelled.';
        });
        return;
      }
      await _refresh();
      if (!mounted) return;
      setState(() => _working = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = '$e';
      });
    }
  }

  Future<void> _uploadNow() async {
    // Capture context-derived references before the password prompt so we
    // never re-read context after async gaps.
    final svc = context.read<MpcService>();
    final password = await promptRecoveryPassword(
      context,
      hint: 'Re-encrypts and re-uploads the current backup with fresh '
          'salt and nonce.',
    );
    if (!mounted) return;
    if (password == null || password.isEmpty) return;
    setState(() {
      _working = true;
      _error = null;
      _status = null;
    });
    try {
      await svc.uploadBackupNow(password: password);
      await _refresh();
      if (!mounted) return;
      setState(() {
        _working = false;
        _status = 'Backup uploaded.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = '$e';
      });
    }
  }

  Future<void> _signOut() async {
    final svc = context.read<MpcService>();
    setState(() => _working = true);
    try {
      await svc.backupStore.signOut();
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _lastModified = null;
          _status = null;
          _error = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MpcService>();
    final isSoftware = svc.signerKind == SignerKind.software;
    final accountLabel = svc.backupStore.accountLabel;

    return Scaffold(
      appBar: AppBar(title: const Text('Drive Backup')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: !isSoftware
            ? Center(
                child: Text(
                  'Your wallet is using the hardware signer. Drive backup is '
                  'not used in this mode.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row('Google account', accountLabel ?? 'Not signed in'),
                  const SizedBox(height: 8),
                  _row(
                    'Last backup',
                    _loading
                        ? 'Checking…'
                        : _lastModified == null
                            ? 'No backup found'
                            : _lastModified!.toLocal().toString(),
                  ),
                  const SizedBox(height: 24),
                  if (_status != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_status!,
                          style: GoogleFonts.inter(color: Colors.greenAccent)),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!,
                          style: GoogleFonts.inter(color: Colors.redAccent)),
                    ),
                  if (!svc.backupStore.isSignedIn)
                    ElevatedButton.icon(
                      onPressed: _working ? null : _signIn,
                      icon: const Icon(Icons.cloud),
                      label: const Text('Sign in with Google'),
                    )
                  else ...[
                    ElevatedButton.icon(
                      onPressed: _working ? null : _uploadNow,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Re-upload backup now'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _working ? null : _signOut,
                      child: Text('Sign out',
                          style: GoogleFonts.inter(color: Colors.white70)),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
