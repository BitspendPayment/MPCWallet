import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/mpc_service.dart';

/// Post-DKG onboarding step: create the passkey that gates spending.
///
/// The passkey's PRF output blinds the FROST signing share, so every payment
/// needs a fresh biometric/screen-lock gesture. Registration needs the DKG'd
/// user id, which is why this step comes after DKG rather than before.
/// Skipping leaves the wallet un-gated (legacy Schnorr auth); it can be
/// retried here since [MpcService.enablePasskey] is idempotent-safe.
class PasskeySetupScreen extends StatefulWidget {
  const PasskeySetupScreen({super.key});

  @override
  State<PasskeySetupScreen> createState() => _PasskeySetupScreenState();
}

class _PasskeySetupScreenState extends State<PasskeySetupScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _createPasskey() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<MpcService>().enablePasskey();
      if (mounted) context.push('/onboarding/ready');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(
                child: Icon(Icons.fingerprint, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 32),
              Text(
                'Secure your wallet',
                style:
                    GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Create a passkey to lock your signing key. Every payment will '
                'ask for your fingerprint, face, or screen lock — nothing to '
                'remember, nothing that can be guessed.',
                style: GoogleFonts.inter(
                    color: Colors.white70, fontSize: 16, height: 1.5),
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Passkey setup failed: $_error',
                    style: GoogleFonts.inter(
                        color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],
              const Spacer(),
              ElevatedButton(
                key: const Key('passkeyCreateBtn'),
                onPressed: _busy ? null : _createPasskey,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_error == null ? 'Create passkey' : 'Try again'),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('passkeySkipBtn'),
                onPressed:
                    _busy ? null : () => context.push('/onboarding/ready'),
                child: Text(
                  'Skip for now (payments won\'t require a passkey)',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
