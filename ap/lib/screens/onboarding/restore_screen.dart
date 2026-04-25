import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:client/backup/backup_codec.dart';

import '../../services/mpc_service.dart';

/// Download the encrypted backup from Drive and prompt for the password.
/// On success, seed the software signer and advance to server selection.
class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _downloading = false;
  bool _decrypting = false;
  Uint8List? _blob;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _download());
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    final svc = context.read<MpcService>();
    try {
      final blob = await svc.backupStore.download();
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _blob = blob;
        if (blob == null) {
          _error = 'No backup found in this Google account.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'Download failed: $e';
      });
    }
  }

  Future<void> _decryptAndContinue() async {
    final blob = _blob;
    if (blob == null) return;
    setState(() {
      _decrypting = true;
      _error = null;
    });
    final password = _passwordCtrl.text;
    try {
      // Validate the password by attempting a throwaway decrypt. The actual
      // signer hydration happens inside MpcService.doRestore so the share
      // only lives in RAM for the duration of the re-DKG call.
      await decryptBackup(blob, password);
      if (!mounted) return;
      setState(() => _decrypting = false);
      context.push('/onboarding/server', extra: {
        'isRestore': true,
        'signerKind': 'software',
        'password': password,
        'blob': blob,
      });
    } on BadPasswordException {
      if (!mounted) return;
      setState(() {
        _decrypting = false;
        _error = 'Wrong password.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _decrypting = false;
        _error = 'Restore failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restore Wallet')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_downloading)
              Column(
                children: [
                  const SizedBox(height: 48),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  Text('Downloading backup…',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white70)),
                ],
              )
            else if (_blob == null)
              Column(
                children: [
                  const SizedBox(height: 16),
                  Text(
                    _error ?? 'No backup available.',
                    style: GoogleFonts.inter(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _download,
                    child: const Text('Retry'),
                  ),
                ],
              )
            else ...[
              Text(
                'Unlock your backup',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the password you used when you first set up this '
                'wallet.',
                style: GoogleFonts.inter(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                style: GoogleFonts.inter(color: Colors.white),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style: GoogleFonts.inter(color: Colors.redAccent)),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _decrypting || _passwordCtrl.text.isEmpty
                    ? null
                    : _decryptAndContinue,
                child: _decrypting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
