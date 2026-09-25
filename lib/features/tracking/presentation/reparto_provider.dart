import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/ubicacion_service.dart';
import '../data/websocket_service.dart';

class RepartoState {
  const RepartoState({
    this.pedidoId,
    this.enServicio = false,
    this.conectado = false,
    this.ocupado = false,
    this.posicion,
    this.velocidadKmh,
    this.puntosEnviados = 0,
    this.error,
  });

  final int? pedidoId;
  final bool enServicio;
  final bool conectado;
  final bool ocupado;
  final LatLng? posicion;
  final double? velocidadKmh;
  final int puntosEnviados;
  final String? error;

  RepartoState copyWith({
    int? pedidoId,
    bool? enServicio,
    bool? conectado,
    bool? ocupado,
    LatLng? posicion,
    double? velocidadKmh,
    int? puntosEnviados,
    String? error,
    bool limpiarError = false,
  }) {
    return RepartoState(
      pedidoId: pedidoId ?? this.pedidoId,
      enServicio: enServicio ?? this.enServicio,
      conectado: conectado ?? this.conectado,
      ocupado: ocupado ?? this.ocupado,
      posicion: posicion ?? this.posicion,
      velocidadKmh: velocidadKmh ?? this.velocidadKmh,
      puntosEnviados: puntosEnviados ?? this.puntosEnviados,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

class RepartoNotifier extends StateNotifier<RepartoState> {
  RepartoNotifier() : super(const RepartoState());

  final _ubicacion = UbicacionService();
  final _ws = WebSocketService();
  final _espera = EsperaReintento();

  StreamSubscription<Position>? _suscripcionGps;
  StreamSubscription<PuntoTracking>? _suscripcionSocket;
  Timer? _temporizadorReintento;
  Position? _pendiente;

  bool get _activo => state.enServicio;

  // ---------------------------------------------------------------------------
  // Ciclo del servicio
  // ---------------------------------------------------------------------------

  Future<void> iniciar(int pedidoId) async {
    state = state.copyWith(pedidoId: pedidoId, ocupado: true, limpiarError: true);
    try {
      await _ubicacion.asegurarPermiso();

      state = state.copyWith(enServicio: true);
      await _conectarSocket();

      // Un primer punto inmediato: con `distanceFilter` el flujo continuo no
      // emite nada hasta que el repartidor recorre 10 metros, así que sin esto
      // el cliente se quedaba mirando un mapa vacío pese a estar "en servicio".
      await _enviarPosicionActual();

      _suscripcionGps ??= _ubicacion.flujo().listen(_alRecibirPosicion);
    } on UbicacionException catch (e) {
      state = state.copyWith(enServicio: false, error: e.mensaje);
    } catch (_) {
      state = state.copyWith(
        enServicio: false,
        error: 'No se pudo iniciar el reparto. Revisa tu conexión.',
      );
    } finally {
      if (mounted) state = state.copyWith(ocupado: false);
    }
  }

  Future<void> detener() async {
    _temporizadorReintento?.cancel();
    await _suscripcionGps?.cancel();
    await _suscripcionSocket?.cancel();
    _temporizadorReintento = null;
    _suscripcionGps = null;
    _suscripcionSocket = null;
    _pendiente = null;
    _ws.cerrar();
    _espera.reiniciar();
    if (mounted) state = const RepartoState();
  }

  Future<void> alternar(int pedidoId, bool activar) =>
      activar ? iniciar(pedidoId) : detener();

  // ---------------------------------------------------------------------------
  // Socket
  // ---------------------------------------------------------------------------

  Future<void> _conectarSocket() async {
    final pedidoId = state.pedidoId;
    if (pedidoId == null) return;

    try {
      final stream = await _ws.conectar(pedidoId);
      await _suscripcionSocket?.cancel();

      // Escuchar la retransmisión mantiene vivo el socket y permite detectar
      // tanto un rechazo del backend como una caída de red.
      _suscripcionSocket = stream.listen(
        (_) {},
        onError: _alCaerSocket,
        onDone: () => _alCaerSocket(null),
      );

      state = state.copyWith(conectado: true, limpiarError: true);
      _espera.reiniciar();

      final pendiente = _pendiente;
      if (pendiente != null) {
        _pendiente = null;
        _enviar(pendiente);
      }
    } catch (e) {
      _alCaerSocket(e);
    }
  }

  void _alCaerSocket(Object? error) {
    if (!mounted || !_activo) return;

    state = state.copyWith(conectado: false);

    // Un token caducado o un pedido ajeno no se arreglan reintentando.
    if (_ws.cierreEsDefinitivo) {
      final motivo = _ws.describirFallo(error);
      detener().then((_) {
        if (mounted) state = state.copyWith(error: motivo);
      });
      return;
    }

    state = state.copyWith(
      error: 'Sin conexión. Reintentando en ${_espera.actual.inSeconds} s…',
    );

    _temporizadorReintento?.cancel();
    _temporizadorReintento = Timer(_espera.actual, () {
      _espera.siguiente();
      if (mounted && _activo) _conectarSocket();
    });
  }

  // ---------------------------------------------------------------------------
  // GPS
  // ---------------------------------------------------------------------------

  Future<void> _enviarPosicionActual() async {
    try {
      _alRecibirPosicion(await _ubicacion.posicionActual());
    } catch (_) {
      // Si la lectura puntual falla, el flujo continuo acabará dando una.
    }
  }

  void _alRecibirPosicion(Position posicion) {
    if (!mounted) return;
    state = state.copyWith(
      posicion: LatLng(posicion.latitude, posicion.longitude),
      // `Position.speed` viene en m/s; la API la guarda en km/h.
      velocidadKmh: posicion.speed * 3.6,
    );
    _enviar(posicion);
  }

  void _enviar(Position posicion) {
    final enviado = _ws.enviarUbicacion(
      posicion.latitude,
      posicion.longitude,
      velocidad: posicion.speed * 3.6,
    );

    if (enviado) {
      state = state.copyWith(puntosEnviados: state.puntosEnviados + 1);
    } else {
      // Se guarda solo el último: al cliente le interesa dónde está ahora el
      // repartidor, no por dónde pasó mientras no había red.
      _pendiente = posicion;
    }
  }

  // ---------------------------------------------------------------------------
  // Entrega
  // ---------------------------------------------------------------------------

  Future<void> alTerminarEntrega() async {
    await detener();
  }

  @override
  void dispose() {
    _temporizadorReintento?.cancel();
    _suscripcionGps?.cancel();
    _suscripcionSocket?.cancel();
    _ws.cerrar();
    super.dispose();
  }
}

final repartoProvider =
    StateNotifierProvider<RepartoNotifier, RepartoState>((ref) {
  final notifier = RepartoNotifier();

  // Al cerrar sesión —a mano o porque caducó el token— se corta la emisión.
  // Si no, el GPS seguiría corriendo con su notificación contra un socket que
  // el backend ya rechaza.
  ref.listen(authProvider, (_, auth) {
    if (!auth.autenticado) notifier.detener();
  });

  return notifier;
});
