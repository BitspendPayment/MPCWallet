import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/mpc_service.dart';

class ServerConnectionScreen extends StatefulWidget {
  const ServerConnectionScreen({super.key});

  @override
  State<ServerConnectionScreen> createState() => _ServerConnectionScreenState();
}

class _ServerConnectionScreenState extends State<ServerConnectionScreen> {
  late final TextEditingController _urlController;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // Physical device with USB signer uses ADB reverse → 127.0.0.1
    _urlController = TextEditingController(text: '127.0.0.1');
  }

  void _connect() async {
    final extras = GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};

    setState(() {
      _isChecking = true;
    });

    final host = _urlController.text.trim();
    if (host.isNotEmpty) {
      await context.read<MpcService>().setHost(host);
    }

    // Simulate network check (or in real app, we might check connectivity here)
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _isChecking = false;
      });
      // Forward signerKind / password / isRestore to the DKG screen.
      context.push('/onboarding/dkg', extra: extras);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Server')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Co-signing Server',
              style:
                  GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the URL of the MPC co-signing server.',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('serverUrlField'),
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Server Host / IP',
                prefixIcon: Icon(Icons.dns),
                hintText: 'e.g. 10.0.2.2 or 192.168.1.x',
              ),
              style: GoogleFonts.inter(color: Colors.white),
            ),
            const Spacer(),
            ElevatedButton(
              key: const Key('serverConnectBtn'),
              onPressed: _isChecking ? null : _connect,
              child: _isChecking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect & Start DKG'),
            ),
          ],
        ),
      ),
    );
  }
}
