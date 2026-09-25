import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/recuperar_password_screen.dart';
import '../../features/auth/presentation/registro_screen.dart';
import '../../features/direcciones/presentation/screens/mis_direcciones_screen.dart';
import '../../features/entregas/presentation/screens/detalle_entrega_screen.dart';
import '../../features/entregas/presentation/screens/mis_entregas_screen.dart';
import '../../features/inicio/presentation/screens/home_cliente_screen.dart';
import '../../features/inicio/presentation/screens/home_repartidor_screen.dart';
import '../../features/notificaciones/presentation/screens/notificaciones_screen.dart';
import '../../features/pedidos/presentation/screens/crear_pedido_screen.dart';
import '../../features/pedidos/presentation/screens/detalle_pedido_screen.dart';
import '../../features/pedidos/presentation/screens/mis_pedidos_screen.dart';
import '../../features/pedidos/presentation/screens/pedido_creado_screen.dart';
import '../../features/perfil/presentation/screens/perfil_screen.dart';
import '../../features/reportes/presentation/screens/reportes_repartidor_screen.dart';
import '../../features/rutas/presentation/screens/mapa_ruta_screen.dart';
import '../../features/tracking/presentation/screens/reparto_screen.dart';
import '../../features/tracking/presentation/screens/seguimiento_screen.dart';
import '../../features/tracking/presentation/screens/tracking_tiempo_real_screen.dart';
import '../../shared/models/pedido.dart';
import 'shell_principal.dart';

class _RefrescoAuth extends ChangeNotifier {
  _RefrescoAuth(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

const _rutasPublicas = {'/login', '/registro', '/recuperar'};

final _navegadorRaiz = GlobalKey<NavigatorState>();

const _inicioCliente = '/inicio';
const _inicioRepartidor = '/hoy';

const _ramasCliente = ['/inicio', '/pedidos', '/seguimiento', '/perfil'];
const _ramasRepartidor = [
  '/hoy',
  '/entregas',
  '/recorrido',
  '/rendimiento',
  '/mi-perfil',
];

bool _perteneceA(List<String> ramas, String ubicacion) {
  return ramas.any((r) => ubicacion == r || ubicacion.startsWith('$r/'));
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresco = _RefrescoAuth(ref);
  ref.onDispose(refresco.dispose);

  return GoRouter(
    navigatorKey: _navegadorRaiz,
    initialLocation: _inicioCliente,
    refreshListenable: refresco,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final ubicacion = state.matchedLocation;
      final esPublica = _rutasPublicas.contains(ubicacion);

      // Sin sesión no se entra a ninguna pantalla interna.
      if (!auth.autenticado) return esPublica ? null : '/login';

      // Con sesión, las pantallas de acceso dejan de tener sentido.
      if (esPublica) {
        return auth.esRepartidor ? _inicioRepartidor : _inicioCliente;
      }

      // Guarda en los dos sentidos: un cliente no tiene recorrido ni métricas
      // de reparto, y un repartidor no crea pedidos ni gestiona direcciones.
      // Antes solo se comprobaba el primer caso.
      if (auth.esRepartidor && _perteneceA(_ramasCliente, ubicacion)) {
        return _inicioRepartidor;
      }
      if (!auth.esRepartidor && _perteneceA(_ramasRepartidor, ubicacion)) {
        return _inicioCliente;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/registro', builder: (_, __) => const RegistroScreen()),
      GoRoute(
        path: '/recuperar',
        builder: (_, __) => const RecuperarPasswordScreen(),
      ),

      // ---------------------------------------------------------------------
      // Cliente: Inicio · Pedidos · Seguimiento · Perfil
      // ---------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) =>
            ShellPrincipal(navigationShell: shell, esRepartidor: false),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/inicio', builder: (_, __) => const HomeClienteScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/pedidos',
              builder: (_, __) => const MisPedidosScreen(),
              routes: [
                // Antes que `:id`, o "nuevo" se leería como el id del pedido.
                GoRoute(
                  path: 'nuevo',
                  parentNavigatorKey: _navegadorRaiz,
                  builder: (_, __) => const CrearPedidoScreen(),
                ),
                // Tambien antes que `:id`, y con el pedido recien creado en
                // `extra`: es un resultado, no un recurso con URL propia. Sin
                // ese objeto la pantalla no tiene nada que confirmar, asi que
                // se cae a la lista en vez de romper.
                GoRoute(
                  path: 'creado',
                  parentNavigatorKey: _navegadorRaiz,
                  redirect: (_, state) =>
                      state.extra is Pedido ? null : '/pedidos',
                  builder: (_, state) =>
                      PedidoCreadoScreen(pedido: state.extra! as Pedido),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _navegadorRaiz,
                  builder: (_, state) => DetallePedidoScreen(
                      pedidoId: int.parse(state.pathParameters['id']!)),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/seguimiento',
              builder: (_, __) => const SeguimientoScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/perfil', builder: (_, __) => const PerfilScreen()),
          ]),
        ],
      ),

      // ---------------------------------------------------------------------
      // Repartidor: Inicio · Entregas · Recorrido · Rendimiento · Perfil
      // ---------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) =>
            ShellPrincipal(navigationShell: shell, esRepartidor: true),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/hoy', builder: (_, __) => const HomeRepartidorScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/entregas',
              builder: (_, __) => const MisEntregasScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _navegadorRaiz,
                  builder: (_, state) => DetalleEntregaScreen(
                      pedidoId: int.parse(state.pathParameters['id']!)),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/recorrido', builder: (_, __) => const MapaRutaScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/rendimiento',
              builder: (_, __) => const ReportesRepartidorScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/mi-perfil', builder: (_, __) => const PerfilScreen()),
          ]),
        ],
      ),

      // ---------------------------------------------------------------------
      // Pantalla completa: se abren por encima de la barra de pestañas.
      // ---------------------------------------------------------------------
      GoRoute(
        path: '/tracking/:id',
        builder: (_, state) => TrackingTiempoRealScreen(
            pedidoId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/reparto/:id',
        builder: (_, state) =>
            RepartoScreen(pedidoId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/notificaciones',
        builder: (_, __) => const NotificacionesScreen(),
      ),
      GoRoute(
        path: '/direcciones',
        builder: (_, __) => const MisDireccionesScreen(),
      ),
    ],
  );
});
