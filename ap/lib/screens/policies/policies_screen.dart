import 'package:client/policy.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/mpc_service.dart';



class PoliciesScreen extends StatefulWidget {
  const PoliciesScreen({super.key});

  @override
  State<PoliciesScreen> createState() => _PoliciesScreenState();
}

class _PoliciesScreenState extends State<PoliciesScreen> {
  bool _isDeleting = false;

  String _formatInterval(Duration interval) {
    if (interval.inDays >= 7) return '${interval.inDays ~/ 7} Week(s)';
    if (interval.inDays >= 1) return '${interval.inDays} Day(s)';
    if (interval.inHours >= 1) return '${interval.inHours} Hour(s)';
    return '${interval.inMinutes} Minute(s)';
  }

  Future<void> _deletePolicy(String policyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Delete Policy',
            style: GoogleFonts.inter(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'This will permanently remove this spending policy. '
              'Both your signing and recovery keys will be used to authorize this action.',
              style: GoogleFonts.inter(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final mpcService = context.read<MpcService>();
      await mpcService.client!.deletePolicy(policyId);
      mpcService.policyUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Policy deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        final isHardwareError = e.toString().contains('No HW Signer device found') ||
            e.toString().contains('USB') ||
            e.toString().contains('transport');
        if (isHardwareError) {
          final retry = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              icon: const Icon(Icons.usb_off, color: Colors.amber, size: 48),
              title: Text(
                'Hardware Key Required',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Connect your HW Signer via USB OTG, then tap Retry.',
                style: GoogleFonts.inter(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
          if (retry == true && mounted) {
            try {
              await context.read<MpcService>().reconnectHardwareSigner();
              _deletePolicy(policyId);
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Still unable to connect. Check your device.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mpcService = context.watch<MpcService>();
    final policies = mpcService.policies;

    return Scaffold(
      appBar: AppBar(title: const Text('Spending Policies')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scope banner
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.blueAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Policies apply to all transactions — both on-chain Bitcoin and off-chain Ark sends.',
                      style: GoogleFonts.inter(
                          color: Colors.blueAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            if (policies.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      Text('No Spending Policies',
                          style: GoogleFonts.inter(
                              fontSize: 18, color: Colors.white54)),
                      const SizedBox(height: 8),
                      Text(
                          'Add a policy to set spending limits that require PIN authorization for Bitcoin and Ark transactions.',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.white24),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: policies.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _buildPolicyTile(context, policies[index], index + 1),
                ),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Modifying or removing policies requires the Recovery Key.',
                      style:
                          GoogleFonts.inter(color: Colors.amber, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                context.push('/policies/edit');
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Policy'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyTile(
      BuildContext context, ProtectedPolicy policy, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Policy $index',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Active',
                    style:
                        GoogleFonts.inter(color: Colors.green, fontSize: 10)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.white54, size: 20),
                tooltip: 'Edit Policy',
                onPressed: _isDeleting
                    ? null
                    : () => context
                        .push('/policies/edit', extra: {'policyId': policy.id}),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 20),
                tooltip: 'Delete Policy',
                onPressed: _isDeleting ? null : () => _deletePolicy(policy.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            children: [
              Expanded(
                child: _buildDetail(
                  'Threshold',
                  '${NumberFormat('#,###').format(policy.thresholdSats)} Sats',
                ),
              ),
              Expanded(
                child: _buildDetail(
                  'Interval',
                  _formatInterval(policy.interval),
                ),
              ),
              Expanded(
                child: _buildDetail('PIN', 'Set'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}
