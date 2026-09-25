import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/map_style.dart';
import '../../../../shared/widgets/mapa/encabezado_mapa.dart';
import '../../../../shared/widgets/mapa/hoja_mapa.dart';
import '../../../../shared/widgets/mapa/piezas_mapa.dart';
import '../../../pedidos/data/pedidos_repository.dart';
import '../../data/tracking_repository.dart';
import '../../data/websocket_service.dart';
import '../widgets/mapa_entrega.dart';

class TrackingTiempoRealScreen extends StatefulWidget {
  const TrackingTiempoRealScreen({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  State<TrackingTiempoRealScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingTiempoRealScreen> {
  final _ws = WebSocketService();
  final _tracking = TrackingRepository();
  final _pedidos = PedidosRepository();

  RutaEntrega? _ruta;
  LatLng? _posicion;
  double? _velocidad;
  DateTime? _momento;
  String? _error;

  double _altoHoja = 150;

  @override
  void initState() {
    super.initState();
    _cargarRuta();
    _sembrarUltimaPosicion();
    _conectar();
  }

  Future<void> _cargarRuta() async {
    try {
      final ruta = await _pedidos.ruta(widget.pedidoId);
      if (mounted) setState(() => _ruta = ruta);
    } catch (_) {
      // El seguimiento en vivo sigue funcionando aunque falle el trazado.
    }
  }

  Future<void> _sembrarUltimaPosicion() async {
    try {
      final ultima = await _tracking.ultima(widget.pedidoId);
      if (!mounted || ultima == null || _posicion != null) return;
      setState(() {
        _posicion = ultima.punto;
        _velocidad = ultima.velocidad;
        _momento = ultima.momento;
      });
    } catch (_) {
      // El histórico es un extra: su fallo no debe romper la pantalla.
    }
  }

  Future<void> _conectar() async {
    // `conectar` es asíncrono porque antes lee el JWT del almacenamiento seguro.
    final stream = await _ws.conectar(widget.pedidoId);
    if (!mounted) return;

    stream.listen(
      (punto) {
        if (!mounted) return;
        setState(() {
          _posicion = LatLng(punto.lat, punto.lng);
          _velocidad = punto.velocidad;
          _momento = DateTime.now();
          _error = null;
        });
      },
      onError: (e) {
        if (mounted) setState(() => _error = _ws.describirFallo(e));
      },
      onDone: _mostrarCierre,
    );
  }

  void _mostrarCierre() {
    final motivo = _ws.motivoDeCierre;
    if (motivo != null && mounted) setState(() => _error = motivo);
  }

  @override
  void dispose() {
    _ws.cerrar();
    super.dispose();
  }

  String get _mensaje {
    if (_error != null) return _error!;
    if (_posicion == null) {
      return 'Esperando a que el repartidor active «En servicio».';
    }
    final partes = <String>['En camino'];
    if (_velocidad != null) {
      partes.add('${_velocidad!.toStringAsFixed(0)} km/h');
    }
    if (_momento != null) {
      final hace = DateTime.now().difference(_momento!);
      if (hace.inMinutes >= 1) partes.add('visto hace ${hace.inMinutes} min');
    }
    return partes.join(' · ');
  }

  Widget get _chip {
    if (_error != null) {
      return const ChipEstado(texto: 'Sin conexión', color: MapStyle.aviso);
    }
    if (_posicion == null) {
      return const ChipEstado(texto: 'Esperando', color: MapStyle.neutro);
    }
    return const ChipEstado(texto: 'En camino', color: MapStyle.exito);
  }

  @override
  Widget build(BuildContext context) {
    final ruta = _ruta;
    final destino = ruta?.destino.etiqueta ?? '';

    return Scaffold(
      backgroundColor: MapStyle.superficieTenue,
      body: Stack(
        children: [
          Positioned.fill(
            child: MapaEntrega(
              ruta: ruta,
              posicionRepartidor: _posicion,
              etiquetaDestino: 'Pedido #${widget.pedidoId}',
              emitiendo: _posicion != null && _error == null,
              margenInferior: _altoHoja,
            ),
          ),

          Align(
            alignment: Alignment.topCenter,
            child: EncabezadoMapa(
              titulo: 'Seguimiento',
              onVolver: () => Navigator.of(context).maybePop(),
              estado: _chip,
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: MedidorAltura(
              onAltura: (alto) => setState(() => _altoHoja = alto),
              child: HojaMapa(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EtiquetaSeccion('Tu pedido'),
                    const SizedBox(height: MapStyle.esp2 - 2),
                    Text('Pedido #${widget.pedidoId}', style: MapStyle.titulo),
                    if (destino.isNotEmpty) ...[
                      const SizedBox(height: MapStyle.esp1 + 1),
                      Text(
                        destino,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MapStyle.direccion,
                      ),
                    ],

                    if (ruta != null && ruta.tieneTrazado) ...[
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
                            texto: '${ruta.duracionMin ?? '—'} min',
                          ),
                        ],
                      ),
                    ] else if (ruta != null) ...[
                      const SizedBox(height: MapStyle.esp3),
                      const Text(
                        'Trazado no disponible; se muestran origen y destino.',
                        style: MapStyle.secundario,
                      ),
                    ],

                    const SizedBox(height: MapStyle.esp4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _error != null
                              ? Icons.error_outline
                              : (_posicion == null
                                  ? Icons.hourglass_empty
                                  : Icons.two_wheeler),
                          size: 17,
                          color: _error != null
                              ? MapStyle.peligro
                              : MapStyle.textoSuave,
                        ),
                        const SizedBox(width: MapStyle.esp2),
                        Expanded(
                          child: Text(
                            _mensaje,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: _error != null
                                  ? MapStyle.peligro
                                  : MapStyle.textoSuave,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
