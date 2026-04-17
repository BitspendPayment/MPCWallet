import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../../services/mpc_service.dart';

class EditPolicyScreen extends StatefulWidget {
  final Map<String, dynamic>? extras;
  const EditPolicyScreen({super.key, this.extras});

  @override
  State<EditPolicyScreen> createState() => _EditPolicyScreenState();
}

class _EditPolicyScreenState extends State<EditPolicyScreen> {
  static const double _minSats = 10000; // 10k sats
  static const double _maxSats = 1000000000; // 10 BTC

  bool _isSigning = false;
  double _sliderValue = 0.5; // 0.0–1.0, maps logarithmically
  String _interval = '24h';

  /// Non-null when editing an existing policy
  String? _editingPolicyId;
  bool get _isEditMode => _editingPolicyId != null;

  int get _thresholdSats => pow(
          10,
          log(_minSats) / ln10 +
              _sliderValue * (log(_maxSats) / ln10 - log(_minSats) / ln10))
      .round();

  double _satsToSlider(double sats) {
    final clamped = sats.clamp(_minSats, _maxSats);
    return (log(clamped) / ln10 - log(_minSats) / ln10) /
        (log(_maxSats) / ln10 - log(_minSats) / ln10);
  }

  String _intervalFromDuration(Duration d) {
    if (d.inDays >= 7) return '7d';
    if (d.inHours >= 24) return '24h';
    if (d.inHours >= 1) return '1h';
    return '5m';
  }

  @override
  void initState() {
    super.initState();
    final extras = widget.extras;
    final policyId = extras?['policyId'] as String?;

    if (policyId != null) {
      // Edit mode: load from the specific policy
      final policies = context.read<MpcService>().policies;
      final policy = policies.where((p) => p.id == policyId).firstOrNull;
      if (policy != null) {
        _editingPolicyId = policyId;
        _sliderValue = _satsToSlider(policy.thresholdSats.toDouble());
        _interval = _intervalFromDuration(policy.interval);
      }
    } else {
      // Create mode: pre-populate from active policy if one exists
      final policy = context.read<MpcService>().activePolicy;
      if (policy != null) {
        _sliderValue = _satsToSlider(policy.thresholdSats.toDouble());
        _interval = _intervalFromDuration(policy.interval);
      }
    }
  }

  Duration get _selectedDuration {
    switch (_interval) {
      case '5m':
        return const Duration(minutes: 5);
      case '1h':
        return const Duration(hours: 1);
      case '7d':
        return const Duration(days: 7);
      case '24h':
      default:
        return const Duration(hours: 24);
    }
  }

  void _savePolicy() async {
    final mpcService = context.read<MpcService>();
    if (mpcService.client == null) return;

    // Check for duplicate threshold + interval
    final duplicate = mpcService.policies.any((p) =>
        p.id != _editingPolicyId &&
        p.thresholdSats == _thresholdSats &&
        p.interval.inSeconds == _selectedDuration.inSeconds);
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A policy with this threshold and interval already exists.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isEditMode) {
      await _updatePolicy(mpcService);
    } else {
      await _createPolicy(mpcService);
    }
  }

  Future<void> _createPolicy(MpcService mpcService) async {
    String? pin = await _showAuthDialog();
    if (pin == null || pin.isEmpty) return;

    setState(() => _isSigning = true);
    try {
      await mpcService.client!.createSpendingPolicy(
          _selectedDuration, Int64(_thresholdSats), pin);
      mpcService.policyUpdated();

      if (mounted) {
        setState(() => _isSigning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Policy created successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSigning = false);
        _showErrorFeedback(e);
      }
    }
  }

  Future<void> _updatePolicy(MpcService mpcService) async {
    setState(() => _isSigning = true);
    try {
      await mpcService.client!.updatePolicy(
        _editingPolicyId!,
        thresholdSats: _thresholdSats,
        intervalSeconds: _selectedDuration.inSeconds,
      );
      mpcService.policyUpdated();

      if (mounted) {
        setState(() => _isSigning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Policy updated successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSigning = false);
        _showErrorFeedback(e);
      }
    }
  }

  Future<void> _showErrorFeedback(Object e) async {
    final msg = e.toString();
    final isHardwareError = msg.contains('No HW Signer device found') ||
        msg.contains('USB') ||
        msg.contains('transport');
    if (isHardwareError) {
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          icon: const Icon(Icons.usb_off, color: Colors.amber, size: 48),
          title: Text('Hardware Key Required',
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
              'Connect your HW Signer via USB OTG, then tap Retry.',
              style: GoogleFonts.inter(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel',
                    style: GoogleFonts.inter(color: Colors.white54))),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Retry')),
          ],
        ),
      );
      if (retry == true && mounted) {
        final mpc = context.read<MpcService>();
        final messenger = ScaffoldMessenger.of(context);
        try {
          await mpc.reconnectHardwareSigner();
          messenger.showSnackBar(
            const SnackBar(content: Text('Hardware key reconnected. Try again.')),
          );
        } catch (_) {
          if (mounted) {
            messenger.showSnackBar(
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

  Future<String?> _showAuthDialog() async {
    String pin = '';
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Authorize Recovery Key',
            style: GoogleFonts.inter(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 48, color: Colors.blueAccent),
            const SizedBox(height: 16),
            Text(
              'Enter your PIN to sign this policy with your recovery key.',
              style: GoogleFonts.inter(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (v) => pin = v,
              style: const TextStyle(color: Colors.white, letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: '6-digit PIN',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (pin.length == 6 && RegExp(r'^\d{6}$').hasMatch(pin)) {
                Navigator.of(context).pop(pin);
              }
            },
            child: const Text('Sign'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditMode ? 'Edit Policy' : 'New Policy')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Spending Threshold (Sats)',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            Slider(
              value: _sliderValue,
              min: 0,
              max: 1,
              divisions: 200,
              label: '${NumberFormat('#,###').format(_thresholdSats)} Sats',
              onChanged: (value) => setState(() => _sliderValue = value),
            ),
            Text(
              '${NumberFormat('#,###').format(_thresholdSats)} Sats',
              style:
                  GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Text('Reset Interval',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '5m', label: Text('5 Min')),
                  ButtonSegment(value: '1h', label: Text('1 Hour')),
                  ButtonSegment(value: '24h', label: Text('Daily')),
                  ButtonSegment(value: '7d', label: Text('Weekly')),
                ],
                selected: {
                  _interval
                },
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _interval = newSelection.first;
                  });
                },
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.white;
                    }
                    return Colors.transparent;
                  }),
                  foregroundColor:
                      MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.black;
                    }
                    return Colors.white;
                  }),
                )),
            const Spacer(),
            ElevatedButton(
              onPressed: _isSigning ? null : _savePolicy,
              child: _isSigning
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditMode ? 'Update Policy' : 'Sign & Create Policy'),
            )
          ],
        ),
      ),
    );
  }
}
