import 'package:flutter/material.dart';

import 'app_theme.dart';

class MapStyle {
  const MapStyle._();

  // ---------------------------------------------------------------------------
  // Color
  // ---------------------------------------------------------------------------

  static const Color primario = AppTheme.primario;

  static const Color superficie = Color(0xFFFFFFFF);
  static const Color superficieTenue = Color(0xFFF8FAFC);
  static const Color borde = Color(0xFFE2E8F0);

  static const Color textoFuerte = Color(0xFF0F172A);
  static const Color textoSuave = Color(0xFF64748B);

  static const Color exito = Color(0xFF16A34A);
  static const Color aviso = Color(0xFFF59E0B);
  static const Color peligro = Color(0xFFDC2626);
  static const Color neutro = Color(0xFF94A3B8);

  // ---------------------------------------------------------------------------
  // Métrica
  // ---------------------------------------------------------------------------

  static const double esp1 = 4;
  static const double esp2 = 8;
  static const double esp3 = 12;
  static const double esp4 = 16;
  static const double esp5 = 20;
  static const double esp6 = 24;

  static const double radioHoja = 24;
  static const double radioControl = 14;
  static const double radioPildora = 999;

  static const double tap = 48;

  static const List<BoxShadow> sombraFlotante = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> sombraHoja = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, -4)),
  ];

  // ---------------------------------------------------------------------------
  // Fondo del mapa
  // ---------------------------------------------------------------------------

  static const String tilesUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String paqueteAgente = 'com.logistica.movil';

  static const String atribucion = '© OpenStreetMap contributors';

  static const ColorFilter filtroMapaClaro = ColorFilter.matrix(<double>[
    0.27024, 0.55385, 0.05591, 0, 38, //
    0.16464, 0.65945, 0.05591, 0, 38, //
    0.16464, 0.55385, 0.16151, 0, 38, //
    0, 0, 0, 1, 0, //
  ]);

  // ---------------------------------------------------------------------------
  // Tipografía
  //
  // Jerarquía de la hoja inferior: pedido > dirección > distancia/tiempo > resto.
  // ---------------------------------------------------------------------------

  static const TextStyle etiqueta = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: textoSuave,
    letterSpacing: 0.8,
    height: 1.2,
  );

  static const TextStyle titulo = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textoFuerte,
    height: 1.2,
  );

  static const TextStyle tituloBarra = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: textoFuerte,
    height: 1.2,
  );

  static const TextStyle direccion = TextStyle(
    fontSize: 15,
    color: textoSuave,
    height: 1.35,
  );

  static const TextStyle metrica = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textoFuerte,
    height: 1.2,
  );

  static const TextStyle secundario = TextStyle(
    fontSize: 12,
    color: textoSuave,
    height: 1.35,
  );
}
