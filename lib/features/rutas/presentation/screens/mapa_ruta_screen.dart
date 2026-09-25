import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/errores_api.dart';
import '../../../../core/theme/estados.dart';
import '../../../../core/theme/map_style.dart';
import '../../../../shared/widgets/mapa/encabezado_mapa.dart';
import '../../../../shared/widgets/mapa/hoja_mapa.dart';
import '../../../../shared/widgets/mapa/piezas_mapa.dart';
import '../../../../shared/widgets/piezas_pedido.dart';
import '../../data/rutas_repository.dart';
import '../rutas_provider.dart';
import '../widgets/polyline_map_widget.dart';

class MapaRutaScreen extends ConsumerStatefulWidget {
  const MapaRutaScreen({super.key});

  @override
  ConsumerState<MapaRutaScreen> createState() => _MapaRutaScreenState();
}

class _MapaRutaScreenState extends ConsumerState<MapaRutaScreen> {
  static const _hojaMin = 0.30;
  static const _hojaMedia = 0.58;
  static const _hojaMax = 0.92;

  int _indice = 0;
  bool _cambiandoEstado = false;

  int? _seleccionada;

  void _recargar() {
    setState(() => _seleccionada = null);
    ref.invalidate(rutasProvider);
  }

  Parada? _porOrden(Ruta ruta, int? orden) {
    if (orden == null) return null;
    for (final parada in ruta.paradas) {
      if (parada.orden == orden) return parada;
    }
    return null;
  }

