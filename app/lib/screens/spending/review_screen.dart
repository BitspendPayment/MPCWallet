import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class ReviewScreen extends StatelessWidget {
  final Map<String, dynamic> extras;

  const ReviewScreen({super.key, required this.extras});

  @override
  Widget build(BuildContext context) {
    final address = extras['address'] as String? ?? 'Unknown';
    final amount = extras['amount'] as String? ?? '0';
    final isArk = extras['isArk'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(isArk ? 'Review Ark Send' : 'Review Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDetailRow('Recipient', address),
            const Divider(color: Colors.white24, height: 32),
            _buildDetailRow('Amount', '$amount Sats'),
            const SizedBox(height: 16),
            if (isArk)
              _buildDetailRow('Fee', 'None (off-chain)')
            else ...[
              _buildDetailRow('Network Fee', 'Calculated at signing'),
              const Divider(color: Colors.white24, height: 32),
              _buildDetailRow('Total', '$amount + Fee', isTotal: true),
            ],

            const Spacer(),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isArk ? Colors.blue : Colors.blue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (isArk ? Colors.blueAccent : Colors.blueAccent)
                        .withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(
                    isArk ? Icons.account_tree : Icons.info_outline,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isArk
                          ? 'This is an off-chain Ark transfer. It requires FROST signing.'
                          : 'This transaction requires 2 signatures to be valid.',
                      style: GoogleFonts.inter(
                          color: Colors.blueAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.push('/spending/signing', extra: extras);
              },
              child: Text(isArk ? 'Sign & Send' : 'Sign Transaction'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
