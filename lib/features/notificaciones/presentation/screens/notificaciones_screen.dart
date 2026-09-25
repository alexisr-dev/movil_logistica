import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/map_style.dart';
import '../../../../shared/models/notificacion.dart';
import '../../../../shared/widgets/estados_vista.dart';
import '../../../../shared/widgets/piezas_pedido.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../notificaciones_provider.dart';

class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key});

  static const _iconos = {
    'cambio_estado': Icons.swap_horiz,
    'asignacion': Icons.assignment_ind_outlined,
    'ruta_asignada': Icons.route_outlined,
    'ruta_actualizada': Icons.edit_road_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificaciones = ref.watch(notificacionesProvider);
    final esRepartidor = ref.watch(authProvider).esRepartidor;
    final sinLeer = notificaciones.valueOrNull?.where((n) => !n.leido) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (sinLeer.isNotEmpty)
            TextButton(
              onPressed: () async {
                await ref
                    .read(notificacionesRepositoryProvider)
                    .marcarTodas(sinLeer.map((n) => n.id));
                ref.invalidate(notificacionesProvider);
              },
              child: const Text('Marcar todas'),
            ),
        ],
      ),
      body: notificaciones.when(
        loading: () => const ListaEsqueleto(filas: 5),
        error: (e, _) => VistaError(
          error: e,
          onReintentar: () => ref.invalidate(notificacionesProvider),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return const VistaVacia(
              icono: Icons.notifications_none,
              titulo: 'No tienes notificaciones',
              mensaje: 'Aquí te avisaremos de cada cambio en tus pedidos.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificacionesProvider);
              await ref.read(notificacionesProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(MapStyle.esp4),
              itemCount: lista.length,
              separatorBuilder: (_, __) => const SizedBox(height: MapStyle.esp2),
              itemBuilder: (_, i) => _Fila(
                notificacion: lista[i],
                icono: _iconos[lista[i].tipo] ?? Icons.notifications_none,
                onTap: () => _abrir(context, ref, lista[i], esRepartidor),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _abrir(
    BuildContext context,
    WidgetRef ref,
    Notificacion notificacion,
    bool esRepartidor,
  ) async {
    if (!notificacion.leido) {
      // Sin await: marcarla es un efecto secundario, no debe retrasar la
      // navegación. Si falla, seguirá sin leer y se reintentará al volver.
      ref
          .read(notificacionesRepositoryProvider)
          .marcarLeida(notificacion.id)
          .then((_) => ref.invalidate(notificacionesProvider))
          .catchError((_) => notificacion);
    }

    final pedidoId = notificacion.pedidoId;
    if (pedidoId == null || !context.mounted) return;
    // Cada rol tiene su propia pantalla de detalle.
    context.push(
      esRepartidor ? '/entregas/$pedidoId' : '/pedidos/$pedidoId',
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.notificacion,
    required this.icono,
    required this.onTap,
  });

  final Notificacion notificacion;
  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sinLeer = !notificacion.leido;

    return Card(
      color: sinLeer ? MapStyle.primario.withOpacity(0.04) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: sinLeer ? MapStyle.primario.withOpacity(0.28) : MapStyle.borde,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MapStyle.esp4 - 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (sinLeer ? MapStyle.primario : MapStyle.neutro)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icono,
                  size: 19,
                  color: sinLeer ? MapStyle.primario : MapStyle.neutro,
                ),
              ),
              const SizedBox(width: MapStyle.esp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notificacion.tituloVisible,
                      style: TextStyle(
                        fontSize: 14.5,
                        // El punto azul y la negrita dicen lo mismo, pero la
                        // negrita también se lee de reojo en escala de grises.
                        fontWeight:
                            sinLeer ? FontWeight.w700 : FontWeight.w600,
                        color: MapStyle.textoFuerte,
                        height: 1.3,
                      ),
                    ),
                    if (notificacion.mensajeVisible.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(notificacion.mensajeVisible,
                          style: MapStyle.secundario),
                    ],
                    const SizedBox(height: MapStyle.esp2 - 3),
                    Text(
                      hace(notificacion.fechaCreacion),
                      style: MapStyle.secundario.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (sinLeer)
                Container(
                  margin: const EdgeInsets.only(left: MapStyle.esp2, top: 4),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: MapStyle.primario,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
