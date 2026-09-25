import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginacion.dart';
import '../../../core/utils/polyline.dart';

class Parada {
  final int id;
  final int pedidoId;
  final String codigoSeguimiento;
  final int orden;
  final String estado;
  final LatLng? punto;
  final String? direccion;
  final String? distrito;
  final DateTime? horaEstimada;
  final DateTime? horaReal;

  Parada({
    required this.id,
    required this.pedidoId,
    required this.codigoSeguimiento,
    required this.orden,
    required this.estado,
    this.punto,
    this.direccion,
    this.distrito,
    this.horaEstimada,
    this.horaReal,
  });

  bool get entregada => estado == 'entregado';
  bool get fallida => estado == 'fallido';

  bool get resuelta => entregada || fallida;

  String get etiquetaDireccion => [direccion, distrito]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' · ');

  factory Parada.fromJson(Map<String, dynamic> json) {
    final lat = json['latitud'] as num?;
    final lng = json['longitud'] as num?;
    DateTime? fecha(String clave) {
      final valor = json[clave];
      return valor is String ? DateTime.tryParse(valor) : null;
    }

    return Parada(
      id: json['id'] as int,
      pedidoId: json['pedido'] as int,
      codigoSeguimiento: json['codigo_seguimiento'] as String? ?? '',
      orden: json['orden_parada'] as int? ?? 0,
      estado: json['estado_parada'] as String? ?? 'pendiente',
      punto: lat == null || lng == null
          ? null
          : LatLng(lat.toDouble(), lng.toDouble()),
      direccion: json['direccion'] as String?,
      distrito: json['distrito'] as String?,
      horaEstimada: fecha('hora_estimada'),
      horaReal: fecha('hora_real'),
    );
  }
}

class Ruta {
  final int id;
  final String fecha;
  final String estado;
  final double? distanciaKm;
  final int? tiempoEstimadoMin;
  final List<LatLng> puntos;
  final List<Parada> paradas;

  Ruta({
    required this.id,
    required this.fecha,
    required this.estado,
    required this.puntos,
    required this.paradas,
    this.distanciaKm,
    this.tiempoEstimadoMin,
  });

  bool get estaPlanificada => estado == 'planificada';
  bool get estaEnCurso => estado == 'en_curso';
  bool get estaFinalizada => estado == 'finalizada' || estado == 'cancelada';

  Parada? get proxima {
    for (final parada in paradas) {
      if (!parada.resuelta) return parada;
    }
    return null;
  }

  List<Parada> get pendientes =>
      paradas.where((p) => !p.resuelta).toList(growable: false);

  List<Parada> get completadas =>
      paradas.where((p) => p.resuelta).toList(growable: false);

  bool get todasResueltas => paradas.isNotEmpty && pendientes.isEmpty;

  factory Ruta.fromJson(Map<String, dynamic> json) {
    final geometria = json['geometria_ruta'] as String?;
    final paradas = ((json['paradas'] as List?) ?? [])
        .map((e) => Parada.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));

    return Ruta(
      id: json['id'] as int,
      fecha: json['fecha'] as String,
      estado: json['estado'] as String? ?? '',
      distanciaKm: json['distancia_total_km'] == null
          ? null
          : double.tryParse(json['distancia_total_km'].toString()),
      tiempoEstimadoMin: json['tiempo_estimado_min'] as int?,
      // El backend ya pidió el recorrido a OSRM y lo guardó; aquí solo se
      // decodifica. Así el móvil no expone ninguna clave ni repite la llamada.
      puntos: geometria == null || geometria.isEmpty
          ? const []
          : decodificarPolyline(geometria),
      paradas: paradas,
    );
  }
}

class ResultadoParada {
  const ResultadoParada({
    required this.parada,
    required this.pedidoActualizado,
    required this.estadoPedido,
    this.motivo,
  });

  final Parada parada;
  final bool pedidoActualizado;
  final String estadoPedido;
  final String? motivo;

  factory ResultadoParada.fromJson(Map<String, dynamic> json) =>
      ResultadoParada(
        parada: Parada.fromJson(json['parada'] as Map<String, dynamic>),
        pedidoActualizado: json['pedido_actualizado'] as bool? ?? false,
        estadoPedido: json['estado_pedido'] as String? ?? '',
        motivo: json['motivo'] as String?,
      );
}

class RutasRepository {
  final _dio = ApiClient.instance.dio;

  Future<List<Ruta>> listar({int? pedidoId}) async {
    final res = await _dio.get(
      '/rutas/',
      queryParameters: pedidoId == null ? null : {'pedido': pedidoId},
    );
    return resultadosDe(res.data).map(Ruta.fromJson).toList();
  }

  Future<Ruta> iniciar(int rutaId) async {
    final res = await _dio.post('/rutas/$rutaId/iniciar/');
    return Ruta.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Ruta> finalizar(int rutaId) async {
    final res = await _dio.post('/rutas/$rutaId/finalizar/');
    return Ruta.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ResultadoParada> marcarParada(
    int paradaId, {
    required bool entregada,
    String comentario = '',
  }) async {
    final res = await _dio.post(
      '/rutas/paradas/$paradaId/marcar/',
      data: {
        'resultado': entregada ? 'entregado' : 'fallido',
        if (comentario.trim().isNotEmpty) 'comentario': comentario.trim(),
      },
    );
    return ResultadoParada.fromJson(res.data as Map<String, dynamic>);
  }
}
