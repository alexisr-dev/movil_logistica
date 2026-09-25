import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/env.dart';

class PuntoTracking {
  final double lat;
  final double lng;
  final double? velocidad;

  PuntoTracking({required this.lat, required this.lng, this.velocidad});
}

const Map<int, String> motivosCierre = {
  4401: 'Tu sesión expiró. Vuelve a iniciar sesión.',
  4403: 'No tienes permiso para seguir este pedido.',
  4404: 'El pedido ya no existe.',
  4503: 'El servidor de tiempo real no está disponible.\n'
      'Falta levantar Redis, o usar la capa en memoria en desarrollo.',
};

const _cierresDefinitivos = {4401, 4403, 4404};

class WebSocketService {
  WebSocketChannel? _channel;
  final _storage = const FlutterSecureStorage();

  Future<Stream<PuntoTracking>> conectar(int pedidoId) async {
    final token = await _storage.read(key: 'access_token');
    final uri = Uri.parse(
      '${Env.wsUrl}/ws/tracking/$pedidoId/?token=${Uri.encodeComponent(token ?? '')}',
    );
    _channel = WebSocketChannel.connect(uri);

    return _channel!.stream.map((mensaje) {
      final data = jsonDecode(mensaje as String) as Map<String, dynamic>;
      return PuntoTracking(
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
        velocidad: data['velocidad'] == null
            ? null
            : (data['velocidad'] as num).toDouble(),
      );
    });
  }

  String? get motivoDeCierre {
    final codigo = _channel?.closeCode;
    return codigo == null ? null : motivosCierre[codigo];
  }

  bool get cierreEsDefinitivo {
    final codigo = _channel?.closeCode;
    return codigo != null && _cierresDefinitivos.contains(codigo);
  }

  String describirFallo(Object? error) {
    final porCodigo = motivoDeCierre;
    if (porCodigo != null) return porCodigo;

    final codigo = _channel?.closeCode;
    if (codigo != null) {
      return 'El servidor cerró la conexión (código $codigo).\n'
          '${_channel?.closeReason ?? ''}'.trim();
    }

    if (error is WebSocketChannelException) {
      return 'No se pudo abrir el canal de tiempo real en ${Env.wsUrl}.\n'
          'Comprueba que el backend corre con daphne (ASGI) y que estás en la '
          'misma red Wi-Fi.';
    }

    return 'Se perdió la conexión con ${Env.wsUrl}.'
        '${error == null ? '' : '\n$error'}';
  }

  bool enviarUbicacion(double lat, double lng, {double? velocidad}) {
    final canal = _channel;
    if (canal == null || canal.closeCode != null) return false;

    canal.sink.add(jsonEncode({
      'lat': lat,
      'lng': lng,
      'velocidad': velocidad,
    }));
    return true;
  }

  void cerrar() {
    _channel?.sink.close();
    _channel = null;
  }
}

class EsperaReintento {
  static const _inicial = Duration(seconds: 2);
  static const _maxima = Duration(seconds: 30);

  Duration _actual = _inicial;

  Duration get actual => _actual;

  void siguiente() {
    final doble = _actual * 2;
    _actual = doble > _maxima ? _maxima : doble;
  }

  void reiniciar() => _actual = _inicial;
}
