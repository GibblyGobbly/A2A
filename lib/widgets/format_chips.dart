import 'package:flutter/material.dart';
import '../services/format_detector.dart';
import '../theme/app_theme.dart';

class FormatChips extends StatelessWidget {
  final List<FormatOption> formats;
  final String? selectedFormat;
  final ValueChanged<String> onSelected;

  const FormatChips({
    super.key,
    required this.formats,
    required this.selectedFormat,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (formats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No compatible output formats found.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: formats.map((format) {
        final isSelected = selectedFormat == format.extension;
        return InkWell(
          onTap: () => onSelected(format.extension),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryBlue : AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Text(
              format.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textDark,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
