import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/map_style.dart';
import '../../../../shared/widgets/estados_vista.dart';
import '../../../../shared/widgets/piezas_pedido.dart';
import '../../../pedidos/presentation/pedidos_provider.dart';

class SeguimientoScreen extends ConsumerWidget {
  const SeguimientoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clasificados = ref.watch(pedidosClasificadosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento')),
      body: clasificados.when(
        loading: () => const ListaEsqueleto(filas: 3),
        error: (e, _) => VistaError(
          error: e,
          onReintentar: () => ref.invalidate(pedidosProvider),
        ),
        data: (datos) {
          // Todo pedido vivo tiene mapa: su recorrido origen→destino existe
          // desde que se crea. Lo que solo aparece «en camino» es la posición
          // del repartidor, porque hasta entonces no hay nada que retransmitir.
          final seguibles = datos.enCurso;
          if (seguibles.isEmpty) {
            return const _SinPedidos();
          }

          final enCamino = seguibles.where((p) => p.estaEnCamino).length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pedidosProvider);
              await ref.read(pedidosProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(MapStyle.esp4),
              children: [
                Text(
                  enCamino == 0
                      ? 'Ninguno de tus pedidos ha salido todavía. Puedes ver el '
                          'recorrido que hará cada uno.'
                      : (enCamino == 1
                          ? 'Tienes 1 pedido en camino ahora mismo.'
                          : 'Tienes $enCamino pedidos en camino ahora mismo.'),
                  style: MapStyle.direccion,
                ),
                const SizedBox(height: MapStyle.esp4),
                ...seguibles.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: MapStyle.esp3),
                    child: TarjetaPedido(
                      pedido: p,
                      destacada: p.estaEnCamino,
                      onTap: () => context.push('/tracking/${p.id}'),
                      accion: p.estaEnCamino
                          ? FilledButton.icon(
                              onPressed: () => context.push('/tracking/${p.id}'),
                              icon: const Icon(Icons.map_outlined, size: 20),
                              label: const Text('Seguir en vivo'),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => context.push('/tracking/${p.id}'),
                              icon: const Icon(Icons.map_outlined, size: 19),
                              label: const Text('Ver recorrido'),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SinPedidos extends StatelessWidget {
  const _SinPedidos();

  @override
  Widget build(BuildContext context) {
    return VistaVacia(
      icono: Icons.map_outlined,
      titulo: 'Nada que seguir todavía',
      mensaje: 'Cuando tengas un pedido en curso podrás ver aquí su recorrido, '
          'y al repartidor moverse en cuanto salga.',
      accion: FilledButton.icon(
        onPressed: () => context.push('/pedidos/nuevo'),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Crear pedido'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(220, MapStyle.tap),
        ),
      ),
    );
  }
}
