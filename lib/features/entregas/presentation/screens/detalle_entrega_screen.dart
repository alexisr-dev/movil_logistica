import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/errores_api.dart';
import '../../../../core/theme/estados.dart';
import '../../../../core/theme/map_style.dart';
import '../../../../shared/models/pedido.dart';
import '../../../../shared/widgets/estados_vista.dart';
import '../../../../shared/widgets/piezas_pedido.dart';
import '../../../pedidos/presentation/pedidos_provider.dart';
import '../entregas_provider.dart';
import '../widgets/hoja_resultado_entrega.dart';

class DetalleEntregaScreen extends ConsumerWidget {
  const DetalleEntregaScreen({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedido = ref.watch(pedidoProvider(pedidoId));

    return Scaffold(
      appBar: AppBar(title: const Text('Entrega')),
      body: pedido.when(
        loading: () => const ListaEsqueleto(filas: 3),
        error: (e, _) => VistaError(
          error: e,
          onReintentar: () => ref.invalidate(pedidoProvider(pedidoId)),
        ),
        data: (p) => _Contenido(pedido: p),
      ),
    );
  }
}

class _Contenido extends ConsumerStatefulWidget {
  const _Contenido({required this.pedido});

  final Pedido pedido;

  @override
  ConsumerState<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends ConsumerState<_Contenido> {
  bool _trabajando = false;

  Pedido get _pedido => widget.pedido;

  int? get _paradaId {
    final dia = ref.read(entregasProvider).valueOrNull;
    if (dia == null) return null;
    for (final entrega in [
      if (dia.proxima != null) dia.proxima!,
      ...dia.pendientes,
      ...dia.completadas,
    ]) {
      if (entrega.pedido.id == _pedido.id) return entrega.paradaId;
    }
    return null;
  }

  void _recargar() {
    ref.invalidate(pedidoProvider(_pedido.id));
    refrescarEntregas(ref);
  }

  Future<void> _ponerEnCamino() async {
    setState(() => _trabajando = true);
    try {
      await ref.read(entregasServiceProvider).ponerEnCamino(_pedido);
      if (!mounted) return;
      _recargar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido en camino. ¡Buen viaje!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeDeError(e, respaldo: 'No se pudo iniciar la entrega.'))),
      );
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _entregar() async {
    setState(() => _trabajando = true);
    final cierre = await confirmarEntrega(
      context,
      ref,
      pedidoId: _pedido.id,
      codigo: _pedido.codigoSeguimiento,
      paradaId: _paradaId,
    );
    if (!mounted) return;
    setState(() => _trabajando = false);
    if (cierre == null) return;
    _recargar();
    mostrarResultadoCierre(context, cierre);
  }

  Future<void> _fallar() async {
    final cierre = await registrarEntregaFallida(
      context,
      ref,
      pedidoId: _pedido.id,
      codigo: _pedido.codigoSeguimiento,
      paradaId: _paradaId,
    );
    if (!mounted || cierre == null) return;
    _recargar();
    mostrarResultadoCierre(context, cierre);
  }

