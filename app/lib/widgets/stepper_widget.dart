import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DkgStepper extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const DkgStepper({
    super.key,
    required this.currentStep,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Divider
            return Expanded(
              child: Container(
                height: 2,
                color: index ~/ 2 < currentStep ? Colors.white : Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
            );
          } else {
            // Step Circle
            final stepIndex = index ~/ 2;
            final isActive = stepIndex <= currentStep;
            final isCompleted = stepIndex < currentStep;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.transparent,
                    border: Border.all(
                      color: isActive ? Colors.white : Colors.white24,
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.black)
                        : Text(
                            '${stepIndex + 1}',
                            style: GoogleFonts.inter(
                              color: isActive ? Colors.black : Colors.white24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  steps[stepIndex],
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isActive ? Colors.white : Colors.white24,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            );
          }
        }),
      ),
    );
  }
}
