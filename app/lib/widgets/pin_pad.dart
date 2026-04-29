import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PinPad extends StatelessWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onDelete;
  final bool showBiometric;
  final VoidCallback? onBiometricPressed;

  const PinPad({
    super.key,
    required this.onKeyPressed,
    required this.onDelete,
    this.showBiometric = false,
    this.onBiometricPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              _buildKey(context, '1'),
              _buildKey(context, '2'),
              _buildKey(context, '3'),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              _buildKey(context, '4'),
              _buildKey(context, '5'),
              _buildKey(context, '6'),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              _buildKey(context, '7'),
              _buildKey(context, '8'),
              _buildKey(context, '9'),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              showBiometric
                  ? Expanded(
                      child: InkWell(
                        onTap: onBiometricPressed,
                        child: const Center(
                          child: Icon(Icons.fingerprint,
                              size: 32, color: Colors.white),
                        ),
                      ),
                    )
                  : const Spacer(),
              _buildKey(context, '0'),
              Expanded(
                child: InkWell(
                  onTap: onDelete,
                  child: const Center(
                    child: Icon(Icons.backspace_outlined,
                        size: 24, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKey(BuildContext context, String value) {
    return Expanded(
      child: InkWell(
        onTap: () => onKeyPressed(value),
        child: Center(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
