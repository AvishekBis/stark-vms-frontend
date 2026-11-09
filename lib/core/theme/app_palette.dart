import 'package:flutter/material.dart';

/// Stark Group brand palette. The ONLY place where colour values live;
/// widgets read colours through `Theme.of(context)`.
abstract final class AppPalette {
  static const Color navy = Color(0xFF17375E);
  static const Color blue = Color(0xFF2E75B6);
  static const Color blueTint = Color(0x332E75B6);
  static const Color green = Color(0xFF2E8B57);
  static const Color amber = Color(0xFFE0A100);
  static const Color red = Color(0xFFC62828);
  static const Color grey = Color(0xFF6B7280);

  static const Color white = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1F2933);
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFD5DBE3);
}
