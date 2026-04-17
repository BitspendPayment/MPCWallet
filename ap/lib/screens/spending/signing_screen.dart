import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/stepper_widget.dart';
import 'package:provider/provider.dart';
import '../../services/mpc_service.dart';

class SigningScreen extends StatefulWidget {
  final Map<String, dynamic> extras;
  const SigningScreen({super.key, this.extras = const {}});

  @override
  State<SigningScreen> createState() => _SigningScreenState();
}

class _SigningScreenState extends State<SigningScreen> {
  int _currentStep = 0;
  late final List<String> _steps;
  String _statusText = '';

  bool get _isArk => widget.extras['isArk'] as bool? ?? false;

  @override
  void initState() {
    super.initState();
    _steps = _isArk ? ['Build', 'Sign', 'Submit'] : ['Build', 'Sign', 'Broadcast'];
    _statusText = 'Building transaction...';
    _startSigning();
  }

  Future<String?> _showPinDialog() async {
    String pin = '';
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Policy Triggered',
            style: GoogleFonts.inter(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield, size: 48, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'This transaction exceeds your spending policy threshold. Enter your PIN to authorize.',
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
            ),
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
            child: const Text('Authorize'),
          ),
        ],
      ),
    );
  }

  void _startSigning() async {
    if (_isArk) {
      await _startArkSend();
    } else {
      await _startBitcoinSend();
    }
  }

  Future<void> _startArkSend() async {
    final mpcService = context.read<MpcService>();
    final arkWallet = mpcService.arkWallet;

    if (arkWallet == null || !mpcService.arkAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ark wallet not initialized!')),
        );
        context.pop();
      }
      return;
    }

    final destination = widget.extras['address'] as String?;
    final amountStr = widget.extras['amount'] as String?;

    if (destination == null || amountStr == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid transaction details!')),
        );
        context.pop();
      }
      return;
    }

    final amount = int.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid amount!')),
        );
        context.pop();
      }
      return;
    }

    try {
      // Step 0: Build transaction
      setState(() {
        _currentStep = 0;
        _statusText = 'Building transaction...';
      });

      final unsigned = await arkWallet.createTransaction(
        destination: destination,
        amountSats: amount,
      );

      // Step 1: Sign — check if policy is triggered
      setState(() {
        _currentStep = 1;
        _statusText = 'Checking spending policy...';
      });

      String? pin;
      String? policyId;

      try {
        final resolvedPolicyId = await arkWallet.getPolicyId(unsigned);
        if (resolvedPolicyId.isNotEmpty) {
          setState(() {
            _statusText = 'Policy triggered — PIN required';
          });

          if (!mounted) return;
          pin = await _showPinDialog();
          if (pin == null || pin.isEmpty) {
            unsigned.dispose();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signing cancelled')),
              );
              context.pop();
            }
            return;
          }
          policyId = resolvedPolicyId;
        }
      } catch (e) {
        debugPrint("getPolicyId failed: $e — proceeding without policy");
      }

      setState(() {
        _statusText = 'Signing with your Key Share...';
      });
      await Future.delayed(const Duration(milliseconds: 300));

      final signed = await arkWallet.signTransaction(
        unsigned,
        pin: pin,
        policyId: policyId,
      );

      // Step 2: Submit
      setState(() {
        _currentStep = 2;
        _statusText = 'Submitting to Ark...';
      });
      await Future.delayed(const Duration(milliseconds: 300));

      final arkTxid = await arkWallet.submit(signed);
      await mpcService.refreshVtxos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ark send complete! TX: ${arkTxid.substring(0, 16)}...'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/ark');
      }
    } catch (e, st) {
      debugPrint('=== ARK SEND FAILED ===');
      debugPrint('Error: $e');
      debugPrint('Stack: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ark Send Failed: $e'),
              backgroundColor: Colors.red),
        );
        context.pop();
      }
    }
  }

  Future<void> _startBitcoinSend() async {
    final mpcService = context.read<MpcService>();
    final wallet = mpcService.wallet;

    if (wallet == null || !mpcService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet not initialized!')),
      );
      return;
    }

    try {
      // Step 0: Build transaction
      setState(() {
        _currentStep = 0;
        _statusText = 'Building transaction...';
      });

      final destination = widget.extras['address'] as String?;
      final amountStr = widget.extras['amount'] as String?;

      if (destination == null || amountStr == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid transaction details!')),
          );
          context.pop();
        }
        return;
      }

      BigInt amount;
      try {
        amount = BigInt.parse(amountStr);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid amount format!')),
          );
          context.pop();
        }
        return;
      }

      // Sync UTXOs
      try {
        await wallet.sync();
      } catch (e) {
        print("Sync failed before sign: $e");
      }

      final balance = await wallet.getBalance();
      if (amount + BigInt.from(500) > balance) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Insufficient funds! Balance: $balance sats')),
          );
          context.pop();
        }
        return;
      }

      final unsigned = await wallet.createTransaction(
        destination: destination,
        amount: amount,
        feeRate: 1,
      );

      // Step 1: Sign — check if policy is triggered
      setState(() {
        _currentStep = 1;
        _statusText = 'Checking spending policy...';
      });

      String? pin;
      String? policyId;

      try {
        final resolvedPolicyId = await wallet.getPolicyId(unsigned);
        if (resolvedPolicyId.isNotEmpty) {
          setState(() {
            _statusText = 'Policy triggered — PIN required';
          });

          if (!mounted) return;
          pin = await _showPinDialog();
          if (pin == null || pin.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signing cancelled')),
              );
              context.pop();
            }
            return;
          }
          policyId = resolvedPolicyId;
        }
      } catch (e) {
        print("getPolicyId failed: $e — proceeding without policy");
      }

      setState(() {
        _statusText = 'Signing with your Key Share...';
      });
      await Future.delayed(const Duration(milliseconds: 300));

      final txHex = await wallet.signTransaction(
        unsigned,
        pin: pin,
        policyId: policyId,
      );

      // Step 2: Broadcast
      setState(() {
        _currentStep = 2;
        _statusText = 'Broadcasting transaction...';
      });
      await Future.delayed(const Duration(milliseconds: 300));

      await wallet.broadcast(txHex);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Success! Tx Sent.'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {},
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.read<MpcService>().refreshHistory();
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Transaction Failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isArk ? 'Sending (Ark)' : 'Signing Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            DkgStepper(currentStep: _currentStep, steps: _steps),
            const Spacer(),
            Text(_statusText,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Colors.white),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
