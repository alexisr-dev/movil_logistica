// Pruebas del router.
//
// El árbol de rutas tiene una trampa conocida de `go_router`: empujar una ruta
// que vive dentro del `StatefulShellRoute` desde una pantalla que vive fuera de
// él duplica la página del shell en el navegador raíz, y Flutter revienta con
// `!keyReservation.contains(key)`. Estas pruebas recorren justo esos saltos.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:movil_logistica/core/routing/app_router.dart';
import 'package:movil_logistica/features/auth/data/auth_repository.dart';
import 'package:movil_logistica/features/auth/presentation/auth_provider.dart';
import 'package:movil_logistica/features/notificaciones/presentation/notificaciones_provider.dart';
import 'package:movil_logistica/features/pedidos/presentation/pedidos_provider.dart';
import 'package:movil_logistica/shared/models/notificacion.dart';
import 'package:movil_logistica/shared/models/pedido.dart';

class _AuthFalso extends AuthNotifier {
  _AuthFalso({required bool repartidor}) : super(AuthRepository()) {
    state = AuthState(
      autenticado: true,
      rol: repartidor ? 'repartidor' : 'cliente',
    );
  }
}

Future<GoRouter> _montar(WidgetTester tester,
    {required bool repartidor}) async {
  final container = ProviderContainer(overrides: [
    authProvider.overrideWith((ref) => _AuthFalso(repartidor: repartidor)),
    notificacionesProvider.overrideWith((ref) async => <Notificacion>[]),
    noLeidasProvider.overrideWith((ref) async => 0),
    pedidosProvider.overrideWith((ref) async => <Pedido>[]),
  ]);
  addTearDown(container.dispose);

  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
  await _asentar(tester);
  return router;
}

Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Pedido _pedidoDemo() => Pedido.fromJson({
      'id': 1,
      'codigo_seguimiento': 'LOG-DEMO01',
      'estado': {
        'id': 1,
        'codigo': 'pendiente',
        'nombre': 'Pendiente',
        'orden': 1
      },
      'direccion_origen': {
        'id': 1,
        'calle': 'Av. Grau',
        'numero': '100',
        'distrito': 'Piura',
        'ciudad': 'Piura',
        'latitud': -5.19,
        'longitud': -80.63,
        'es_default': true,
      },
      'direccion_destino': {
        'id': 2,
        'calle': 'Av. Sullana',
        'numero': '200',
        'distrito': 'Sullana',
        'ciudad': 'Sullana',
        'latitud': -4.90,
        'longitud': -80.68,
        'es_default': false,
      },
      'descripcion': 'Documentos',
      'fecha_creacion': '2026-03-01T10:00:00Z',
      'historial': <dynamic>[],
      'transiciones_permitidas': <dynamic>[],
    });

void main() {
  testWidgets('el cliente abre el detalle desde la bandeja de notificaciones',
      (tester) async {
    final router = await _montar(tester, repartidor: false);

    router.push('/notificaciones');
    await _asentar(tester);
    expect(find.text('Notificaciones'), findsOneWidget);

    router.push('/pedidos/1');
    await _asentar(tester);

    expect(tester.takeException(), isNull);
    expect(router.state.uri.toString(), '/pedidos/1');
  });

  testWidgets('el repartidor abre la entrega desde la bandeja', (tester) async {
    final router = await _montar(tester, repartidor: true);

    router.push('/notificaciones');
    await _asentar(tester);
    expect(find.text('Notificaciones'), findsOneWidget);

    router.push('/entregas/1');
    await _asentar(tester);

    expect(tester.takeException(), isNull);
    expect(router.state.uri.toString(), '/entregas/1');
  });

  testWidgets('volver desde el detalle deja la bandeja en su sitio',
      (tester) async {
    final router = await _montar(tester, repartidor: false);

    router.push('/notificaciones');
    await _asentar(tester);
    router.push('/pedidos/1');
    await _asentar(tester);

    router.pop();
    await _asentar(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Notificaciones'), findsOneWidget);
  });

  testWidgets('el detalle tambien se abre desde dentro de las pestanas',
      (tester) async {
    final router = await _montar(tester, repartidor: false);

    router.go('/pedidos');
    await _asentar(tester);
    router.push('/pedidos/1');
    await _asentar(tester);

    expect(tester.takeException(), isNull);
    expect(router.state.uri.toString(), '/pedidos/1');
  });

  testWidgets('crear pedido se abre desde el inicio sin romper la pila',
      (tester) async {
    final router = await _montar(tester, repartidor: false);

    router.push('/pedidos/nuevo');
    await _asentar(tester);

    expect(tester.takeException(), isNull);
    expect(router.state.uri.toString(), '/pedidos/nuevo');
  });

  // El alta termina saltando a «Pedido creado» con un `pushReplacement` del
  // Navigator, no del router: se comprueba que ese salto convive con las
  // paginas que gestiona `go_router`.
  testWidgets('el alta puede reemplazarse por la pantalla de confirmacion',
      (tester) async {
    final router = await _montar(tester, repartidor: false);

    router.push('/pedidos/nuevo');
    await _asentar(tester);

    router.pushReplacement('/pedidos/creado', extra: _pedidoDemo());
    await _asentar(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('LOG-DEMO01'), findsOneWidget);

    // Y desde la confirmacion se salta al detalle del pedido recien creado.
    await tester.tap(find.text('Ver pedido'));
    await _asentar(tester);

    expect(tester.takeException(), isNull);
    expect(router.state.uri.toString(), '/pedidos/1');
  });

  // Sin el pedido en `extra` la confirmacion no tiene nada que confirmar.
  testWidgets('la confirmacion sin pedido cae en la lista', (tester) async {
    final router = await _montar(tester, repartidor: false);

    router.push('/pedidos/creado');
    await _asentar(tester);

    expect(tester.takeException(), isNull);
    expect(router.state.uri.toString(), '/pedidos');
  });
}
