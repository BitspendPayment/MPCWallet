import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.black,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Merlin Wallet',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Secure 2-of-3 Multi-Party Computation Bitcoin Wallet.\n\nYou hold 2 keys (Spending + Recovery).\nThe server holds 1 share to co-sign.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  context.push('/onboarding/signer-selection');
                },
                child: const Text('Create MPC Wallet'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  context.push('/onboarding/signer-selection',
                      extra: {'isRestore': true});
                },
                child: Text(
                  'Restore existing wallet',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
