import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/estados.dart';
import '../../../../core/theme/map_style.dart';
import '../../../../shared/widgets/estados_vista.dart';
import '../../../../shared/widgets/mapa/piezas_mapa.dart';
import '../../../../shared/widgets/piezas_pedido.dart';
import '../entregas_provider.dart';

class MisEntregasScreen extends ConsumerWidget {
  const MisEntregasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entregas = ref.watch(entregasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis entregas'),
        actions: [
          IconButton(
            onPressed: () => refrescarEntregas(ref),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: entregas.when(
        loading: () => const ListaEsqueleto(filas: 4),
        error: (e, _) => VistaError(
          error: e,
          onReintentar: () => refrescarEntregas(ref),
        ),
        data: (dia) {
          if (dia.vacio) {
            return const VistaVacia(
              icono: Icons.local_shipping_outlined,
              titulo: 'No tienes entregas asignadas',
              mensaje:
                  'El operador asigna los pedidos y planifica las rutas desde '
                  'el panel web.',
            );
          }

          final proxima = dia.proxima;

          return RefreshIndicator(
            onRefresh: () async => refrescarEntregas(ref),
            child: ListView(
              padding: const EdgeInsets.all(MapStyle.esp4),
              children: [
                if (proxima != null) ...[
                  const _Titulo('Próxima entrega'),
                  TarjetaPedido(
                    pedido: proxima.pedido,
                    ordenParada: proxima.orden,
                    horaEstimada: proxima.horaEstimada,
                    destacada: true,
                    onTap: () =>
                        context.push('/entregas/${proxima.pedido.id}'),
                    accion: FilledButton.icon(
                      onPressed: () =>
                          context.push('/entregas/${proxima.pedido.id}'),
                      icon: const Icon(Icons.navigation, size: 20),
                      label: const Text('Ver entrega'),
                    ),
                  ),
                  const SizedBox(height: MapStyle.esp6),
                ],

                if (dia.pendientes.isNotEmpty) ...[
                  _Titulo('Pendientes (${dia.pendientes.length})'),
                  ...dia.pendientes.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: MapStyle.esp3),
                      child: TarjetaPedido(
                        pedido: e.pedido,
                        ordenParada: e.orden,
                        horaEstimada: e.horaEstimada,
                        onTap: () => context.push('/entregas/${e.pedido.id}'),
                      ),
                    ),
                  ),
                  const SizedBox(height: MapStyle.esp5),
                ],

                if (dia.completadas.isNotEmpty) ...[
                  _Titulo('Completadas (${dia.completadas.length})'),
                  ...dia.completadas.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: MapStyle.esp3),
                      child: _FilaCompletada(entrega: e),
                    ),
                  ),
                ],
                const SizedBox(height: MapStyle.esp5),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: MapStyle.esp1,
        bottom: MapStyle.esp3,
      ),
      child: EtiquetaSeccion(texto),
    );
  }
}

class _FilaCompletada extends StatelessWidget {
  const _FilaCompletada({required this.entrega});

  final Entrega entrega;

  @override
  Widget build(BuildContext context) {
    final pedido = entrega.pedido;
    // El estado de la parada manda cuando existe: distingue «fallido» de
    // «entregado», mientras que el pedido devuelto podría venir de otra causa.
    final aspecto = entrega.parada != null
        ? aspectoDeParada(entrega.parada!.estado)
        : aspectoDePedido(pedido.estado.codigo);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.push('/entregas/${pedido.id}'),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MapStyle.esp4,
          vertical: MapStyle.esp1,
        ),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: aspecto.color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(aspecto.icono, size: 18, color: aspecto.color),
        ),
        title: Text(
          pedido.codigoSeguimiento,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          entrega.parada?.horaReal != null
              ? '${aspecto.etiqueta} · ${soloHora(entrega.parada!.horaReal!)}'
              : aspecto.etiqueta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, color: MapStyle.neutro),
      ),
    );
  }
}
