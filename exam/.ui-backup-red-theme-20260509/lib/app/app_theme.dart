import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
const kBg = Color(0xFF0B0F18);
const kAccent = Color(0xFF3B82F6);
const kBorder = Color(0xFF1F2937);
const kField = Color(0xFF0F172A);
const kSubtle = Color(0xFF9CA3AF);

ThemeData buildAppTheme() {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: kBorder, width: 1),
  );
  final base = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBg,
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: kField,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: kAccent, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: kSubtle),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent, foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    );

  final thText = GoogleFonts.notoSansThaiTextTheme(base.textTheme);
  return base.copyWith(textTheme: thText);
}
