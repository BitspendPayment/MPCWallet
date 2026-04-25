import 'package:flutter/material.dart';

/// Prompt the user for their wallet password. Returns the entered password
/// on OK, or null if the user cancels.
///
/// Used to gate the four operations that need the recovery signer: DKG (in
/// onboarding), restore, update policy, delete policy. The password is
/// consumed immediately by `MpcService.loadRecoverySigner` or
/// `withRecoverySigner` and not cached anywhere.
Future<String?> promptRecoveryPassword(
  BuildContext context, {
  String title = 'Enter wallet password',
  String? hint,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _RecoveryPasswordDialog(title: title, hint: hint),
  );
}

class _RecoveryPasswordDialog extends StatefulWidget {
  final String title;
  final String? hint;
  const _RecoveryPasswordDialog({required this.title, this.hint});

  @override
  State<_RecoveryPasswordDialog> createState() =>
      _RecoveryPasswordDialogState();
}

class _RecoveryPasswordDialogState extends State<_RecoveryPasswordDialog> {
  // Owned by this State — created in initState (implicitly) and disposed in
  // dispose(), guaranteeing it's torn down in the same frame as the
  // TextField that uses it. Avoids the `_dependents.isEmpty` assertion that
  // can fire when a controller is disposed after its TextField is unmounted.
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.hint != null) ...[
            Text(widget.hint!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
