import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kBg = Color(0xFFF6EEE3);
const kAccent = Color(0xFFB8793A);
const kAccentSoft = Color(0xFFF0DDC6);
const kBorder = Color(0xFFE4D2BF);
const kField = Color(0xFFFFF8F0);
const kCard = Color(0xFFFFFBF6);
const kText = Color(0xFF3A2A1E);
const kSubtle = Color(0xFF8A7562);
const kSuccess = Color(0xFF5F8F5F);
const kWarning = Color(0xFFC28A2C);

const kSoftShadow = [
  BoxShadow(
    color: Color(0x1F5A3B21),
    blurRadius: 18,
    offset: Offset(0, 8),
  ),
];

ThemeData buildAppTheme() {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: kBorder, width: 1),
  );
  final base = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kAccent,
      brightness: Brightness.light,
      primary: kAccent,
      surface: kCard,
    ),
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      elevation: 0,
      foregroundColor: kText,
      iconTheme: IconThemeData(color: kText),
      titleTextStyle: TextStyle(
        color: kAccent,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kField,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: kAccent, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: kSubtle),
      prefixIconColor: kAccent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    cardTheme: CardThemeData(
      color: kCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorder),
      ),
    ),
  );

  final thText = GoogleFonts.notoSansThaiTextTheme(base.textTheme);
  return base.copyWith(
    textTheme: thText.apply(
      bodyColor: kText,
      displayColor: kText,
    ),
  );
}
