import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app/services/mpc_service.dart';

class ArkSendScreen extends StatefulWidget {
  const ArkSendScreen({super.key});

  @override
  State<ArkSendScreen> createState() => _ArkSendScreenState();
}

class _ArkSendScreenState extends State<ArkSendScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _send() {
    final address = _addressController.text.trim();
    final amountText = _amountController.text.trim();

    if (address.isEmpty || amountText.isEmpty) {
      setState(() => _error = 'Please fill all fields');
      return;
    }

    if (!address.startsWith('tark1') && !address.startsWith('ark1')) {
      setState(() => _error = 'Invalid Ark address (must start with ark1 or tark1)');
      return;
    }

    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Invalid amount');
      return;
    }

    final mpcService = context.read<MpcService>();
    if (amount > mpcService.arkBalance.toInt()) {
      setState(() => _error = 'Insufficient Ark balance');
      return;
    }

    // Navigate to signing screen with 3-step Build → Sign → Submit flow
    context.push('/spending/signing', extra: {
      'isArk': true,
      'address': address,
      'amount': amountText,
    });
  }

  @override
  Widget build(BuildContext context) {
    final mpcService = context.watch<MpcService>();
    final arkBalance = mpcService.arkBalance;
    final formattedBalance = NumberFormat('#,###').format(arkBalance.toInt());

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Send (Ark)',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('arkSendAddressField'),
              controller: _addressController,
              enabled: true,
              decoration: InputDecoration(
                labelText: 'Recipient Ark Address',
                hintText: 'tark1...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () {},
                ),
              ),
              style: GoogleFonts.inter(),
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('arkSendAmountField'),
              controller: _amountController,
              enabled: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                suffixText: 'Sats',
              ),
              style: GoogleFonts.inter(fontSize: 24),
            ),
            const SizedBox(height: 16),
            Text(
              'Available Ark Balance: $formattedBalance Sats',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ],
            const Spacer(),
            ElevatedButton(
                key: const Key('arkSendVtxoBtn'),
                onPressed: _send,
                child: const Text('Send VTXO'),
              ),
          ],
        ),
      ),
    );
  }
}
