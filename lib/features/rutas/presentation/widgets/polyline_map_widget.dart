import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/map_style.dart';
import '../../../../shared/widgets/mapa/capas_base.dart';
import '../../../../shared/widgets/mapa/controles_mapa.dart';
import '../../../../shared/widgets/mapa/marcadores_mapa.dart';

class ParadaMapa {
  const ParadaMapa({
    required this.punto,
    required this.orden,
    this.entregada = false,
    this.etiqueta,
  });

  final LatLng punto;
  final int orden;
  final bool entregada;

  final String? etiqueta;
}

class PolylineMapWidget extends StatefulWidget {
  const PolylineMapWidget({
    super.key,
    required this.puntos,
    this.paradas = const [],
    this.ordenDestacado,
    this.onParadaTocada,
    this.claveEncuadre,
    this.margenInferior = MapStyle.esp4,
  });

  final List<LatLng> puntos;
  final List<ParadaMapa> paradas;

  final int? ordenDestacado;

  final ValueChanged<int>? onParadaTocada;

  final Object? claveEncuadre;

  final double margenInferior;

  @override
  State<PolylineMapWidget> createState() => _PolylineMapWidgetState();
}

class _PolylineMapWidgetState extends State<PolylineMapWidget> {
  final _mapController = MapController();
  bool _listo = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PolylineMapWidget anterior) {
    super.didUpdateWidget(anterior);

    if (widget.claveEncuadre != anterior.claveEncuadre) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _encuadrar());
      return;
    }

    // Elegir una parada en la lista la trae al centro del mapa: es la forma de
    // relacionar «la número 4» con un punto de la ciudad.
    final destacado = widget.ordenDestacado;
    if (destacado == null || destacado == anterior.ordenDestacado) return;

    final parada = widget.paradas.where((p) => p.orden == destacado);
    if (parada.isEmpty || !_listo) return;

    final camara = _mapController.camera;
    _mapController.move(parada.first.punto, camara.zoom < 14 ? 15 : camara.zoom);
  }

  List<LatLng> get _todosLosPuntos => [
        ...widget.puntos,
        ...widget.paradas.map((p) => p.punto),
      ];

  void _encuadrar() {
    final puntos = _todosLosPuntos;
    if (puntos.isEmpty || !mounted || !_listo) return;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(puntos),
        padding: EdgeInsets.fromLTRB(
          MapStyle.esp6 * 2,
          MapStyle.esp6 * 5,
          MapStyle.esp6 * 2,
          widget.margenInferior + MapStyle.esp6 * 2,
        ),
      ),
    );
  }

  void _zoom(double delta) {
    if (!_listo) return;
    final camara = _mapController.camera;
    _mapController.move(camara.center, (camara.zoom + delta).clamp(3.0, 19.0));
  }

  Color _colorParada(ParadaMapa parada, bool destacada) {
    if (parada.entregada) return MapStyle.exito;
    return destacada ? MapStyle.primario : MapStyle.neutro;
  }

  @override
  Widget build(BuildContext context) {
    final puntos = _todosLosPuntos;
    final centro = puntos.isEmpty
        ? const LatLng(-12.0464, -77.0428)
        : puntos[puntos.length ~/ 2];

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: centro,
            initialZoom: 13,
            backgroundColor: MapStyle.superficieTenue,
            interactionOptions: interaccionMapa,
            onMapReady: () {
              _listo = true;
              _encuadrar();
            },
          ),
          children: [
            capaTiles(context),
            if (widget.puntos.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.puntos,
                    strokeWidth: 5,
                    color: MapStyle.primario,
                    borderStrokeWidth: 3,
                    borderColor: Colors.white,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final parada in widget.paradas)
                  _marcador(
                    context,
                    parada,
                    parada.orden == widget.ordenDestacado,
                  ),
              ],
            ),
          ],
        ),

        Positioned(
          left: MapStyle.esp3,
          bottom: widget.margenInferior + MapStyle.esp2,
          child: const AtribucionMapa(),
        ),

        Positioned(
          right: MapStyle.esp3,
          bottom: widget.margenInferior + MapStyle.esp3,
          child: ControlesMapa(
            onAcercar: () => _zoom(1),
            onAlejar: () => _zoom(-1),
            onUbicacion: puntos.isEmpty ? null : _encuadrar,
            iconoUbicacion: Icons.zoom_out_map,
            tooltipUbicacion: 'Ver toda la ruta',
          ),
        ),
      ],
    );
  }

  Marker _marcador(BuildContext context, ParadaMapa parada, bool destacada) {
    final conEtiqueta =
        destacada && parada.etiqueta != null && parada.etiqueta!.isNotEmpty;
    final tamanoPin = MarcadorParada.tamanoPin(destacada);

    return Marker(
      point: parada.punto,
      width: conEtiqueta ? 190 : 44,
      height: altoMarcador(
        context,
        tamanoPin: tamanoPin,
        conEtiqueta: conEtiqueta,
      ),
      alignment: Alignment.topCenter,
      child: MarcadorParada(
        orden: parada.orden,
        color: _colorParada(parada, destacada),
        destacada: destacada,
        entregada: parada.entregada,
        etiqueta: conEtiqueta
            ? EtiquetaMarcador(
                titulo: 'Próxima',
                subtitulo: parada.etiqueta,
              )
            : null,
        onTap: widget.onParadaTocada == null
            ? null
            : () => widget.onParadaTocada!(parada.orden),
      ),
    );
  }
}
