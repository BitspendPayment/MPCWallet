import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SignerSelectionScreen extends StatelessWidget {
  const SignerSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final extras = GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
    final isRestore = extras['isRestore'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Recovery Signer')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hardware Signer',
              style:
                  GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your recovery key is managed by an external signing device.\n'
              'Connect your hardware signer via USB to continue.',
              style: GoogleFonts.inter(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.usb,
                      color: Colors.blueAccent, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hardware Signer (USB)',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('Connect a hardware signing device via USB',
                            style: GoogleFonts.inter(
                                color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.push('/onboarding/server',
                  extra: {'isRestore': isRestore}),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
