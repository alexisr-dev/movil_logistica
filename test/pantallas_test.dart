// Pruebas de las pantallas y de la lógica que las alimenta.
//
// Cubren lo que no se ve al compilar: que la línea de tiempo corte el camino
// cuando un pedido se cancela, que el clasificador elija bien el pedido activo,
// y que las pantallas monten con datos reales sin desbordarse.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:movil_logistica/features/pedidos/presentation/pedidos_provider.dart';
import 'package:movil_logistica/features/pedidos/presentation/widgets/linea_tiempo_pedido.dart';
import 'package:movil_logistica/shared/models/pedido.dart';
import 'package:movil_logistica/shared/widgets/estados_vista.dart';
import 'package:movil_logistica/shared/widgets/piezas_pedido.dart';

Map<String, dynamic> _estado(String codigo, String nombre, int orden) =>
    {'id': orden, 'codigo': codigo, 'nombre': nombre, 'orden': orden};

Map<String, dynamic> _direccion(int id) => {
      'id': id,
      'calle': 'Av. Arequipa',
      'numero': '1234',
      'distrito': 'Lince',
      'ciudad': 'Lima',
      'latitud': -12.09,
      'longitud': -77.04,
      'es_default': false,
    };

Pedido _pedido({
  int id = 1,
  String codigo = 'ABC123',
  String estado = 'pendiente',
  int orden = 1,
  List<String> pasados = const ['pendiente'],
  String? comentarioFinal,
}) {
  return Pedido.fromJson({
    'id': id,
    'codigo_seguimiento': codigo,
    'estado': _estado(estado, estado, orden),
    'cliente': null,
    'repartidor': null,
    'direccion_origen': _direccion(1),
    'direccion_destino': _direccion(2),
    'descripcion': 'Documentos',
    'peso_kg': null,
    'costo_envio': null,
    'fecha_creacion': '2026-03-01T10:00:00Z',
    'fecha_estimada_entrega': null,
    'fecha_entrega_real': null,
    'historial': [
      for (var i = 0; i < pasados.length; i++)
        {
          'id': i + 1,
          'estado': _estado(pasados[i], pasados[i], i + 1),
          'fecha': '2026-03-0${i + 1}T10:00:00Z',
          'comentario':
              i == pasados.length - 1 ? comentarioFinal : null,
          'usuario': 1,
        },
    ],
    'transiciones_permitidas': const [],
    'calificacion': null,
  });
}

Widget _montar(Widget pantalla) => ProviderScope(
      child: MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        // Los tres, como en `main()`: sin el de Cupertino, Flutter avisa de
        // que el locale no está soportado por todos los delegates y el aviso
        // hace fallar el test.
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: pantalla),
      ),
    );

void main() {
  // `DateFormat(..., 'es')` lanza sin esto, igual que en `main()`.
  setUpAll(() => initializeDateFormatting('es'));

  group('LineaTiempoPedido', () {
    testWidgets('pinta los cinco hitos del camino feliz', (tester) async {
      await tester.pumpWidget(_montar(
        SingleChildScrollView(child: LineaTiempoPedido(pedido: _pedido())),
      ));

      for (final etiqueta in [
        'Pendiente',
        'Confirmado',
        'En preparación',
        'En camino',
        'Entregado',
      ]) {
        expect(find.text(etiqueta), findsOneWidget);
      }
    });

    testWidgets('corta el camino cuando el pedido se cancela', (tester) async {
      await tester.pumpWidget(_montar(
        SingleChildScrollView(
          child: LineaTiempoPedido(
            pedido: _pedido(
              estado: 'cancelado',
              orden: 6,
              pasados: ['pendiente', 'cancelado'],
            ),
          ),
        ),
      ));

      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Cancelado'), findsOneWidget);
      // Los pasos que ya no van a ocurrir no se dibujan: dejarlos en gris
      // sugeriría que el pedido sigue su curso.
      expect(find.text('En camino'), findsNothing);
      expect(find.text('Entregado'), findsNothing);
    });

    testWidgets('muestra el motivo guardado en el comentario', (tester) async {
      await tester.pumpWidget(_montar(
        SingleChildScrollView(
          child: LineaTiempoPedido(
            pedido: _pedido(
              estado: 'devuelto',
              orden: 7,
              pasados: ['pendiente', 'devuelto'],
              comentarioFinal: 'Nadie en el domicilio',
            ),
          ),
        ),
      ));

      // Es donde la entrega fallida deja el motivo: no hay campo propio.
      expect(find.text('Nadie en el domicilio'), findsOneWidget);
    });
  });

  group('PedidosClasificados', () {
    test('destaca el pedido más avanzado de los que siguen vivos', () {
      final datos = PedidosClasificados(
        enCurso: [
          _pedido(id: 1, estado: 'pendiente', orden: 1),
          _pedido(id: 2, estado: 'en_camino', orden: 4),
          _pedido(id: 3, estado: 'confirmado', orden: 2),
        ],
        completados: const [],
        cancelados: const [],
      );

      // Se ordena por `estado.orden`, el mismo campo con el que el backend
      // ordena el catálogo.
      expect(datos.activo?.id, 2);
    });

    test('sin pedidos en curso no hay nada que destacar', () {
      final datos = PedidosClasificados(
        enCurso: const [],
        completados: [_pedido(id: 9, estado: 'entregado', orden: 5)],
        cancelados: const [],
      );

      expect(datos.activo, isNull);
      expect(datos.vacio, isFalse);
    });
  });

  group('TarjetaPedido', () {
    testWidgets('muestra código, destino y estado', (tester) async {
      await tester.pumpWidget(_montar(
        TarjetaPedido(pedido: _pedido(), onTap: () {}),
      ));

      expect(find.text('ABC123'), findsOneWidget);
      expect(find.text('Av. Arequipa 1234 · Lince · Lima'), findsOneWidget);
      expect(find.text('pendiente'), findsOneWidget);
    });

    testWidgets('el orden de parada sustituye al icono de estado',
        (tester) async {
      await tester.pumpWidget(_montar(
        TarjetaPedido(pedido: _pedido(), onTap: () {}, ordenParada: 3),
      ));

      // En una tarjeta pequeña el número y el icono competían: se elige uno.
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('no desborda en una pantalla estrecha', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_montar(
        TarjetaPedido(
          pedido: _pedido(codigo: 'CODIGO-MUY-LARGO-DE-SEGUIMIENTO-XYZ'),
          onTap: () {},
          ordenParada: 12,
          horaEstimada: DateTime(2026, 3, 2, 14, 30),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('Estados de vista', () {
    testWidgets('el vacío ofrece una salida', (tester) async {
      var pulsado = false;
      await tester.pumpWidget(_montar(
        VistaVacia(
          icono: Icons.inbox_outlined,
          titulo: 'Sin pedidos',
          mensaje: 'Crea el primero.',
          accion: FilledButton(
            onPressed: () => pulsado = true,
            child: const Text('Crear pedido'),
          ),
        ),
      ));

      await tester.tap(find.text('Crear pedido'));
      expect(pulsado, isTrue);
    });

    testWidgets('el error deja reintentar y no enseña la traza cruda',
        (tester) async {
      var reintentos = 0;
      await tester.pumpWidget(_montar(
        VistaError(
          error: Exception('DioException [connection error]: fallo'),
          onReintentar: () => reintentos++,
        ),
      ));

      expect(find.text('No se pudieron cargar los datos'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(reintentos, 1);
    });
  });
}