  Future<void> _cambiarEstadoRuta(Ruta ruta, {required bool iniciar}) async {
    if (!iniciar) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: const Text('¿Finalizar el recorrido?'),
          content: Text(
            ruta.pendientes.isEmpty
                ? 'Se cerrará la ruta del ${ruta.fecha}.'
                : 'Quedan ${ruta.pendientes.length} paradas sin resolver. '
                    'Se cerrará la ruta igualmente y quedarán como pendientes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogo).pop(true),
              child: const Text('Finalizar'),
            ),
          ],
        ),
      );
      if (confirmado != true || !mounted) return;
    }

    setState(() => _cambiandoEstado = true);
    try {
      final repo = ref.read(rutasRepositoryProvider);
      iniciar ? await repo.iniciar(ruta.id) : await repo.finalizar(ruta.id);
      ref.invalidate(rutasProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(iniciar ? 'Recorrido iniciado.' : 'Recorrido finalizado.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeDeError(e,
              respaldo: 'No se pudo cambiar el estado del recorrido.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _cambiandoEstado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rutas = ref.watch(rutasProvider);

    return Scaffold(
      backgroundColor: MapStyle.superficieTenue,
      body: rutas.when(
        loading: () => _marco(const Center(child: CircularProgressIndicator())),
        error: (e, _) => _marco(
          _Mensaje(
            icono: Icons.wifi_off,
            texto: 'No se pudieron cargar las rutas.\n\n'
                '${mensajeDeError(e, respaldo: "Revisa tu conexión.")}',
            accion: OutlinedButton.icon(
              onPressed: _recargar,
              icon: const Icon(Icons.refresh, size: 19),
              label: const Text('Reintentar'),
            ),
          ),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return _marco(
              const _Mensaje(
                icono: Icons.route_outlined,
                texto: 'No tienes rutas planificadas.\n\n'
                    'El administrador las crea desde el panel web, eligiendo '
                    'los pedidos y el orden de visita.',
              ),
            );
          }
          return _contenido(context, lista);
        },
      ),
    );
  }

  Widget _marco(Widget cuerpo) {
    return Stack(
      children: [
        Positioned.fill(child: cuerpo),
        Align(
          alignment: Alignment.topCenter,
          child: EncabezadoMapa(
            titulo: 'Recorrido',
            acciones: [
              AccionMapa(
                etiqueta: 'Actualizar',
                icono: Icons.refresh,
                onTap: _recargar,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contenido(BuildContext context, List<Ruta> rutas) {
    final ruta = rutas[_indice.clamp(0, rutas.length - 1)];
    final proxima = ruta.proxima;
    final destacada = _seleccionada ?? proxima?.orden;
    final aspecto = aspectoDeRuta(ruta.estado);

    final enMapa = ruta.paradas
        .where((p) => p.punto != null)
        .map((p) => ParadaMapa(
              punto: p.punto!,
              orden: p.orden,
              // Una parada fallida tampoco está pendiente: si solo contara
              // «entregado», el mapa la seguiría pintando como por visitar.
              entregada: p.resuelta,
              etiqueta: p.codigoSeguimiento,
            ))
        .toList();

    final sinGeometria = ruta.puntos.isEmpty && enMapa.isEmpty;
    final alto = MediaQuery.sizeOf(context).height;

    return Stack(
      children: [
        Positioned.fill(
          child: sinGeometria
              ? const _Mensaje(
                  icono: Icons.timeline,
                  texto: 'Esta ruta aún no tiene geometría calculada.',
                )
              : PolylineMapWidget(
                  puntos: ruta.puntos,
                  paradas: enMapa,
                  ordenDestacado: destacada,
                  onParadaTocada: (orden) =>
                      setState(() => _seleccionada = orden),
                  claveEncuadre: ruta.id,
                  margenInferior: alto * _hojaMin,
                ),
        ),

        Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EncabezadoMapa(
                titulo: 'Recorrido',
                estado: ChipEstado(
                  texto: aspecto.etiqueta,
                  color: aspecto.color,
                ),
                acciones: [
                  AccionMapa(
                    etiqueta: 'Actualizar',
                    icono: Icons.refresh,
                    onTap: _recargar,
                  ),
                ],
              ),
              if (rutas.length > 1) _selectorRutas(rutas),
            ],
          ),
        ),

        DraggableScrollableSheet(
          initialChildSize: _hojaMin,
          minChildSize: _hojaMin,
          maxChildSize: _hojaMax,
          snap: true,
          snapSizes: const [_hojaMin, _hojaMedia, _hojaMax],
          builder: (context, scroll) => DecoratedBox(
            decoration: decoracionHoja,
            child: _hoja(
              context,
              scroll: scroll,
              ruta: ruta,
              destacada: destacada,
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectorRutas(List<Ruta> rutas) {
    return SizedBox(
      // Alto escalado con la tipografía del sistema: fijo, con la letra al
      // máximo las píldoras se salían de su carril.
      height: MediaQuery.textScalerOf(context).scale(34) + MapStyle.esp3,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          MapStyle.esp3,
          MapStyle.esp3,
          MapStyle.esp3,
          0,
        ),
        itemCount: rutas.length,
        separatorBuilder: (_, __) => const SizedBox(width: MapStyle.esp2),
        itemBuilder: (_, i) {
          final activa = i == _indice;
          return TarjetaFlotante(
            radio: MapStyle.radioPildora,
            child: Material(
              color: activa ? MapStyle.primario : Colors.transparent,
              borderRadius: BorderRadius.circular(MapStyle.radioPildora),
              child: InkWell(
                borderRadius: BorderRadius.circular(MapStyle.radioPildora),
                onTap: () => setState(() {
                  _indice = i;
                  _seleccionada = null;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MapStyle.esp4,
                    vertical: MapStyle.esp2,
                  ),
                  child: Center(
                    child: Text(
                      'Ruta ${rutas[i].id} · ${rutas[i].fecha}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: activa ? Colors.white : MapStyle.textoFuerte,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hoja(
    BuildContext context, {
    required ScrollController scroll,
    required Ruta ruta,
    required int? destacada,
  }) {
    final parada = _porOrden(ruta, destacada);
    final pendientes = ruta.pendientes.length;

    return ListView(
      controller: scroll,
      padding: EdgeInsets.only(
        bottom: MapStyle.esp6 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        const Center(child: AsaHoja()),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            MapStyle.esp5,
            MapStyle.esp2,
            MapStyle.esp5,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EtiquetaSeccion(
                parada == null ? 'Ruta completada' : 'Próxima entrega',
              ),
              const SizedBox(height: MapStyle.esp2 - 2),
              Text(
                parada?.codigoSeguimiento.isNotEmpty == true
                    ? parada!.codigoSeguimiento
                    : (parada == null
                        ? 'Todas las paradas resueltas'
                        : 'Pedido #${parada.pedidoId}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MapStyle.titulo,
              ),
              if (parada != null) ...[
                const SizedBox(height: MapStyle.esp1 + 1),
                Text(
                  parada.etiquetaDireccion.isEmpty
                      ? 'Dirección no disponible'
                      : parada.etiquetaDireccion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MapStyle.direccion,
                ),
              ],

              const SizedBox(height: MapStyle.esp4 - 2),
              Wrap(
                spacing: MapStyle.esp2,
                runSpacing: MapStyle.esp2,
                children: [
                  PildoraMetrica(
                    icono: Icons.straighten,
                    texto: '${ruta.distanciaKm ?? '—'} km',
                  ),
                  PildoraMetrica(
                    icono: Icons.schedule,
                    texto: '${ruta.tiempoEstimadoMin ?? '—'} min',
                  ),
                  PildoraMetrica(
                    icono: Icons.flag_outlined,
                    texto: pendientes == 1
                        ? '1 parada pendiente'
                        : '$pendientes paradas pendientes',
                  ),
                  if (parada?.horaEstimada != null)
                    PildoraMetrica(
                      icono: Icons.access_time,
                      texto: 'Estimada ${soloHora(parada!.horaEstimada!)}',
                    ),
                ],
              ),

              const SizedBox(height: MapStyle.esp4),
              _AccionesRuta(
                ruta: ruta,
                ocupado: _cambiandoEstado,
                onIniciar: () => _cambiarEstadoRuta(ruta, iniciar: true),
                onFinalizar: () => _cambiarEstadoRuta(ruta, iniciar: false),
              ),

              if (parada != null) ...[
                const SizedBox(height: MapStyle.esp2),
                OutlinedButton.icon(
                  // Al detalle de **entrega**, que es donde el repartidor cierra
                  // la parada; el detalle de pedido es la pantalla del cliente.
                  onPressed: () => context.push('/entregas/${parada.pedidoId}'),
                  icon: const Icon(Icons.receipt_long_outlined, size: 19),
                  label: const Text('Ver detalles de la entrega'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(MapStyle.tap),
                    foregroundColor: MapStyle.primario,
                    side: const BorderSide(color: MapStyle.borde),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(MapStyle.radioControl),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const Divider(height: MapStyle.esp6 + MapStyle.esp3),

        // Lista de paradas en orden: el mapa dice dónde, esto dice qué.
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: MapStyle.esp5),
          child: EtiquetaSeccion('Paradas de la ruta'),
        ),
        const SizedBox(height: MapStyle.esp2),

        if (ruta.paradas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MapStyle.esp5,
              vertical: MapStyle.esp3,
            ),
            child: Text(
              'Esta ruta no tiene paradas asignadas.',
              style: MapStyle.secundario,
            ),
          )
        else
          for (var i = 0; i < ruta.paradas.length; i++)
            _FilaParada(
              parada: ruta.paradas[i],
              destacada: ruta.paradas[i].orden == destacada,
              ultima: i == ruta.paradas.length - 1,
              onTap: () =>
                  setState(() => _seleccionada = ruta.paradas[i].orden),
              onAbrir: () =>
                  context.push('/entregas/${ruta.paradas[i].pedidoId}'),
            ),
      ],
    );
  }
}

class _AccionesRuta extends StatelessWidget {
  const _AccionesRuta({
    required this.ruta,
    required this.ocupado,
    required this.onIniciar,
    required this.onFinalizar,
  });

  final Ruta ruta;
  final bool ocupado;
  final VoidCallback onIniciar;
  final VoidCallback onFinalizar;

  @override
  Widget build(BuildContext context) {
    if (ruta.estaFinalizada) {
      final aspecto = aspectoDeRuta(ruta.estado);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(MapStyle.esp3),
        decoration: BoxDecoration(
          color: aspecto.color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(MapStyle.radioControl),
        ),
        child: Row(
          children: [
            Icon(aspecto.icono, size: 18, color: aspecto.color),
            const SizedBox(width: MapStyle.esp2),
            Expanded(
              child: Text(
                'Recorrido ${aspecto.etiqueta.toLowerCase()}.',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: MapStyle.textoFuerte,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final iniciar = ruta.estaPlanificada;
    return FilledButton.icon(
      onPressed: ocupado ? null : (iniciar ? onIniciar : onFinalizar),
      icon: ocupado
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(iniciar ? Icons.play_arrow_rounded : Icons.flag, size: 21),
      label: Text(iniciar ? 'Iniciar recorrido' : 'Finalizar recorrido'),
      style: FilledButton.styleFrom(
        backgroundColor: iniciar ? MapStyle.primario : MapStyle.exito,
        minimumSize: const Size.fromHeight(MapStyle.tap),
      ),
    );
  }
}

class _FilaParada extends StatelessWidget {
  const _FilaParada({
    required this.parada,
    required this.destacada,
    required this.ultima,
    required this.onTap,
    required this.onAbrir,
  });

  final Parada parada;
  final bool destacada;
  final bool ultima;
  final VoidCallback onTap;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final aspecto = aspectoDeParada(parada.estado);
    // Una parada pendiente sin destacar se pinta neutra; la destacada, azul.
    final color = parada.resuelta
        ? aspecto.color
        : (destacada ? MapStyle.primario : MapStyle.neutro);

    return Material(
      color: destacada ? MapStyle.primario.withOpacity(0.06) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MapStyle.esp5,
            MapStyle.esp3 - 2,
            MapStyle.esp5,
            MapStyle.esp3 - 2,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 30,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      if (!ultima)
                        const Positioned(
                          top: 28,
                          bottom: -14,
                          child: SizedBox(
                            width: 2,
                            child: ColoredBox(color: MapStyle.borde),
                          ),
                        ),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: parada.resuelta
                            ? Icon(
                                parada.entregada ? Icons.check : Icons.close,
                                size: 15,
                                color: Colors.white,
                              )
                            : Text(
                                parada.orden.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MapStyle.esp3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        parada.codigoSeguimiento.isEmpty
                            ? 'Pedido #${parada.pedidoId}'
                            : parada.codigoSeguimiento,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: parada.resuelta
                              ? MapStyle.textoSuave
                              : MapStyle.textoFuerte,
                          // Solo se tacha lo entregado. Una parada fallida no
                          // está «hecha»: hay que volver a ella, y tacharla la
                          // haría desaparecer de la vista.
                          decoration: parada.entregada
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: MapStyle.textoSuave,
                        ),
                      ),
                      if (parada.etiquetaDireccion.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          parada.etiquetaDireccion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MapStyle.secundario,
                        ),
                      ],
                      if (parada.fallida) ...[
                        const SizedBox(height: 3),
                        ChipEstado(
                          texto: aspecto.etiqueta,
                          color: aspecto.color,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: MapStyle.esp2),
                BotonMapa(
                  icono: Icons.chevron_right,
                  tooltip: 'Abrir entrega',
                  onTap: onAbrir,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto, required this.icono, this.accion});

  final String texto;
  final IconData icono;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MapStyle.esp6 + MapStyle.esp3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: MapStyle.neutro),
            const SizedBox(height: MapStyle.esp4),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: MapStyle.direccion,
            ),
            if (accion != null) ...[
              const SizedBox(height: MapStyle.esp5),
              accion!,
            ],
          ],
        ),
      ),
    );
  }
}
