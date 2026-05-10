import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Create-a-password screen for the software signer path.
///
/// Enforces ~50 bits of entropy before letting the user proceed. If the user
/// forgets this password, the Drive backup is unrecoverable — we surface
/// that fact prominently.
class PasswordCreateScreen extends StatefulWidget {
  const PasswordCreateScreen({super.key});

  @override
  State<PasswordCreateScreen> createState() => _PasswordCreateScreenState();
}

class _PasswordCreateScreenState extends State<PasswordCreateScreen> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _obscure = true;
  bool _acknowledged = false;

  @override
  void dispose() {
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  double _entropyBits(String s) {
    if (s.isEmpty) return 0;
    int pool = 0;
    if (s.contains(RegExp(r'[a-z]'))) pool += 26;
    if (s.contains(RegExp(r'[A-Z]'))) pool += 26;
    if (s.contains(RegExp(r'[0-9]'))) pool += 10;
    if (s.contains(RegExp(r'[^A-Za-z0-9]'))) pool += 32;
    if (pool == 0) return 0;
    return s.length * (log(pool) / log(2));
  }

  @override
  Widget build(BuildContext context) {
    final extras =
        GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
    final pw1 = _pw1.text;
    final pw2 = _pw2.text;
    final bits = _entropyBits(pw1);
    final strong = bits >= 50;
    final match = pw1.isNotEmpty && pw1 == pw2;
    final canContinue = strong && match && _acknowledged;

    final barColor = bits < 30
        ? Colors.redAccent
        : bits < 50
            ? Colors.orangeAccent
            : Colors.greenAccent;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Password')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Protect your signing key',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This password encrypts your signing key on this device and in '
              'the Google Drive backup. It never leaves your phone.',
              style: GoogleFonts.inter(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('passwordField1'),
              controller: _pw1,
              obscureText: _obscure,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              style: GoogleFonts.inter(color: Colors.white),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (bits / 80).clamp(0.0, 1.0),
              color: barColor,
              backgroundColor: Colors.white12,
              minHeight: 4,
            ),
            const SizedBox(height: 4),
            Text(
              strong
                  ? 'Strength: strong'
                  : bits < 30
                      ? 'Strength: weak'
                      : 'Strength: fair — aim for stronger',
              style: GoogleFonts.inter(color: barColor, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('passwordField2'),
              controller: _pw2,
              obscureText: _obscure,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Confirm password'),
              style: GoogleFonts.inter(color: Colors.white),
            ),
            if (pw2.isNotEmpty && !match)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Passwords do not match',
                    style: GoogleFonts.inter(
                        color: Colors.redAccent, fontSize: 12)),
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    key: const Key('passwordAckCheckbox'),
                    value: _acknowledged,
                    onChanged: (v) =>
                        setState(() => _acknowledged = v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'I understand that if I lose this password, my Drive '
                      'backup cannot be recovered and my funds may be lost.',
                      style: GoogleFonts.inter(
                          color: Colors.redAccent.shade100, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              key: const Key('passwordContinueBtn'),
              onPressed: canContinue
                  ? () {
                      context.push('/onboarding/google-signin', extra: {
                        ...extras,
                        'password': _pw1.text,
                        'signerKind': 'software',
                      });
                    }
                  : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
