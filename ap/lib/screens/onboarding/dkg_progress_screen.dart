import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/mpc_service.dart';
import '../../widgets/stepper_widget.dart';

class DkgProgressScreen extends StatefulWidget {
  const DkgProgressScreen({super.key});

  @override
  State<DkgProgressScreen> createState() => _DkgProgressScreenState();
}

class _DkgProgressScreenState extends State<DkgProgressScreen> {
  int _currentStep = 0;
  final List<String> _steps = ['Session', 'Generate', 'Finalize'];
  final List<String> _logs = [];
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _startDkg();
    }
  }

  void _startDkg() async {
    final mpcService = context.read<MpcService>();
    final extras = GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
    final isRestore = extras['isRestore'] == true;
    final signerKindStr = extras['signerKind'] as String? ?? 'software';
    final signerKind = signerKindStr == 'hardware'
        ? SignerKind.hardware
        : SignerKind.software;
    final password = extras['password'] as String?;
    final blob = extras['blob'] as Uint8List?;

    // Wait for Init
    if (!mpcService.isInitialized) {
      await _addLog('Client init failed or slow. Retrying...');
    }

    // Record which signer backend is in use. Software signer password is
    // passed directly to doDkg / doRestore below — never cached in the service.
    try {
      await mpcService.setSignerKind(signerKind);
    } catch (e) {
      await _addLog('Failed to set signer: $e');
      return;
    }

    await _addLog('Connected to server.');
    setState(() => _currentStep = 0);

    try {
      if (isRestore) {
        await _addLog('Restoring wallet...');
      } else {
        await _addLog('Starting Distributed Key Generation...');
      }
      setState(() => _currentStep = 1);

      await Future.delayed(const Duration(milliseconds: 500)); // UI pacing
      await _addLog(isRestore
          ? 'Re-deriving shares from stored secrets...'
          : 'Generating secrets and exchanging packages...');

      if (isRestore) {
        await mpcService.doRestore(blob: blob, password: password);
      } else {
        await mpcService.doDkg(password: password);
      }

      await _addLog(isRestore
          ? 'Wallet restored successfully.'
          : 'DKG Finalized successfully.');
      setState(() => _currentStep = 2);
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        context.push('/onboarding/ready');
      }
    } catch (e) {
      await _addLog('Error: $e');
    }
  }

  Future<void> _addLog(String message) async {
    if (mounted) {
      setState(() {
        _logs.add(message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final extras = GoRouterState.of(context).extra as Map<String, dynamic>? ?? {};
    final isRestore = extras['isRestore'] == true;

    return Scaffold(
      appBar: AppBar(title: Text(isRestore ? 'Restoring Wallet' : 'Creating Wallet')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              DkgStepper(currentStep: _currentStep, steps: _steps),
              const SizedBox(height: 32),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '> ${_logs[index]}',
                          style: GoogleFonts.firaCode(
                            fontSize: 12,
                            color: Colors.greenAccent,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_currentStep < 2)
                const CircularProgressIndicator(color: Colors.white)
              else
                const Icon(Icons.check_circle,
                    color: Colors.greenAccent, size: 48),
            ],
          ),
        ),
      ),
    );
  }
}