  @override
  Widget build(BuildContext context) {
    // Dispara la carga de pedidos y rutas: es lo que alimenta `_paradaId`.
    ref.watch(entregasProvider);

    final p = _pedido;
    final destino = p.direccionDestino;
    final cliente = p.cliente;
    final aspecto = aspectoDePedido(p.estado.codigo);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(
            MapStyle.esp4,
            MapStyle.esp4,
            MapStyle.esp4,
            140, // hueco para la barra de acciones fija
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.codigoSeguimiento, style: MapStyle.titulo),
                ),
                EstadoPedidoChip(p.estado.codigo, nombre: p.estado.nombre),
              ],
            ),
            const SizedBox(height: MapStyle.esp5),

            SeccionTarjeta(
              titulo: 'Dirección de entrega',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destino?.lineaCompleta ?? 'Dirección no disponible',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MapStyle.textoFuerte,
                      height: 1.35,
                    ),
                  ),
                  if (destino?.tieneReferencia == true) ...[
                    const SizedBox(height: MapStyle.esp3),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(MapStyle.esp3),
                      decoration: BoxDecoration(
                        color: MapStyle.aviso.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              size: 17, color: MapStyle.aviso),
                          const SizedBox(width: MapStyle.esp2),
                          Expanded(
                            child: Text(
                              destino!.referencia!,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: MapStyle.textoFuerte,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: MapStyle.esp5),

            if (cliente != null)
              SeccionTarjeta(
                titulo: 'Cliente',
                child: Row(
                  children: [
                    AvatarUsuario(usuario: cliente, radio: 22),
                    const SizedBox(width: MapStyle.esp3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cliente.nombreCompleto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: MapStyle.textoFuerte,
                            ),
                          ),
                          Text(
                            // El teléfono es opcional en el modelo.
                            cliente.tieneTelefono
                                ? cliente.telefono!
                                : 'Sin teléfono registrado',
                            style: MapStyle.secundario,
                          ),
                        ],
                      ),
                    ),
                    // No hay marcador telefónico: añadirlo exigiría el paquete
                    // `url_launcher`, que el proyecto no tiene. Se muestra el
                    // número para marcarlo a mano en lugar de un botón muerto.
                  ],
                ),
              ),

            const SizedBox(height: MapStyle.esp5),
            SeccionTarjeta(
              titulo: 'Pedido',
              child: Column(
                children: [
                  FilaDato('Contenido', p.descripcionCorta,
                      icono: Icons.notes_outlined),
                  if (p.pesoKg != null)
                    FilaDato('Peso', '${p.pesoKg!.toStringAsFixed(2)} kg',
                        icono: Icons.scale_outlined),
                  if (p.fechaEstimadaEntrega != null)
                    FilaDato(
                      'Hora estimada',
                      fechaCorta(p.fechaEstimadaEntrega!),
                      icono: Icons.schedule_outlined,
                    ),
                  FilaDato('Origen',
                      p.direccionOrigen?.lineaCompleta ?? 'No disponible',
                      icono: Icons.trip_origin),
                ],
              ),
            ),

            if (p.estaTerminado) ...[
              const SizedBox(height: MapStyle.esp5),
              Container(
                padding: const EdgeInsets.all(MapStyle.esp4),
                decoration: BoxDecoration(
                  color: aspecto.color.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: aspecto.color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(aspecto.icono, color: aspecto.color, size: 22),
                    const SizedBox(width: MapStyle.esp3),
                    Expanded(
                      child: Text(
                        'Esta entrega ya está cerrada como ${aspecto.etiqueta.toLowerCase()}.',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MapStyle.textoFuerte,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        if (!p.estaTerminado)
          Align(
            alignment: Alignment.bottomCenter,
            child: _BarraAcciones(
              pedido: p,
              trabajando: _trabajando,
              onEnCamino: _ponerEnCamino,
              onEntregar: _entregar,
              onFallar: _fallar,
            ),
          ),
      ],
    );
  }
}

class _BarraAcciones extends StatelessWidget {
  const _BarraAcciones({
    required this.pedido,
    required this.trabajando,
    required this.onEnCamino,
    required this.onEntregar,
    required this.onFallar,
  });

  final Pedido pedido;
  final bool trabajando;
  final VoidCallback onEnCamino;
  final VoidCallback onEntregar;
  final VoidCallback onFallar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MapStyle.superficie,
        border: Border(top: BorderSide(color: MapStyle.borde)),
        boxShadow: MapStyle.sombraHoja,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(MapStyle.esp4),
          child: pedido.estaEnCamino
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Acción principal mientras se va de camino: el mapa, que
                    // es donde se emite el GPS que ve el cliente. Cerrar la
                    // entrega se hace al llegar, y también desde allí.
                    FilledButton.icon(
                      onPressed: trabajando
                          ? null
                          : () => context.push('/reparto/${pedido.id}'),
                      icon: const Icon(Icons.navigation, size: 21),
                      label: const Text('Ir al mapa y compartir ubicación'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                    ),
                    const SizedBox(height: MapStyle.esp2),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: trabajando ? null : onEntregar,
                            icon: const Icon(Icons.check_circle_outline, size: 19),
                            label: const Text('Entregado'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: MapStyle.exito,
                              side: BorderSide(
                                  color: MapStyle.exito.withOpacity(0.45)),
                            ),
                          ),
                        ),
                        const SizedBox(width: MapStyle.esp2),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: trabajando ? null : onFallar,
                            icon: const Icon(Icons.error_outline, size: 19),
                            label: const Text('No pude'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: MapStyle.peligro,
                              side: BorderSide(
                                  color: MapStyle.peligro.withOpacity(0.4)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: trabajando ? null : onEnCamino,
                      icon: trabajando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text('Iniciar entrega'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                    ),
                    const SizedBox(height: MapStyle.esp2),
                    // El recorrido existe desde que se crea el pedido (origen y
                    // destino son obligatorios), así que se puede consultar
                    // antes de salir: es justo cuando hace falta saber a dónde
                    // se va. Emitir la ubicación sigue siendo una acción aparte.
                    OutlinedButton.icon(
                      onPressed: () => context.push('/reparto/${pedido.id}'),
                      icon: const Icon(Icons.map_outlined, size: 19),
                      label: const Text('Ver recorrido en el mapa'),
                    ),
                    const SizedBox(height: MapStyle.esp2 - 4),
                    const Text(
                      'Iniciar entrega marcará el pedido en camino y avisará al cliente.',
                      style: MapStyle.secundario,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
