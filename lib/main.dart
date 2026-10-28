import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const GlycrScannerApp());
}

class GlycrScannerApp extends StatelessWidget {
  const GlycrScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glycr Scanner',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const LoginScreen(),
    );
  }

  ThemeData _buildTheme() {
    const bg = Color(0xFF0d1117);
    const surface = Color(0xFF131a23);
    const surface2 = Color(0xFF192130);
    const border = Color(0xFF243347);
    const teal = Color(0xFF2dd4bf);
    const text = Color(0xFFccd9e3);
    const muted = Color(0xFF4a6278);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(
        primary: teal,
        secondary: teal,
        surface: surface,
        onSurface: text,
        outline: border,
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: text,
        displayColor: const Color(0xFFeaf2f8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
        hintStyle: const TextStyle(color: muted, fontSize: 14),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: bg,
          minimumSize: const Size.fromHeight(48),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.outfit(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      dividerColor: border,
      useMaterial3: true,
    );
  }
}

// ── App colours ────────────────────────────────────────────
class AppColors {
  static const bg       = Color(0xFF0d1117);
  static const bg2      = Color(0xFF131a23);
  static const bg3      = Color(0xFF192130);
  static const surface  = Color(0xFF1e2a3a);
  static const border   = Color(0xFF243347);
  static const border2  = Color(0xFF2d3f56);
  static const muted    = Color(0xFF4a6278);
  static const dim      = Color(0xFF7a96aa);
  static const text     = Color(0xFFccd9e3);
  static const bright   = Color(0xFFeaf2f8);
  static const teal     = Color(0xFF2dd4bf);
  static const tealD    = Color(0xFF1aae9e);
  static const mint     = Color(0xFF6ee7b7);
  static const coral    = Color(0xFFff6b6b);
  static const gold     = Color(0xFFfbbf24);
  static const sky      = Color(0xFF7dd3fc);
  static const redDark  = Color(0xFF9c1c1c);
}