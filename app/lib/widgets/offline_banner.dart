import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:app/services/mpc_service.dart';

/// A slim banner shown while the wallet is in offline (on-chain-only) mode.
/// Renders nothing when Ark is available and offline mode isn't forced.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final mpc = context.watch<MpcService>();
    if (!mpc.offlineMode) return const SizedBox.shrink();

    final subtitle = mpc.offlineModeForced
        ? 'Enabled in Settings — Ark is hidden.'
        : 'Ark server unavailable — reconnecting…';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF3A2E00),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: Colors.amberAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline mode — on-chain Bitcoin only',
                  style: GoogleFonts.inter(
                    color: Colors.amberAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
