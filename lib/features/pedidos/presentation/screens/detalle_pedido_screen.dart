import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/errores_api.dart';
import '../../../../core/theme/estados.dart';
import '../../../../core/theme/map_style.dart';
import '../../../../shared/models/direccion.dart';
import '../../../../shared/models/pedido.dart';
import '../../../../shared/widgets/estados_vista.dart';
import '../../../../shared/widgets/mapa/piezas_mapa.dart';
import '../../../../shared/widgets/piezas_pedido.dart';
import '../pedidos_provider.dart';
import '../widgets/hoja_calificacion.dart';
import '../widgets/linea_tiempo_pedido.dart';

class DetallePedidoScreen extends ConsumerWidget {
  const DetallePedidoScreen({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedido = ref.watch(pedidoProvider(pedidoId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del pedido'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(pedidoProvider(pedidoId)),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
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

  void _recargar() {
    ref.invalidate(pedidoProvider(_pedido.id));
    // La lista también cambia: el pedido acaba de cambiar de grupo.
    ref.invalidate(pedidosProvider);
  }

  Future<void> _cancelar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Cancelar el pedido?'),
        content: Text(
          'El pedido ${_pedido.codigoSeguimiento} se cancelará y no podrá '
          'reactivarse. Tendrías que crear uno nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('No, mantenerlo'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            style: FilledButton.styleFrom(backgroundColor: MapStyle.peligro),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _trabajando = true);
    try {
      await ref
          .read(pedidosRepositoryProvider)
          .cambiarEstado(_pedido.id, 'cancelado');
      if (!mounted) return;
      _recargar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido cancelado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeDeError(e, respaldo: 'No se pudo cancelar el pedido.'))),
      );
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _calificar() async {
    final guardada = await mostrarHojaCalificacion(
      context,
      pedidoId: _pedido.id,
      repartidor: _pedido.repartidor,
    );
    if (!guardada || !mounted) return;
    _recargar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Gracias por tu calificación!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _pedido;
    final aspecto = aspectoDePedido(p.estado.codigo);

    return RefreshIndicator(
      onRefresh: () async => _recargar(),
      child: ListView(
        padding: const EdgeInsets.all(MapStyle.esp4),
        children: [
          _Cabecera(pedido: p, aspecto: aspecto),
          const SizedBox(height: MapStyle.esp4),

          // El mapa se abre para cualquier pedido vivo, no solo «en camino»: el
          // trazado origen→destino existe desde que se crea el pedido, y verlo
          // antes de que salga el repartidor es información legítima. Lo que
          // cambia es la promesa del botón.
          if (!p.estaTerminado) ...[
            FilledButton.icon(
              onPressed: () => context.push('/tracking/${p.id}'),
              icon: const Icon(Icons.map_outlined, size: 20),
              label: Text(
                p.estaEnCamino ? 'Ver seguimiento en vivo' : 'Ver recorrido',
              ),
            ),
            const SizedBox(height: MapStyle.esp4),
          ],

          if (p.puedeCalificar) ...[
            _AvisoCalificar(onCalificar: _trabajando ? null : _calificar),
            const SizedBox(height: MapStyle.esp4),
          ],

          if (p.calificacion != null) ...[
            _CalificacionDada(calificacion: p.calificacion!),
            const SizedBox(height: MapStyle.esp4),
          ],

          SeccionTarjeta(
            titulo: 'Recorrido',
            child: _Recorrido(
              origen: p.direccionOrigen,
              destino: p.direccionDestino,
            ),
          ),
          const SizedBox(height: MapStyle.esp5),

          SeccionTarjeta(
            titulo: 'Progreso',
            child: LineaTiempoPedido(pedido: p),
          ),
          const SizedBox(height: MapStyle.esp5),

          SeccionTarjeta(
            titulo: 'Detalles del envío',
            child: _Detalles(pedido: p),
          ),

          if (p.tieneRepartidor) ...[
            const SizedBox(height: MapStyle.esp5),
            SeccionTarjeta(
              titulo: 'Repartidor',
              child: _Repartidor(pedido: p),
            ),
          ],

          if (p.puedeCancelar) ...[
            const SizedBox(height: MapStyle.esp6),
            OutlinedButton.icon(
              onPressed: _trabajando ? null : _cancelar,
              icon: const Icon(Icons.cancel_outlined, size: 19),
              label: const Text('Cancelar pedido'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MapStyle.peligro,
                side: BorderSide(color: MapStyle.peligro.withOpacity(0.4)),
              ),
            ),
          ],
          const SizedBox(height: MapStyle.esp6),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.pedido, required this.aspecto});

  final Pedido pedido;
  final Aspecto aspecto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MapStyle.esp5),
      decoration: BoxDecoration(
        color: aspecto.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: aspecto.color.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EtiquetaSeccion('Código de seguimiento'),
          const SizedBox(height: MapStyle.esp2 - 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  pedido.codigoSeguimiento,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: MapStyle.textoFuerte,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Icon(aspecto.icono, color: aspecto.color, size: 26),
            ],
          ),
          const SizedBox(height: MapStyle.esp3),
          Wrap(
            spacing: MapStyle.esp2,
            runSpacing: MapStyle.esp2,
            children: [
              EstadoPedidoChip(pedido.estado.codigo, nombre: pedido.estado.nombre),
              PildoraMetrica(
                icono: Icons.event_outlined,
                texto: fechaDia(pedido.fechaCreacion),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Recorrido extends StatelessWidget {
  const _Recorrido({this.origen, this.destino});

  final Direccion? origen;
  final Direccion? destino;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Extremo(
          direccion: origen,
          icono: Icons.trip_origin,
          color: MapStyle.neutro,
          etiqueta: 'Origen',
          conHilo: true,
        ),
        _Extremo(
          direccion: destino,
          icono: Icons.place,
          color: MapStyle.primario,
          etiqueta: 'Destino',
          conHilo: false,
        ),
      ],
    );
  }
}

class _Extremo extends StatelessWidget {
  const _Extremo({
    required this.direccion,
    required this.icono,
    required this.color,
    required this.etiqueta,
    required this.conHilo,
  });

  final Direccion? direccion;
  final IconData icono;
  final Color color;
  final String etiqueta;
  final bool conHilo;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Icon(icono, size: 18, color: color),
                if (conHilo)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: MapStyle.borde,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: MapStyle.esp3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: conHilo ? MapStyle.esp4 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiqueta, style: MapStyle.etiqueta),
                  const SizedBox(height: 2),
                  Text(
                    direccion?.lineaCompleta ?? 'Dirección no disponible',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: MapStyle.textoFuerte,
                      height: 1.35,
                    ),
                  ),
                  if (direccion?.tieneReferencia == true) ...[
                    const SizedBox(height: 2),
                    Text(direccion!.referencia!, style: MapStyle.secundario),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Detalles extends StatelessWidget {
  const _Detalles({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    return Column(
      children: [
        FilaDato('Descripción', p.descripcionCorta, icono: Icons.notes_outlined),
        // Solo se pinta lo que el backend realmente trae. `peso_kg`,
        // `costo_envio` y `fecha_estimada_entrega` son opcionales y hoy nadie
        // los rellena al crear desde la app: mostrar "—" en tres filas seguidas
        // haría parecer que falta información en vez de que no aplica.
        if (p.pesoKg != null)
          FilaDato('Peso', '${p.pesoKg!.toStringAsFixed(2)} kg',
              icono: Icons.scale_outlined),
        if (p.costoEnvio != null)
          FilaDato('Costo de envío', 'S/ ${p.costoEnvio!.toStringAsFixed(2)}',
              icono: Icons.payments_outlined),
        FilaDato('Creado', fechaCorta(p.fechaCreacion),
            icono: Icons.schedule_outlined),
        if (p.fechaEstimadaEntrega != null)
          FilaDato('Entrega estimada', fechaCorta(p.fechaEstimadaEntrega!),
              icono: Icons.event_available_outlined),
        if (p.fechaEntregaReal != null)
          FilaDato('Entregado', fechaCorta(p.fechaEntregaReal!),
              icono: Icons.check_circle_outline),
      ],
    );
  }
}

class _Repartidor extends StatelessWidget {
  const _Repartidor({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final repartidor = pedido.repartidor!;
    final perfil = repartidor.perfilRepartidor;

    return Row(
      children: [
        AvatarUsuario(usuario: repartidor, radio: 24),
        const SizedBox(width: MapStyle.esp3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                repartidor.nombreCompleto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MapStyle.textoFuerte,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (perfil?.tipoVehiculo != null) perfil!.tipoVehiculo!,
                  if (perfil?.placa != null) perfil!.placa!,
                ].join(' · '),
                style: MapStyle.secundario,
              ),
            ],
          ),
        ),
        if (perfil?.calificacionPromedio != null &&
            perfil!.calificacionPromedio! > 0)
          PildoraMetrica(
            icono: Icons.star_rounded,
            texto: perfil.calificacionPromedio!.toStringAsFixed(1),
          ),
      ],
    );
  }
}

class _AvisoCalificar extends StatelessWidget {
  const _AvisoCalificar({this.onCalificar});

  final VoidCallback? onCalificar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MapStyle.esp4),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 26),
          const SizedBox(width: MapStyle.esp3),
          const Expanded(
            child: Text(
              'Tu pedido llegó. ¿Cómo estuvo la entrega?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MapStyle.textoFuerte,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: MapStyle.esp2),
          FilledButton(
            onPressed: onCalificar,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              minimumSize: const Size(96, MapStyle.tap - 8),
            ),
            child: const Text('Calificar'),
          ),
        ],
      ),
    );
  }
}

class _CalificacionDada extends StatelessWidget {
  const _CalificacionDada({required this.calificacion});

  final Calificacion calificacion;

  @override
  Widget build(BuildContext context) {
    return SeccionTarjeta(
      titulo: 'Tu calificación',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= calificacion.puntuacion
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 22,
                  color: i <= calificacion.puntuacion
                      ? const Color(0xFFF59E0B)
                      : MapStyle.neutro,
                ),
              const SizedBox(width: MapStyle.esp2),
              Text(fechaDia(calificacion.fecha), style: MapStyle.secundario),
            ],
          ),
          if (calificacion.comentario != null &&
              calificacion.comentario!.trim().isNotEmpty) ...[
            const SizedBox(height: MapStyle.esp3),
            Text(calificacion.comentario!, style: MapStyle.direccion),
          ],
        ],
      ),
    );
  }
}
