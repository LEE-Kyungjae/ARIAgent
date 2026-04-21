import 'package:flutter/material.dart';

class SettingsDropdown extends StatelessWidget {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final Function(String?)? onChanged;

  const SettingsDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111122),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: disabled ? 0.05 : 0.1),
        ),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF111122),
        underline: const SizedBox(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: disabled ? 0.4 : 1.0),
          fontSize: 13,
        ),
        icon: Icon(
          Icons.expand_more,
          color: Colors.white.withValues(alpha: disabled ? 0.2 : 0.4),
        ),
        disabledHint: items
            .firstWhere(
              (item) => item.value == value,
              orElse: () => DropdownMenuItem(
                value: value,
                child: Text(value),
              ),
            )
            .child,
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
