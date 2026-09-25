// Pruebas del botón «Mi ubicación actual».
//
// El GPS real se sustituye por `GeolocatorPlatform.instance`, que es el punto
// de extensión que ofrece el propio paquete. Así se puede comprobar lo que de
// verdad importa: que cada motivo de fallo da su explicación, que un tiempo
// agotado no se disimula con una posición vieja, y que una lectura buena acaba
// en texto dentro del formulario.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:latlong2/latlong.dart';
import 'package:movil_logistica/core/geo/ubicacion_dispositivo.dart';
import 'package:movil_logistica/features/direcciones/data/geocoding_repository.dart';
import 'package:movil_logistica/features/direcciones/presentation/geocoding_provider.dart';
import 'package:movil_logistica/features/direcciones/presentation/screens/editar_direccion_screen.dart';

import 'apoyo/nominatim_falso.dart';

class _GpsFalso extends GeolocatorPlatform {
  _GpsFalso({
    this.servicioEncendido = true,
    this.permiso = LocationPermission.whileInUse,
    this.posicion,
    this.tarda = false,
  });

  final bool servicioEncendido;
  LocationPermission permiso;
  final Position? posicion;
  final bool tarda;

  int vecesQuePidioPermiso = 0;
  bool pidioUltimaConocida = false;
  LocationSettings? ajustesRecibidos;

  @override
  Future<bool> isLocationServiceEnabled() async => servicioEncendido;

  @override
  Future<LocationPermission> checkPermission() async => permiso;

  @override
  Future<LocationPermission> requestPermission() async {
    vecesQuePidioPermiso++;
    return permiso;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    ajustesRecibidos = locationSettings;
    if (tarda) return Future<Position>.error(TimeoutException('sin señal'));
    return Future<Position>.value(posicion!);
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) {
    pidioUltimaConocida = true;
    return Future<Position?>.value(posicion);
  }
}

Position _posicion(double lat, double lon) => Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.utc(2026, 3, 1),
      accuracy: 8,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  group('UbicacionPuntual', () {
    test('devuelve el punto cuando hay GPS y permiso', () async {
      final gps = _GpsFalso(posicion: _posicion(-5.1945, -80.6328));
      GeolocatorPlatform.instance = gps;

      final punto = await const UbicacionPuntual().punto();

      expect(punto.latitude, closeTo(-5.1945, 0.0001));
      expect(punto.longitude, closeTo(-80.6328, 0.0001));
      // Con límite de tiempo: un botón que gira para siempre es peor que uno
      // que falla.
      expect(gps.ajustesRecibidos?.timeLimit, isNotNull);
    });

    test('con el GPS apagado lo dice, y no pide permiso de paso', () async {
      final gps = _GpsFalso(servicioEncendido: false);
      GeolocatorPlatform.instance = gps;

      await expectLater(
        const UbicacionPuntual().punto(),
        throwsA(isA<UbicacionException>()
            .having((e) => e.motivo, 'motivo', ErrorUbicacion.servicioApagado)),
      );
      // Pedir permiso con el servicio apagado gasta un diálogo que no arregla
      // nada: el usuario lo concede y sigue sin funcionar.
      expect(gps.vecesQuePidioPermiso, 0);
    });

    test('permiso denegado para siempre manda a los ajustes', () async {
      GeolocatorPlatform.instance =
          _GpsFalso(permiso: LocationPermission.deniedForever);

      await expectLater(
        const UbicacionPuntual().punto(),
        throwsA(isA<UbicacionException>()
            .having((e) => e.mensaje, 'mensaje', contains('ajustes'))),
      );
    });

    test('un permiso denegado se vuelve a pedir una vez', () async {
      final gps = _GpsFalso(permiso: LocationPermission.denied);
      GeolocatorPlatform.instance = gps;

      await expectLater(
        const UbicacionPuntual().punto(),
        throwsA(isA<UbicacionException>()
            .having((e) => e.motivo, 'motivo', ErrorUbicacion.permisoDenegado)),
      );
      expect(gps.vecesQuePidioPermiso, 1);
    });

    test('si el GPS no fija a tiempo lo admite, no usa una posición vieja',
        () async {
      // Bajo techo `getCurrentPosition` puede no volver nunca. Devolver la
      // última posición conocida sería colocar el pin donde estuvo el teléfono
      // ayer, diciendo que es donde está ahora.
      final gps = _GpsFalso(tarda: true, posicion: _posicion(-12.04, -77.04));
      GeolocatorPlatform.instance = gps;

      await expectLater(
        const UbicacionPuntual().punto(limite: const Duration(seconds: 1)),
        throwsA(isA<UbicacionException>()
            .having((e) => e.motivo, 'motivo', ErrorUbicacion.tiempoAgotado)),
      );
      expect(gps.pidioUltimaConocida, isFalse);
    });

    test('cada motivo tiene su propia explicación', () {
      final mensajes = ErrorUbicacion.values
          .map((m) => UbicacionException(m).mensaje)
          .toList();

      expect(mensajes.toSet(), hasLength(ErrorUbicacion.values.length));
      expect(mensajes.every((m) => m.trim().isNotEmpty), isTrue);
    });
  });

  group('el mismo punto no se pregunta dos veces', () {
    test('la geocodificación inversa se cachea', () async {
      final falso = DioFalso((_) => crudoConCalle());
      final repo = GeocodingRepository(dio: falso.dio);

      const punto = LatLng(-5.1945, -80.6328);
      final primera = await repo.direccionDe(punto);
      final segunda = await repo.direccionDe(punto);

      expect(primera!.lineaCompleta, segunda!.lineaCompleta);
      expect(falso.peticiones, hasLength(1));
    });
  });

  group('EditarDireccionScreen con GPS', () {
    testWidgets('«Mi ubicación» coloca el pin y escribe la dirección',
        (tester) async {
      GeolocatorPlatform.instance =
          _GpsFalso(posicion: _posicion(-5.1945, -80.6328));
      final falso = DioFalso((_) => crudoConCalle());

      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geocodingRepositoryProvider
                .overrideWithValue(GeocodingRepository(dio: falso.dio)),
          ],
          child: const MaterialApp(home: EditarDireccionScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Mi ubicación actual'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      String valor(String etiqueta) => tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, etiqueta))
          .controller!
          .text;

      expect(valor('Calle o avenida *'), 'Avenida Grau');
      expect(valor('Número'), '450');
      expect(valor('Ciudad'), 'Piura');
      // Y una sola consulta: el `move` del mapa programa otra a los 900 ms que
      // la caché de inversas resuelve sin salir a la red.
      expect(falso.peticiones.where((p) => p.path == '/reverse'), hasLength(1));
    });

    testWidgets('sin permiso lo explica y deja seguir a mano', (tester) async {
      GeolocatorPlatform.instance =
          _GpsFalso(permiso: LocationPermission.deniedForever);
      final falso = DioFalso((_) => crudoConCalle());

      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geocodingRepositoryProvider
                .overrideWithValue(GeocodingRepository(dio: falso.dio)),
          ],
          child: const MaterialApp(home: EditarDireccionScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Mi ubicación actual'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('ajustes'), findsOneWidget);
      // El formulario sigue ahí: el GPS es un atajo, no el único camino.
      expect(find.widgetWithText(TextFormField, 'Calle o avenida *'),
          findsOneWidget);
    });
  });
}
