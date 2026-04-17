import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color iosBlue = Color(
    0xFF0A84FF,
  ); // Jaśniejszy błękit dla Dark Mode

  // --- MOTYW JASNY ---
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        primary: const Color(0xFF007AFF),
      ),
      useMaterial3: true,
      textTheme: GoogleFonts.nunitoTextTheme(),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- MOTYW CIEMNY (iOS Dark) ---
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black, // Prawdziwa czerń OLED
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: iosBlue,
        primary: iosBlue,
        surface: const Color(0xFF1C1C1E), // Karty w iOS Dark
      ),
      useMaterial3: true,
      textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardThemeData(
        color: const Color(0xFF1C1C1E), // Tło kafelków
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1C1C1E),
        selectedItemColor: iosBlue,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
