import 'package:flutter/material.dart';

/// Palet pastel (referensi: pastel color palette)
class AppColors {
  static const background = Color(0xFFFFF9FB);
  static const text = Color(0xFF4A4458);
  static const textSoft = Color(0xFF8E88A0);

  static const pink = Color(0xFFFFD6E0);
  static const peach = Color(0xFFFFE5D0);
  static const yellow = Color(0xFFFFF6C9);
  static const mint = Color(0xFFD4F0E0);
  static const sky = Color(0xFFD0E8FF);
  static const lavender = Color(0xFFE4D9FF);

  static const accent = Color(0xFFB9A5F0);
  static const accentDark = Color(0xFF8F78DB);

  static const cardColors = [pink, peach, yellow, mint, sky, lavender];

  static Color cardColor(int index) => cardColors[index % cardColors.length];
}
