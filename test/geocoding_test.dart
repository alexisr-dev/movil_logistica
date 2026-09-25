// Pruebas de la geocodificación: texto -> coordenadas y coordenadas -> texto.
//
// Nada de red real. Nominatim se sustituye por un interceptor de Dio que
// devuelve respuestas escritas a mano, así que lo que se prueba es lo único que
// es nuestro: la limpieza de la respuesta y las tres reglas que protegen al
// servicio (mínimo de letras, caché y una petición por segundo).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:movil_logistica/features/direcciones/data/geocoding_repository.dart';
import 'package:movil_logistica/features/direcciones/presentation/geocoding_provider.dart';
import 'package:movil_logistica/features/direcciones/presentation/screens/editar_direccion_screen.dart';
import 'package:movil_logistica/shared/models/direccion.dart';
import 'package:movil_logistica/shared/models/lugar.dart';
import 'package:movil_logistica/shared/widgets/buscador_direccion.dart';

import 'apoyo/nominatim_falso.dart';

void main() {
  group('Lugar.fromNominatim limpia la respuesta', () {
    test('se queda con calle, número, distrito y ciudad', () {
      final lugar = Lugar.fromNominatim(crudoConCalle());

      expect(lugar.calle, 'Avenida Grau');
      expect(lugar.numero, '450');
      expect(lugar.distrito, 'Miraflores');
      expect(lugar.ciudad, 'Piura');
      expect(lugar.punto.latitude, closeTo(-5.1945, 0.0001));
      expect(lugar.punto.longitude, closeTo(-80.6328, 0.0001));
    });

    test('el texto visible no arrastra código postal ni país', () {
      final linea = Lugar.fromNominatim(crudoConCalle()).lineaCompleta;

      expect(linea, 'Avenida Grau 450, Miraflores, Piura');
      expect(linea, isNot(contains('20001')));
      expect(linea, isNot(contains('Perú')));
      expect(linea, isNot(contains('-80.6')));
    });

    test('un lugar sin calle usa su nombre propio', () {
      final lugar = Lugar.fromNominatim(crudoSinCalle());

      expect(lugar.etiqueta, 'Plaza Mayor');
      expect(lugar.lineaCompleta, 'Plaza Mayor, Cercado de Lima, Lima');
    });

    test('no repite el distrito cuando coincide con la ciudad', () {
      // En provincias Nominatim devuelve «Piura» en las dos claves, y sin esto
      // el usuario leía «Piura, Piura».
      final lugar = Lugar.fromNominatim({
        'lat': '-5.19',
        'lon': '-80.63',
        'display_name': 'Calle Libertad, Piura, Perú',
        'address': {
          'road': 'Calle Libertad',
          'town': 'Piura',
          'city': 'PIURA',
        },
      });

      expect(lugar.detalle, 'Piura');
    });

    test('sin dirección estructurada cae en el primer tramo del nombre largo',
        () {
      final lugar = Lugar.fromNominatim({
        'lat': '-5.19',
        'lon': '-80.63',
        'display_name': 'Peaje Sullana, Carretera Panamericana, Piura, Perú',
      });

      expect(lugar.etiqueta, 'Peaje Sullana');
    });
  });

  group('GeocodingRepository protege el servicio', () {
    test('menos de tres letras no sale a la red', () async {
      final falso = DioFalso((_) => [crudoConCalle()]);
      final repo = GeocodingRepository(dio: falso.dio);

      expect(await repo.buscar('av'), isEmpty);
      expect(falso.peticiones, isEmpty);
    });

    test('la misma consulta no se pide dos veces', () async {
      final falso = DioFalso((_) => [crudoConCalle()]);
      final repo = GeocodingRepository(dio: falso.dio);

      final primera = await repo.buscar('Av. Grau');
      final segunda = await repo.buscar('Av. Grau');

      expect(primera.single.etiqueta, 'Avenida Grau 450');
      expect(segunda.single.etiqueta, 'Avenida Grau 450');
      expect(falso.peticiones, hasLength(1));
    });

    test('sesga por país y por zona cuando se le da un punto', () async {
      final falso = DioFalso((_) => [crudoConCalle()]);
      final repo = GeocodingRepository(dio: falso.dio);

      await repo.buscar('Av. Grau', cerca: const LatLng(-5.19, -80.63));

      final consulta = falso.peticiones.single.queryParameters;
      expect(consulta['countrycodes'], 'pe');
      expect(consulta['viewbox'], isNotNull);
      // `bounded=0`: es un sesgo, no una jaula. Escribir el nombre de otra
      // ciudad tiene que seguir encontrándola.
      expect(consulta['bounded'], 0);
    });

    test('un fallo de red devuelve lista vacía, no una excepción', () async {
      final falso = DioFalso((_) => null);
      final repo = GeocodingRepository(dio: falso.dio);

      expect(await repo.buscar('Av. Grau'), isEmpty);
    });
  });

  group('geocodificación inversa', () {
    test('convierte un punto en dirección legible', () async {
      final falso = DioFalso((_) => crudoConCalle());
      final repo = GeocodingRepository(dio: falso.dio);

      final lugar = await repo.direccionDe(const LatLng(-5.1945, -80.6328));

      expect(lugar!.lineaCompleta, 'Avenida Grau 450, Miraflores, Piura');
      expect(falso.peticiones.single.path, '/reverse');
    });

    test('un punto sin dirección devuelve null y no inventa una', () async {
      final falso = DioFalso((_) => {'error': 'Unable to geocode'});
      final repo = GeocodingRepository(dio: falso.dio);

      expect(await repo.direccionDe(const LatLng(0, 0)), isNull);
    });
  });

  group('Direccion.lineaHumana', () {
    Direccion crear({String? numero, String? referencia}) => Direccion(
          id: 1,
          calle: 'Av. Lima',
          latitud: -12.0,
          longitud: -77.0,
          numero: numero,
          distrito: 'Miraflores',
          ciudad: 'Lima',
          referencia: referencia,
        );

    test('junta calle, número y referencia', () {
      expect(
        crear(numero: '450', referencia: 'frente al parque').lineaHumana,
        'Av. Lima 450, frente al parque',
      );
    });

    test('sin referencia se queda en la calle', () {
      expect(crear(numero: '450').lineaHumana, 'Av. Lima 450');
    });
  });

  group('EditarDireccionScreen', () {
    testWidgets('elegir una sugerencia rellena los campos del formulario',
        (tester) async {
      final falso = DioFalso((_) => [crudoConCalle()]);

      // El formulario es largo y el `ListView` solo construye lo que cabe:
      // en la ventana de 800x600 por defecto los campos de texto ni existen.
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geocodingRepositoryProvider.overrideWithValue(
              GeocodingRepository(dio: falso.dio),
            ),
          ],
          child: const MaterialApp(home: EditarDireccionScreen()),
        ),
      );
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextField, 'Buscar calle, avenida o lugar'),
          'Av. Grau');
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Avenida Grau 450'));
      await tester.pump();

      // Las coordenadas se guardaron por dentro; lo que se ve es texto.
      String valor(String etiqueta) => tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, etiqueta))
          .controller!
          .text;

      expect(valor('Calle o avenida *'), 'Avenida Grau');
      expect(valor('Número'), '450');
      expect(valor('Distrito'), 'Miraflores');
      expect(valor('Ciudad'), 'Piura');
      expect(find.textContaining('Avenida Grau 450, Miraflores, Piura'),
          findsWidgets);
    });
  });

  group('BuscadorDireccion', () {
    Future<void> montar(
        WidgetTester tester, DioFalso falso, List<Lugar> elegidos) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geocodingRepositoryProvider.overrideWithValue(
              GeocodingRepository(dio: falso.dio),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BuscadorDireccion(onElegido: elegidos.add),
            ),
          ),
        ),
      );
    }

    testWidgets('escribir poco no consulta nada', (tester) async {
      final falso = DioFalso((_) => [crudoConCalle()]);
      await montar(tester, falso, []);

      await tester.enterText(find.byType(TextField), 'av');
      await tester.pump(const Duration(seconds: 2));

      expect(falso.peticiones, isEmpty);
    });

    testWidgets('una ráfaga de teclas es una sola petición', (tester) async {
      final falso = DioFalso((_) => [crudoConCalle()]);
      await montar(tester, falso, []);

      for (final trozo in ['Av.', 'Av. G', 'Av. Gra', 'Av. Grau']) {
        await tester.enterText(find.byType(TextField), trozo);
        await tester.pump(const Duration(milliseconds: 120));
      }
      await tester.pump(const Duration(seconds: 2));

      expect(falso.peticiones, hasLength(1));
      expect(falso.peticiones.single.queryParameters['q'], 'Av. Grau');
    });

    testWidgets('al tocar una sugerencia entrega el lugar con coordenadas',
        (tester) async {
      final falso = DioFalso((_) => [crudoConCalle()]);
      final elegidos = <Lugar>[];
      await montar(tester, falso, elegidos);

      await tester.enterText(find.byType(TextField), 'Av. Grau');
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Avenida Grau 450'), findsOneWidget);
      expect(find.text('Miraflores, Piura'), findsOneWidget);

      await tester.tap(find.text('Avenida Grau 450'));
      await tester.pump();

      expect(elegidos.single.punto.latitude, closeTo(-5.1945, 0.0001));
      expect(elegidos.single.numero, '450');
    });

    testWidgets('sin coincidencias lo dice en vez de quedarse en blanco',
        (tester) async {
      final falso = DioFalso((_) => <dynamic>[]);
      await montar(tester, falso, []);

      await tester.enterText(find.byType(TextField), 'Calle que no existe');
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('Sin coincidencias'), findsOneWidget);
    });
  });
}
