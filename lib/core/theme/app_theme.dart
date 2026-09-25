import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color primario = Color(0xFF2563EB);
  static const Color primarioOscuro = Color(0xFF1E3A8A);

  static const Color superficie = Color(0xFFFFFFFF);
  static const Color fondo = Color(0xFFF1F5F9);
  static const Color borde = Color(0xFFE2E8F0);
  static const Color textoFuerte = Color(0xFF0F172A);
  static const Color textoSuave = Color(0xFF64748B);

  static const double tap = 48;

  static const double radio = 14;
  static const double radioTarjeta = 16;

  static ThemeData get light {
    final esquema = ColorScheme.fromSeed(
      seedColor: primario,
      primary: primario,
      surface: superficie,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: fondo,

      // Blanca y sin sombra: las pantallas de contenido ya se apoyan en el gris
      // del fondo para separarse, y una barra oscura competía con el mapa.
      appBarTheme: const AppBarTheme(
        backgroundColor: superficie,
        foregroundColor: textoFuerte,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: textoFuerte,
        ),
      ),

      cardTheme: CardTheme(
        color: superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radioTarjeta),
          side: const BorderSide(color: borde),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primario,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(tap),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radio),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primario,
          minimumSize: const Size.fromHeight(tap),
          side: const BorderSide(color: borde),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radio),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primario,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: superficie,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _borde(borde),
        enabledBorder: _borde(borde),
        focusedBorder: _borde(primario, grosor: 1.6),
        errorBorder: _borde(const Color(0xFFDC2626)),
        focusedErrorBorder: _borde(const Color(0xFFDC2626), grosor: 1.6),
        labelStyle: const TextStyle(color: textoSuave),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: fondo,
        side: const BorderSide(color: borde),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: textoSuave,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textoFuerte,
        ),
        subtitleTextStyle: TextStyle(fontSize: 13, color: textoSuave),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primario.withOpacity(0.12),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (estados) => TextStyle(
            fontSize: 12,
            fontWeight: estados.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: estados.contains(WidgetState.selected)
                ? primario
                : textoSuave,
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(color: borde, space: 1, thickness: 1),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textoFuerte,
        contentTextStyle: const TextStyle(fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radio - 2),
        ),
      ),
    );
  }

  static OutlineInputBorder _borde(Color color, {double grosor = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radio - 2),
      borderSide: BorderSide(color: color, width: grosor),
    );
  }
}
