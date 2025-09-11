import 'package:flutter/material.dart';

class TextFieldComponent extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;

  const TextFieldComponent({
    super.key,
    required this.controller,
    required this.labelText,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
    );
  }
}