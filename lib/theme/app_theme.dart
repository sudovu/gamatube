import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../models/app_settings.dart';

class AppTheme {
  static ThemeData getTheme({
    required AppThemeMode mode,
    bool highContrast = false,
  }) {
    if (highContrast) {
      return mode == AppThemeMode.light ? _highContrastLight : _highContrastDark;
    }
    switch (mode) {
      case AppThemeMode.light:
        return _lightTheme;
      case AppThemeMode.amoled:
        return _amoledTheme;
      case AppThemeMode.dark:
      case AppThemeMode.system:
        return _darkTheme;
    }
  }

  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.lightSurface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.lightTextPrimary,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      indicatorColor: AppColors.primary.withAlpha(30),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.lightSurface,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 1,
    ),
  );

  static final ThemeData _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryLight,
      secondary: AppColors.secondary,
      surface: AppColors.darkSurface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.darkTextPrimary,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      indicatorColor: AppColors.primaryLight.withAlpha(50),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.darkSurface,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 1,
    ),
  );

  static final ThemeData _amoledTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.amoledBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryLight,
      secondary: AppColors.secondary,
      surface: AppColors.amoledSurface,
      error: AppColors.error,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: AppColors.amoledTextPrimary,
      onError: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.amoledBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.amoledTextPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.amoledTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.amoledSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.amoledBorder, width: 1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.amoledBackground,
      indicatorColor: AppColors.primaryLight.withAlpha(60),
      elevation: 0,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.amoledBackground,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.amoledBorder,
      thickness: 1,
    ),
  );

  static final ThemeData _highContrastLight = _lightTheme.copyWith(
    scaffoldBackgroundColor: AppColors.hcLightBackground,
    colorScheme: const ColorScheme.light(
      primary: Colors.black,
      surface: Colors.white,
      onSurface: Colors.black,
    ),
  );

  static final ThemeData _highContrastDark = _darkTheme.copyWith(
    scaffoldBackgroundColor: AppColors.hcDarkBackground,
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      surface: Colors.black,
      onSurface: Colors.white,
    ),
  );
}
