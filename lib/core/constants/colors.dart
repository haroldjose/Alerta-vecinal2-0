import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFFAF8FF);
  static const Color primary = Color(0xFF4353F4);
  static const Color secondary = Color(0xFF28318F);
  static const Color accent = Color(0xFF4554F5);
  static const Color white = Color(0xFFFAF8FF);
  static const Color error = Color(0xFFE53E3E);
  static const Color success = Color(0xFF38A169);
  static const Color warning = Color(0xFFD69E2E);
  static const Color textPrimary = Color(0xFF2D3748);
  static const Color textSecondary = Color(0xFF718096);
  static const Color border = Color(0xFFE2E8F0);

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [secondary, accent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    );
}