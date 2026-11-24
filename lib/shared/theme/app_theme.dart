import 'package:flutter/material.dart';

abstract final class Palette {
  static const background = Color(0xFF29253F);
  static const card = Color(0xFF342E4F);
  static const sheet = Color(0xFF2E2946);
  static const field = Color(0xFF3D3659);
  static const text = Color(0xFFF6EEFC);
  static const secondary = Color(0xFFCFC2DC);
  static const muted = Color(0xFFB0A2C2);
  static const expense = Color(0xFFFF9EC6);
  static const income = Color(0xFF8ADBC8);
  static const balance = Color(0xFFD9CBFF);
  static const accent = Color(0xFFCA6198);
  static const line = Color(0xFF6D5B7F);
  static const onPink = Color(0xFF46304D);
}

const _fonts = ['JfOpenHuninn'];

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Palette.background,
  fontFamily: 'Fredoka',
  fontFamilyFallback: _fonts,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Palette.accent,
    brightness: Brightness.dark,
    primary: Palette.expense,
    onPrimary: Palette.onPink,
    surface: Palette.card,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Palette.text, fontSize: 15, height: 1.4),
    bodyMedium: TextStyle(color: Palette.text, fontSize: 14, height: 1.4),
    bodySmall: TextStyle(color: Palette.secondary, fontSize: 12, height: 1.4),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Palette.background,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      fontFamily: 'Fredoka',
      fontFamilyFallback: _fonts,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Palette.text,
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(fixedSize: const Size.square(48)),
  ),
  dividerTheme: const DividerThemeData(color: Palette.line, thickness: 0.6),
  inputDecorationTheme: const InputDecorationTheme(
    border: InputBorder.none,
    hintStyle: TextStyle(color: Palette.muted),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Palette.sheet,
    showDragHandle: true,
    dragHandleColor: Palette.line,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Palette.card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: const Color(0xFF4B3A61),
    contentTextStyle: const TextStyle(
      fontFamily: 'Fredoka',
      fontFamilyFallback: _fonts,
      color: Palette.text,
      fontSize: 14,
    ),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: Palette.accent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Palette.line.withValues(alpha: .4),
      minimumSize: const Size(48, 50),
      textStyle: const TextStyle(
        fontFamily: 'Fredoka',
        fontFamilyFallback: _fonts,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: Palette.expense),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.selected) ? Colors.white : Palette.muted,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.selected)
              ? Palette.accent
              : Palette.field,
    ),
  ),
);

InputDecoration fieldDecoration(
  String hint, {
  String? prefix,
  String? suffix,
}) => InputDecoration(
  hintText: hint,
  prefixText: prefix,
  suffixText: suffix,
  filled: true,
  fillColor: Palette.field.withValues(alpha: .8),
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Palette.expense, width: 1.2),
  ),
);
