import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ألوان الهوية البصرية للموقع: تيل أساسي وذهبي مساعد وخلفية متدرجة فاتحة.
class AppColors {
  static const primary = Color(0xFF2D5869);
  static const primaryDark = Color(0xFF1A3A47);
  static const gold = Color(0xFFC5A059);
  static const goldLight = Color(0xFFE2B96F);
  static const background = Color(0xFFE9EFF0);
  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF166534);
  static const warning = Color(0xFF92400E);
}

/// تدرجات مطابقة لهوية الموقع (زر "استشارة مجانية" وفقاعة الشات "أنا").
class AppGradients {
  static const goldToTeal = LinearGradient(
    colors: [AppColors.gold, AppColors.primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const tealToDark = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.gold,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.cairo().fontFamily,
      textTheme: GoogleFonts.cairoTextTheme(),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD0DCE2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD0DCE2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: IconThemeData(color: AppColors.primary),
        selectedLabelTextStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
      ),
    );
  }

  static ThemeData dark() {
    const surface = Color(0xFF1B2226);
    const scaffoldBg = Color(0xFF12181B);
    const border = Color(0xFF2C363B);

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.goldLight,
        secondary: AppColors.gold,
        surface: surface,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: GoogleFonts.cairo().fontFamily,
      textTheme: GoogleFonts.cairoTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.goldLight,
          foregroundColor: const Color(0xFF12181B),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.goldLight, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: border)),
        margin: EdgeInsets.zero,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: IconThemeData(color: AppColors.goldLight),
        selectedLabelTextStyle: TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w700),
      ),
      dividerColor: border,
    );
  }
}
