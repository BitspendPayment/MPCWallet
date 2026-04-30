import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/mpc_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkWalletState();
  }

  Future<void> _checkWalletState() async {
    final mpcService = context.read<MpcService>();

    // Wait for init() to finish loading persisted config from Hive
    await mpcService.initFuture;

    if (!mounted) return;

    if (mpcService.dkgComplete) {
      // Keys exist — restore session and go to home
      try {
        await mpcService.restoreSession();
      } catch (e) {
        // Session restore failed — will start in disconnected state
        print("Session restore failed: $e — falling back to onboarding");
      }
      if (mounted) context.go('/');
    } else {
      // No keys — start onboarding
      if (mounted) context.go('/onboarding/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.black,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Merlin Wallet',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
