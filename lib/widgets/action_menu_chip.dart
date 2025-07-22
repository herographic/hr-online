// lib/widgets/action_menu_chip.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActionMenuChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const ActionMenuChip({
    super.key,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? Theme.of(context).primaryColor : Colors.white,
      borderRadius: BorderRadius.circular(30.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30.0),
        splashColor: Theme.of(context).primaryColor.withOpacity(0.2),
        highlightColor: Theme.of(context).primaryColor.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30.0),
            border: Border.all(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.anuphan(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
