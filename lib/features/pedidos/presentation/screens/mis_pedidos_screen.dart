import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/map_style.dart';
import '../../../../shared/models/pedido.dart';
import '../../../../shared/widgets/estados_vista.dart';
import '../../../../shared/widgets/piezas_pedido.dart';
import '../pedidos_provider.dart';

class MisPedidosScreen extends ConsumerWidget {
  const MisPedidosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clasificados = ref.watch(pedidosClasificadosProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis pedidos'),
          actions: [
            IconButton(
              onPressed: () => context.push('/pedidos/nuevo'),
              icon: const Icon(Icons.add),
              tooltip: 'Crear pedido',
            ),
          ],
          bottom: TabBar(
            labelColor: MapStyle.primario,
            unselectedLabelColor: MapStyle.textoSuave,
            indicatorColor: MapStyle.primario,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle:
                const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
            tabs: [
              _Pestana('En curso', clasificados.valueOrNull?.enCurso.length),
              _Pestana('Completados', clasificados.valueOrNull?.completados.length),
              _Pestana('Cancelados', clasificados.valueOrNull?.cancelados.length),
            ],
          ),
        ),
        body: clasificados.when(
          loading: () => const ListaEsqueleto(filas: 4),
          error: (e, _) => VistaError(
            error: e,
            onReintentar: () => ref.invalidate(pedidosProvider),
          ),
          data: (datos) => TabBarView(
            children: [
              _Lista(
                pedidos: datos.enCurso,
                vacio: const VistaVacia(
                  icono: Icons.local_shipping_outlined,
                  titulo: 'No tienes pedidos en curso',
                  mensaje: 'Los pedidos activos aparecen aquí hasta que se entregan.',
                ),
              ),
              _Lista(
                pedidos: datos.completados,
                vacio: const VistaVacia(
                  icono: Icons.check_circle_outline,
                  titulo: 'Aún no hay entregas completadas',
                  mensaje: 'Cuando recibas un pedido lo verás aquí, y podrás calificarlo.',
                ),
              ),
              _Lista(
                pedidos: datos.cancelados,
                vacio: const VistaVacia(
                  icono: Icons.cancel_outlined,
                  titulo: 'Sin pedidos cancelados',
                  mensaje: 'Aquí aparecerían los pedidos cancelados o devueltos.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana(this.titulo, this.total);

  final String titulo;
  final int? total;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 46,
      child: Text(
        total == null || total == 0 ? titulo : '$titulo ($total)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _Lista extends ConsumerWidget {
  const _Lista({required this.pedidos, required this.vacio});

  final List<Pedido> pedidos;
  final Widget vacio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> recargar() async {
      ref.invalidate(pedidosProvider);
      await ref.read(pedidosProvider.future);
    }

    if (pedidos.isEmpty) {
      // `AlwaysScrollable` para que el gesto de recargar funcione también sobre
      // el estado vacío, que es justo cuando uno quiere reintentar.
      return RefreshIndicator(
        onRefresh: recargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
            vacio,
          ],
        ),
      );
    }

    final ordenados = [...pedidos]
      ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));

    return RefreshIndicator(
      onRefresh: recargar,
      child: ListView.separated(
        padding: const EdgeInsets.all(MapStyle.esp4),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: ordenados.length,
        separatorBuilder: (_, __) => const SizedBox(height: MapStyle.esp3),
        itemBuilder: (_, i) {
          final pedido = ordenados[i];
          return TarjetaPedido(
            pedido: pedido,
            onTap: () => context.push('/pedidos/${pedido.id}'),
            // Mientras el pedido siga vivo hay recorrido que enseñar; el
            // seguimiento en vivo solo cuando ya va en camino.
            accion: pedido.estaTerminado
                ? null
                : (pedido.estaEnCamino
                    ? FilledButton.icon(
                        onPressed: () => context.push('/tracking/${pedido.id}'),
                        icon: const Icon(Icons.map_outlined, size: 19),
                        label: const Text('Ver seguimiento'),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => context.push('/tracking/${pedido.id}'),
                        icon: const Icon(Icons.map_outlined, size: 19),
                        label: const Text('Ver recorrido'),
                      )),
          );
        },
      ),
    );
  }
}
