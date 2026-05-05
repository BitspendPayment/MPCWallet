import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/mpc_service.dart';

/// Network values must match what `parseBitcoinNetwork` accepts in
/// `app-core/lib/bitcoin.dart`. Adding one here without updating that switch
/// will silently fall through to regtest and mis-encode addresses.
const _networks = <(String value, String label)>[
  ('mainnet', 'Mainnet'),
  ('testnet', 'Testnet'),
  ('signet', 'Signet'),
  ('mutinynet', 'Mutinynet'),
  ('regtest', 'Regtest (local dev)'),
];

class NetworkSettingsScreen extends StatefulWidget {
  const NetworkSettingsScreen({super.key});

  @override
  State<NetworkSettingsScreen> createState() => _NetworkSettingsScreenState();
}

class _NetworkSettingsScreenState extends State<NetworkSettingsScreen> {
  late String _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = context.read<MpcService>().network;
  }

  Future<void> _save() async {
    final svc = context.read<MpcService>();
    if (_selected == svc.network) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await svc.setNetwork(_selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network changed to $_selected')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = context.watch<MpcService>().network;
    return Scaffold(
      appBar: AppBar(title: const Text('Network')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bitcoin Network',
              style:
                  GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Currently: $current',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selected,
              decoration: const InputDecoration(
                labelText: 'Bitcoin Network',
                prefixIcon: Icon(Icons.public),
              ),
              dropdownColor: const Color(0xFF1E1E1E),
              style: GoogleFonts.inter(color: Colors.white),
              items: [
                for (final (value, label) in _networks)
                  DropdownMenuItem(value: value, child: Text(label)),
              ],
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v != null) setState(() => _selected = v);
                    },
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: GoogleFonts.inter(
                  color: Colors.redAccent,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Changing the network rebuilds the wallet so receive addresses '
              'render with the correct prefix (e.g. bcrt1… vs tb1…). Switching '
              'to a network the cosigning server is not actually on will give '
              'you addresses that look valid but cannot receive funds.',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
