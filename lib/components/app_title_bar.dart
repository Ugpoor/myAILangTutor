
import 'package:flutter/material.dart';

class AppTitleBar extends StatelessWidget {
  final String title;
  final String lang;
  final List<String>? dropdownItems;
  final String? selectedDropdownValue;
  final Function(String)? onDropdownChanged;
  final VoidCallback? onHomeTap;

  const AppTitleBar({
    super.key,
    required this.title,
    this.lang = 'cn',
    this.dropdownItems,
    this.selectedDropdownValue,
    this.onDropdownChanged,
    this.onHomeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFF69B4),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          if (onHomeTap != null)
            GestureDetector(
              onTap: onHomeTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: const Icon(Icons.home, color: Colors.white, size: 20),
              ),
            ),
          if (onHomeTap != null) const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (dropdownItems != null && dropdownItems!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<String>(
                value: selectedDropdownValue,
                dropdownColor: Color(0xFFFF69B4),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                underline: const SizedBox(),
                onChanged: (String? newValue) {
                  if (newValue != null && onDropdownChanged != null) {
                    onDropdownChanged!(newValue);
                  }
                },
                items: dropdownItems!.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(value),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
