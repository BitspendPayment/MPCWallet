import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/mpc_service.dart';

/// Google Drive sign-in step of the software-signer onboarding flow.
///
/// Used in two modes:
///   * create flow — sign in so the post-DKG hook uploads a backup blob.
///     Skippable (local-only) with an explicit warning.
///   * restore flow — sign in is required because we need to download the
///     existing backup. Skip button is hidden.
class GoogleSignInScreen extends StatefulWidget {
  const GoogleSignInScreen({super.key});

  @override
  State<GoogleSignInScreen> createState() => _GoogleSignInScreenState();
}

class _GoogleSignInScreenState extends State<GoogleSignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn(Map<String, dynamic> extras) async {
    final isRestore = extras['isRestore'] == true;
    setState(() {
      _busy = true;
      _error = null;
    });
    final svc = context.read<MpcService>();
    bool ok = false;
    try {
      ok = await svc.backupStore.signIn();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _error = 'Sign-in cancelled.');
      return;
    }
    if (isRestore) {
      context.push('/onboarding/restore', extra: extras);
    } else {
      context.push('/onboarding/server', extra: extras);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extras =
        GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
    final isRestore = extras['isRestore'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Google Drive Backup')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isRestore ? 'Restore from Drive' : 'Back up to Drive',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isRestore
                  ? 'Sign in to the Google account that has your encrypted '
                      'wallet backup.'
                  : 'Your encrypted signing key will be stored in a hidden '
                      'folder in your Google Drive. Only this app can read it.',
              style: GoogleFonts.inter(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 32),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: GoogleFonts.inter(color: Colors.redAccent)),
              ),
            ElevatedButton.icon(
              onPressed: _busy ? null : () => _signIn(extras),
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud),
              label: Text(_busy ? 'Signing in...' : 'Sign in with Google'),
            ),
            const Spacer(),
            if (!isRestore)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _confirmSkip(context, extras),
                child: Text(
                  'Skip (local-only, no backup)',
                  style: GoogleFonts.inter(
                      color: Colors.white54, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSkip(
      BuildContext context, Map<String, dynamic> extras) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip backup?'),
        content: const Text(
          'Without a Drive backup, losing this device means losing access to '
          'your wallet. There is no way to recover from a lost phone.\n\n'
          'You can enable Drive backup later in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Skip anyway'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.push('/onboarding/server', extra: extras);
    }
  }
}
