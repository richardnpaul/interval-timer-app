import 'package:flutter/material.dart';

/// Fixed palette of hex colors available in the app.
const List<String> kColorPalette = [
  '#EF5350', // red
  '#FF7043', // deep orange
  '#FFA726', // orange
  '#FFEE58', // yellow
  '#66BB6A', // green
  '#26C6DA', // cyan
  '#42A5F5', // blue
  '#7E57C2', // deep purple
  '#EC407A', // pink
  '#78909C', // blue grey
];

/// Parses a '#RRGGBB' hex string into a [Color].
Color colorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}

/// A row of color swatch circles. Tapping a swatch calls [onChanged].
class ColorSwatchPicker extends StatelessWidget {
  /// Currently selected color as a hex string (e.g. '#EF5350'). May be null.
  final String? selected;

  /// Called with the new hex string when a swatch is tapped.
  final ValueChanged<String> onChanged;

  const ColorSwatchPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kColorPalette.map((hex) {
        final isSelected = hex == selected;
        return GestureDetector(
          onTap: () => onChanged(hex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorFromHex(hex),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colorFromHex(hex).withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
