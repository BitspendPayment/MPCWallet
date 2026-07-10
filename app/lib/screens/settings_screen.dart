import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:app/services/mpc_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mpc = context.watch<MpcService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 8),
            SwitchListTile(
              value: mpc.offlineModeForced,
              onChanged: (v) => mpc.setOfflineMode(v),
              title: Text('Offline mode (on-chain only)',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: Text(
                'Use only on-chain Bitcoin and hide Ark, even when the Ark '
                'server is reachable. The wallet also switches to this '
                'automatically whenever Ark is unavailable.',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
              ),
              secondary: const Icon(Icons.cloud_off),
            ),
            const Divider(height: 1, color: Colors.white12),
            ListTile(
              leading: Icon(
                mpc.arkAvailable ? Icons.check_circle : Icons.cloud_off,
                color: mpc.arkAvailable ? Colors.greenAccent : Colors.amberAccent,
              ),
              title: Text('Ark server',
                  style: GoogleFonts.inter(color: Colors.white)),
              trailing: Text(
                mpc.offlineModeForced
                    ? 'Disabled'
                    : (mpc.arkAvailable ? 'Available' : 'Unavailable'),
                style: GoogleFonts.inter(
                  color: mpc.arkAvailable && !mpc.offlineModeForced
                      ? Colors.greenAccent
                      : Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
