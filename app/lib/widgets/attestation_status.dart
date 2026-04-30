import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_core/enclave/native_enclave.dart' show AttestationStatus;

/// Displays the enclave attestation verification status.
///
/// Shows PCR0, verification state (verified/unverified/verifying),
/// and a countdown timer to the next attestation check.
class AttestationStatusWidget extends StatefulWidget {
  /// Async function to poll the current attestation status.
  final Future<AttestationStatus?> Function() statusProvider;

  const AttestationStatusWidget({super.key, required this.statusProvider});

  @override
  State<AttestationStatusWidget> createState() =>
      _AttestationStatusWidgetState();
}

class _AttestationStatusWidgetState extends State<AttestationStatusWidget> {
  Timer? _timer;
  AttestationStatus? _status;

  @override
  void initState() {
    super.initState();
    _pollStatus();
    // Refresh every second for the countdown timer.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _pollStatus());
  }

  void _pollStatus() async {
    final newStatus = await widget.statusProvider();
    if (mounted) {
      setState(() => _status = newStatus);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    if (status == null) {
      return const SizedBox.shrink();
    }

    final verified = status.verified;
    final pcr0 = status.pcr0;
    final remaining = status.ttlRemainingSecs;
    final error = status.error;

    final Color bgColor;
    final Color iconColor;
    final IconData icon;
    final String label;

    if (error != null && error.isNotEmpty) {
      bgColor = Colors.red.shade50;
      iconColor = Colors.red;
      icon = Icons.error_outline;
      label = 'Unverified';
    } else if (verified) {
      bgColor = Colors.green.shade50;
      iconColor = Colors.green;
      icon = Icons.verified_user;
      label = 'Verified';
    } else {
      bgColor = Colors.orange.shade50;
      iconColor = Colors.orange;
      icon = Icons.hourglass_top;
      label = 'Verifying...';
    }

    final pcr0Short = pcr0.length > 16
        ? '${pcr0.substring(0, 8)}...${pcr0.substring(pcr0.length - 8)}'
        : pcr0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Enclave $label',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (verified && remaining > 0)
                      Text(
                        '${remaining}s',
                        style: TextStyle(
                          color: iconColor.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                if (pcr0.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'PCR0: $pcr0Short',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                if (error != null && error.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    error,
                    style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
