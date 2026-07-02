import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Create-a-PIN screen for the wallet.
///
/// The PIN gates the FROST signing share for ARK spends (client-side blinding).
/// There is no cloud backup and no recovery — losing this device (or forgetting
/// the PIN) means the wallet is unrecoverable, so we keep the copy honest.
class PinCreateScreen extends StatefulWidget {
  const PinCreateScreen({super.key});

  @override
  State<PinCreateScreen> createState() => _PinCreateScreenState();
}

class _PinCreateScreenState extends State<PinCreateScreen> {
  static const int _pinLength = 6;

  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extras =
        GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
    final pin1 = _pin1.text;
    final pin2 = _pin2.text;
    final longEnough = pin1.length >= _pinLength;
    final match = pin1.isNotEmpty && pin1 == pin2;
    final canContinue = longEnough && match;

    final numeric = <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(_pinLength),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Create PIN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set your spending PIN',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This $_pinLength-digit PIN unlocks your signing key to approve '
              'payments. It stays on this device and never leaves your phone.',
              style: GoogleFonts.inter(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('pinField1'),
              controller: _pin1,
              obscureText: _obscure,
              keyboardType: TextInputType.number,
              inputFormatters: numeric,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'PIN',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              style: GoogleFonts.inter(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('pinField2'),
              controller: _pin2,
              obscureText: _obscure,
              keyboardType: TextInputType.number,
              inputFormatters: numeric,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Confirm PIN'),
              style: GoogleFonts.inter(color: Colors.white),
            ),
            if (pin2.isNotEmpty && !match)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('PINs do not match',
                    style: GoogleFonts.inter(
                        color: Colors.redAccent, fontSize: 12)),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              key: const Key('pinContinueBtn'),
              onPressed: canContinue
                  ? () {
                      context.push('/onboarding/server', extra: {
                        ...extras,
                        'pin': _pin1.text,
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
