import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/map_style.dart';
import '../../../../shared/widgets/mapa/capas_base.dart';
import '../../../../shared/widgets/mapa/controles_mapa.dart';
import '../../../../shared/widgets/mapa/marcadores_mapa.dart';
import '../../../pedidos/data/pedidos_repository.dart';

class MapaEntrega extends StatefulWidget {
  const MapaEntrega({
    super.key,
    required this.ruta,
    this.posicionRepartidor,
    this.iconoRepartidor = Icons.local_shipping,
    this.etiquetaDestino,
    this.emitiendo = false,
    this.mostrarControles = true,
    this.margenInferior = MapStyle.esp4,
  });

  final RutaEntrega? ruta;
  final LatLng? posicionRepartidor;
  final IconData iconoRepartidor;

  final String? etiquetaDestino;

  final bool emitiendo;

  final bool mostrarControles;

  final double margenInferior;

  @override
  State<MapaEntrega> createState() => _MapaEntregaState();
}

class _MapaEntregaState extends State<MapaEntrega>
    with SingleTickerProviderStateMixin {
  static const _distancia = Distance();

  final _mapController = MapController();

  late final AnimationController _anim;
  StreamSubscription<MapEvent>? _eventos;

  bool _encuadrado = false;
  bool _listo = false;

  bool _siguiendo = true;

  LatLng? _mostrada;
  LatLng? _desde;
  LatLng? _hasta;
  double? _rumbo;

  @override
  void initState() {
    super.initState();
    _mostrada = widget.posicionRepartidor;
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(_alAnimar);

    // Si el repartidor arrastra el mapa deja de seguirle: antes la cámara
    // volvía a saltar sobre él un segundo después de mirar a otra parte.
    _eventos = _mapController.mapEventStream.listen((evento) {
      if (!_siguiendo || !gestosDelUsuario.contains(evento.source)) return;
      setState(() => _siguiendo = false);
    });
  }

  @override
  void dispose() {
    _eventos?.cancel();
    _anim.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MapaEntrega anterior) {
    super.didUpdateWidget(anterior);

    // Primer encuadre en cuanto se conoce el recorrido: con un zoom fijo, si
    // origen y destino están separados uno de los dos queda fuera de pantalla.
    if (!_encuadrado && widget.ruta != null) {
      _encuadrado = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _encuadrar());
      return;
    }

    final nueva = widget.posicionRepartidor;
    if (nueva == null || nueva == anterior.posicionRepartidor) return;

    final previa = _mostrada ?? anterior.posicionRepartidor;
    if (previa == null) {
      setState(() => _mostrada = nueva);
      if (_siguiendo) _seguir(nueva);
      return;
    }

    // Por debajo de 3 m lo que se mueve es el ruido del GPS, no el repartidor:
    // orientar la flecha con eso la haría girar sola en cada semáforo.
    if (_distancia.distance(previa, nueva) >= 3) {
      _rumbo = _distancia.bearing(previa, nueva);
    }

    _desde = previa;
    _hasta = nueva;
    _anim.forward(from: 0);
  }

  // ---------------------------------------------------------------------------
  // Cámara
  // ---------------------------------------------------------------------------

  void _alAnimar() {
    final desde = _desde;
    final hasta = _hasta;
    if (desde == null || hasta == null) return;

    final t = Curves.easeOutCubic.transform(_anim.value);
    final punto = LatLng(
      desde.latitude + (hasta.latitude - desde.latitude) * t,
      desde.longitude + (hasta.longitude - desde.longitude) * t,
    );

    setState(() => _mostrada = punto);
    if (_siguiendo) _seguir(punto);
  }

  void _seguir(LatLng punto) {
    if (!_listo) return;
    final zoom = _mapController.camera.zoom;
    _mapController.move(punto, zoom < 14 ? 16 : zoom);
  }

  void _encuadrar() {
    final ruta = widget.ruta;
    if (ruta == null || !mounted || !_listo) return;

    final puntos = <LatLng>[
      ruta.origen.punto,
      ruta.destino.punto,
      ...ruta.trazado,
      if (_mostrada != null) _mostrada!,
    ];

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(puntos),
        padding: EdgeInsets.fromLTRB(
          MapStyle.esp6 * 2,
          MapStyle.esp6 * 4,
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

  void _alternarEncuadre() {
    final posicion = _mostrada;

    if (posicion == null || _siguiendo) {
      setState(() => _siguiendo = false);
      _encuadrar();
      return;
    }

    setState(() => _siguiendo = true);
    _seguir(posicion);
  }

  // ---------------------------------------------------------------------------
  // Pintura
  // ---------------------------------------------------------------------------

  List<Polyline> _trazados(RutaEntrega ruta) {
    if (ruta.tieneTrazado) {
      return [
        Polyline(
          points: ruta.trazado,
          strokeWidth: 6,
          color: MapStyle.primario,
          // El borde blanco despega la ruta del fondo: sin él, sobre una
          // avenida gris el trazo se confundía con la propia calle.
          borderStrokeWidth: 3,
          borderColor: Colors.white,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      ];
    }

    // Sin geometría de OSRM se dibuja la recta punteada entre extremos, que es
    // justo lo que la pantalla ya prometía por escrito.
    return [
      Polyline(
        points: [ruta.origen.punto, ruta.destino.punto],
        strokeWidth: 3,
        color: MapStyle.neutro,
        isDotted: true,
      ),
    ];
  }

  List<Marker> _marcadores(
    BuildContext context,
    RutaEntrega? ruta,
    LatLng? posicion,
  ) {
    final conEtiqueta =
        widget.etiquetaDestino != null && widget.etiquetaDestino!.isNotEmpty;

    return [
      if (ruta != null) ...[
        // El origen queda en gris y más pequeño: al repartidor le importa a
        // dónde va, no de dónde salió.
        Marker(
          point: ruta.origen.punto,
          width: 34,
          height: altoMarcador(context, tamanoPin: 26),
          alignment: Alignment.topCenter,
          child: const MarcadorExtremo(
            icono: Icons.storefront,
            color: MapStyle.textoSuave,
            tamano: 26,
          ),
        ),
        Marker(
          point: ruta.destino.punto,
          width: conEtiqueta ? 190 : 40,
          height: altoMarcador(
            context,
            tamanoPin: 34,
            conEtiqueta: conEtiqueta,
          ),
          alignment: Alignment.topCenter,
          child: MarcadorExtremo(
            icono: Icons.flag,
            color: MapStyle.peligro,
            etiqueta: conEtiqueta
                ? EtiquetaMarcador(
                    titulo: 'Entrega',
                    subtitulo: widget.etiquetaDestino,
                  )
                : null,
          ),
        ),
      ],
      // El repartidor va encima de los extremos.
      if (posicion != null)
        Marker(
          point: posicion,
          width: 64,
          height: 64,
          child: MarcadorRepartidor(
            icono: widget.iconoRepartidor,
            rumboGrados: _rumbo,
            emitiendo: widget.emitiendo,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ruta = widget.ruta;
    final posicion = _mostrada;

    // Lima por defecto mientras no se sepa nada del pedido.
    final centro =
        ruta?.origen.punto ?? posicion ?? const LatLng(-12.0464, -77.0428);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: centro,
            initialZoom: 14,
            backgroundColor: MapStyle.superficieTenue,
            interactionOptions: interaccionMapa,
            onMapReady: () {
              _listo = true;
              // Sin el `!_encuadrado`: si la ruta llegó antes de que el mapa
              // estuviera montado, aquel intento se descartó y este es el
              // único que puede encuadrarla.
              if (widget.ruta != null) {
                _encuadrado = true;
                _encuadrar();
              }
            },
          ),
          children: [
            capaTiles(context),
            if (ruta != null) PolylineLayer(polylines: _trazados(ruta)),
            MarkerLayer(markers: _marcadores(context, ruta, posicion)),
          ],
        ),

        Positioned(
          left: MapStyle.esp3,
          bottom: widget.margenInferior + MapStyle.esp2,
          child: const AtribucionMapa(),
        ),

        if (widget.mostrarControles)
          Positioned(
            right: MapStyle.esp3,
            bottom: widget.margenInferior + MapStyle.esp3,
            child: ControlesMapa(
              onAcercar: () => _zoom(1),
              onAlejar: () => _zoom(-1),
              onUbicacion: ruta == null && posicion == null
                  ? null
                  : _alternarEncuadre,
              ubicacionActiva: _siguiendo && posicion != null,
              iconoUbicacion: _siguiendo && posicion != null
                  ? Icons.my_location
                  : (posicion == null
                      ? Icons.zoom_out_map
                      : Icons.location_searching),
              tooltipUbicacion: _siguiendo && posicion != null
                  ? 'Ver todo el recorrido'
                  : (posicion == null
                      ? 'Ver todo el recorrido'
                      : 'Centrar en mi posición'),
            ),
          ),
      ],
    );
  }
}
