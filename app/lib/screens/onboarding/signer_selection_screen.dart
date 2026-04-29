import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/mpc_service.dart';

class SignerSelectionScreen extends StatefulWidget {
  const SignerSelectionScreen({super.key});

  @override
  State<SignerSelectionScreen> createState() => _SignerSelectionScreenState();
}

class _SignerSelectionScreenState extends State<SignerSelectionScreen> {
  SignerKind _selected = SignerKind.software;

  @override
  Widget build(BuildContext context) {
    final extras = GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
    final isRestore = extras['isRestore'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Signer')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Where is your signing key?',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This is the key that authorizes spending from your wallet.',
              style: GoogleFonts.inter(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 24),
            _SignerCard(
              selected: _selected == SignerKind.software,
              icon: Icons.phone_iphone,
              title: 'Software Signer',
              subtitle: 'Key lives on this device, encrypted with a password and '
                  'backed up to your Google Drive.',
              badge: 'Recommended',
              onTap: () => setState(() => _selected = SignerKind.software),
            ),
            const SizedBox(height: 12),
            _SignerCard(
              selected: _selected == SignerKind.hardware,
              icon: Icons.usb,
              title: 'Hardware Signer (USB)',
              subtitle: 'Key stays on a physical device. Highest security. '
                  'Requires a USB connection for every signing.',
              onTap: () => setState(() => _selected = SignerKind.hardware),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Software signer is more convenient but your key sits in '
                      'app memory while signing. Hardware signer keeps the key '
                      'isolated at all times.',
                      style: GoogleFonts.inter(
                          color: Colors.amber.shade100, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _continue(isRestore),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  void _continue(bool isRestore) {
    if (_selected == SignerKind.software) {
      if (isRestore) {
        // Restore flow needs Drive sign-in first (download blob).
        context.push('/onboarding/google-signin',
            extra: {'isRestore': true});
      } else {
        context.push('/onboarding/password',
            extra: {'isRestore': false});
      }
    } else {
      // Hardware path: skip password/drive entirely.
      context.push('/onboarding/server',
          extra: {'isRestore': isRestore, 'signerKind': 'hardware'});
    }
  }
}

class _SignerCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _SignerCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? Colors.blueAccent.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.blueAccent : Colors.white12,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? Colors.blueAccent : Colors.white70, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(badge!,
                              style: GoogleFonts.inter(
                                  color: Colors.greenAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          color: Colors.white54, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
