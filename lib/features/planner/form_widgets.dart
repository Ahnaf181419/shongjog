import 'package:flutter/material.dart';

/// Shared form-building widgets used by the Planner, Kit, and Risk screens.

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }
}

class StepperRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int max;
  const StepperRow({
    super.key,
    required this.label,
    required this.controller,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded),
            onPressed: () {
              final v = (int.tryParse(controller.text) ?? 0) - 1;
              if (v >= 0) {
                controller.text = '$v';
              }
            },
          ),
          SizedBox(
            width: 40,
            // TextEditingController is a ValueNotifier — setting
            // controller.text above does fire notifyListeners(), but as
            // a bare StatelessWidget nothing was listening for it, so the
            // displayed digit never repainted even though the underlying
            // value was updating correctly. ValueListenableBuilder is the
            // listener that was missing.
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => Text(
                value.text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () {
              final v = (int.tryParse(controller.text) ?? 0) + 1;
              if (v <= max) {
                controller.text = '$v';
              }
            },
          ),
        ],
      ),
    );
  }
}

class ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
