import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/map_style.dart';
import '../../../../shared/widgets/mapa/encabezado_mapa.dart';
import '../../../../shared/widgets/mapa/hoja_mapa.dart';
import '../../../../shared/widgets/mapa/piezas_mapa.dart';
import '../../../entregas/presentation/entregas_provider.dart';
import '../../../entregas/presentation/widgets/hoja_resultado_entrega.dart';
import '../../../pedidos/data/pedidos_repository.dart';
import '../reparto_provider.dart';
import '../widgets/mapa_entrega.dart';

class RepartoScreen extends ConsumerStatefulWidget {
  const RepartoScreen({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  ConsumerState<RepartoScreen> createState() => _RepartoScreenState();
}

class _RepartoScreenState extends ConsumerState<RepartoScreen> {
  final _pedidos = PedidosRepository();
  RutaEntrega? _ruta;

  double _altoHoja = 190;

  @override
  void initState() {
    super.initState();
    _cargarRuta();
  }

  Future<void> _cargarRuta() async {
    try {
      final ruta = await _pedidos.ruta(widget.pedidoId);
      if (mounted) setState(() => _ruta = ruta);
    } catch (_) {
      // El reparto funciona igual sin el trazado; no se bloquea por esto.
    }
  }

  @override
  Widget build(BuildContext context) {
    final reparto = ref.watch(repartoProvider);
    final notifier = ref.read(repartoProvider.notifier);

    // Dispara la carga de pedidos y rutas: es de donde sale `_paradaId`, y sin
    // el la entrega se cerraria sin tocar la parada de la ruta.
    ref.watch(entregasProvider);

    // Este pedido está en curso solo si es el que tiene la sesión activa: no
    // se puede repartir dos pedidos a la vez desde el mismo teléfono.
    final esteEnCurso =
        reparto.enServicio && reparto.pedidoId == widget.pedidoId;
    final otroEnCurso =
        reparto.enServicio && reparto.pedidoId != widget.pedidoId;

    return Scaffold(
      backgroundColor: MapStyle.superficieTenue,
      // El mapa es la pantalla: ocupa todo el alto y el resto flota encima.
      body: Stack(
        children: [
          Positioned.fill(
            child: MapaEntrega(
              ruta: _ruta,
              posicionRepartidor: esteEnCurso ? reparto.posicion : null,
              iconoRepartidor: Icons.navigation,
              etiquetaDestino: 'Pedido #${widget.pedidoId}',
              emitiendo: esteEnCurso && reparto.conectado,
              margenInferior: _altoHoja,
            ),
          ),

          Align(
            alignment: Alignment.topCenter,
            child: EncabezadoMapa(
              titulo: 'Recorrido',
              onVolver: () => Navigator.of(context).maybePop(),
              estado: _chipEstado(reparto, esteEnCurso, otroEnCurso),
              acciones: [
                if (esteEnCurso)
                  AccionMapa(
                    etiqueta: 'Detener reparto',
                    icono: Icons.stop_circle_outlined,
                    onTap: () => notifier.alternar(widget.pedidoId, false),
                  ),
              ],
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: MedidorAltura(
              onAltura: (alto) => setState(() => _altoHoja = alto),
              child: _HojaEntrega(
                pedidoId: widget.pedidoId,
                ruta: _ruta,
                reparto: reparto,
                esteEnCurso: esteEnCurso,
                subtitulo: _subtitulo(reparto, esteEnCurso, otroEnCurso),
                onAlternar: reparto.ocupado || otroEnCurso
                    ? null
                    : (activar) => notifier.alternar(widget.pedidoId, activar),
                onEntregado:
                    reparto.ocupado ? null : () => _marcarEntregado(notifier),
                onFallida:
                    reparto.ocupado ? null : () => _marcarFallida(notifier),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipEstado(RepartoState reparto, bool esteEnCurso, bool otroEnCurso) {
    if (otroEnCurso) {
      return const ChipEstado(texto: 'Otro reparto activo', color: MapStyle.aviso);
    }
    if (!esteEnCurso) {
      return const ChipEstado(texto: 'Detenido', color: MapStyle.neutro);
    }
    if (!reparto.conectado) {
      return const ChipEstado(texto: 'Reconectando', color: MapStyle.aviso);
    }
    return const ChipEstado(texto: 'En servicio', color: MapStyle.exito);
  }

  String _subtitulo(RepartoState reparto, bool esteEnCurso, bool otroEnCurso) {
    if (otroEnCurso) {
      return 'Ya hay un reparto en curso (pedido ${reparto.pedidoId}). '
          'Termínalo antes de empezar otro.';
    }
    if (!esteEnCurso) {
      return 'Actívalo para compartir tu ubicación con el cliente';
    }
    if (!reparto.conectado) return 'Reconectando… el GPS sigue registrando';
    return 'Compartiendo tu ubicación · ${reparto.puntosEnviados} puntos enviados';
  }

  int? get _paradaId {
    final dia = ref.read(entregasProvider).valueOrNull;
    if (dia == null) return null;
    for (final entrega in [
      if (dia.proxima != null) dia.proxima!,
      ...dia.pendientes,
      ...dia.completadas,
    ]) {
      if (entrega.pedido.id == widget.pedidoId) return entrega.paradaId;
    }
    return null;
  }

  String get _codigo => '#${widget.pedidoId}';

  Future<void> _marcarEntregado(RepartoNotifier notifier) async {
    final cierre = await confirmarEntrega(
      context,
      ref,
      pedidoId: widget.pedidoId,
      codigo: _codigo,
      paradaId: _paradaId,
    );
    if (!mounted || cierre == null) return;

    // El GPS se apaga solo si la entrega se registro de verdad.
    if (cierre.ok) await notifier.alTerminarEntrega();
    if (!mounted) return;
    mostrarResultadoCierre(context, cierre);
  }

  Future<void> _marcarFallida(RepartoNotifier notifier) async {
    final cierre = await registrarEntregaFallida(
      context,
      ref,
      pedidoId: widget.pedidoId,
      codigo: _codigo,
      paradaId: _paradaId,
    );
    if (!mounted || cierre == null) return;

    if (cierre.ok) await notifier.alTerminarEntrega();
    if (!mounted) return;
    mostrarResultadoCierre(context, cierre);
  }
}

class _HojaEntrega extends StatelessWidget {
  const _HojaEntrega({
    required this.pedidoId,
    required this.ruta,
    required this.reparto,
    required this.esteEnCurso,
    required this.subtitulo,
    required this.onAlternar,
    required this.onEntregado,
    required this.onFallida,
  });

  final int pedidoId;
  final RutaEntrega? ruta;
  final RepartoState reparto;
  final bool esteEnCurso;
  final String subtitulo;
  final ValueChanged<bool>? onAlternar;
  final VoidCallback? onEntregado;
  final VoidCallback? onFallida;

  @override
  Widget build(BuildContext context) {
    final entrega = ruta;
    final destino = entrega?.destino.etiqueta ?? '';
    final error = reparto.error;
    final velocidad = reparto.velocidadKmh;

    return HojaMapa(
      child: ConstrainedBox(
        // Tope de seguridad: con la letra del sistema al máximo la hoja podría
        // comerse el mapa entero, y entonces deja de ser un mapa.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.52,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const EtiquetaSeccion('Próxima entrega'),
              const SizedBox(height: MapStyle.esp2 - 2),
              Text('Pedido #$pedidoId', style: MapStyle.titulo),
              const SizedBox(height: MapStyle.esp1 + 1),
              Text(
                destino.isEmpty ? 'Destino de la entrega' : destino,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MapStyle.direccion,
              ),

              const SizedBox(height: MapStyle.esp4 - 2),
              if (entrega != null && entrega.tieneTrazado)
                Wrap(
                  spacing: MapStyle.esp2,
                  runSpacing: MapStyle.esp2,
                  children: [
                    PildoraMetrica(
                      icono: Icons.straighten,
                      texto: '${entrega.distanciaKm ?? '—'} km',
                    ),
                    PildoraMetrica(
                      icono: Icons.schedule,
                      texto: '${entrega.duracionMin ?? '—'} min',
                    ),
                    if (esteEnCurso && velocidad != null)
                      PildoraMetrica(
                        icono: Icons.speed,
                        texto: '${velocidad.toStringAsFixed(0)} km/h',
                      ),
                  ],
                )
              else
                Text(
                  entrega == null
                      ? 'Cargando el recorrido…'
                      : 'Trazado no disponible ahora mismo; se muestran origen '
                          'y destino.',
                  style: MapStyle.secundario,
                ),

              const Divider(height: MapStyle.esp6 + MapStyle.esp2),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'En servicio',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: MapStyle.textoFuerte,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitulo, style: MapStyle.secundario),
                      ],
                    ),
                  ),
                  const SizedBox(width: MapStyle.esp3),
                  Switch(
                    value: esteEnCurso,
                    onChanged: onAlternar,
                  ),
                ],
              ),

              if (esteEnCurso) ...[
                const SizedBox(height: MapStyle.esp2 + 2),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 15, color: MapStyle.neutro),
                    SizedBox(width: MapStyle.esp2 - 2),
                    Expanded(
                      child: Text(
                        'Puedes minimizar la app o cambiar de pestaña: el '
                        'reparto sigue activo mientras veas la notificación.',
                        style: MapStyle.secundario,
                      ),
                    ),
                  ],
                ),
              ],

              // Crece y encoge sin dar el salto seco que daba la Card.
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: MapStyle.esp4),
                        child: AvisoError(error),
                      ),
              ),

              const SizedBox(height: MapStyle.esp5),
              FilledButton.icon(
                onPressed: onEntregado,
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text(
                  'Marcar como entregado',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: MapStyle.exito,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MapStyle.radioControl),
                  ),
                ),
              ),
              const SizedBox(height: MapStyle.esp2),
              // Segunda salida de la visita. Va debajo y en secundario: es la
              // menos frecuente, pero sin ella la unica forma de cerrar una
              // parada era mentir y marcarla entregada.
              OutlinedButton.icon(
                onPressed: onFallida,
                icon: const Icon(Icons.error_outline, size: 19),
                label: const Text('No pude entregar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MapStyle.peligro,
                  minimumSize: const Size.fromHeight(MapStyle.tap),
                  side: BorderSide(color: MapStyle.peligro.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MapStyle.radioControl),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
