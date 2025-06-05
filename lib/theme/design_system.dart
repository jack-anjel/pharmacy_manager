// lib/theme/design_system.dart

import 'package:flutter/material.dart';

/// الألوان الأساسية (Palette)
class AppColors {
  static const Color primary = Colors.teal;
  static const Color primaryVariant = Color(0xFF00695C);
  static const Color secondary = Colors.orange;
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;
  static const Color mutedText = Colors.grey;
  static const Color danger = Colors.red;
  static const Color warning = Colors.orangeAccent;
}

/// المقاييس الثابتة للمسافات والحدود
class AppSpacing {
  static const double padding = 12.0;
  static const double margin = 8.0;
  static const double borderRadius = 8.0;
}

/// أنماط النص الموحدة
class AppTextStyles {
  static const TextStyle headline = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    color: Colors.black54,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: Colors.black87,
  );
  static const TextStyle cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );
  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 14,
    color: Colors.black54,
  );
}
