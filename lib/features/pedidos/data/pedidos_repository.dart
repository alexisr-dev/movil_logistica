import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginacion.dart';
import '../../../core/utils/polyline.dart';
import '../../../shared/models/pedido.dart';

class ExtremoRuta {
  const ExtremoRuta({required this.punto, this.direccion, this.distrito});

  final LatLng punto;
  final String? direccion;
  final String? distrito;

  String get etiqueta =>
      [direccion, distrito].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  static ExtremoRuta fromJson(Map<String, dynamic> json) => ExtremoRuta(
        punto: LatLng(
          (json['latitud'] as num).toDouble(),
          (json['longitud'] as num).toDouble(),
        ),
        direccion: json['direccion'] as String?,
        distrito: json['distrito'] as String?,
      );
}

class RutaEntrega {
  const RutaEntrega({
    required this.origen,
    required this.destino,
    this.trazado = const [],
    this.distanciaKm,
    this.duracionMin,
  });

  final ExtremoRuta origen;
  final ExtremoRuta destino;
  final List<LatLng> trazado;
  final double? distanciaKm;
  final int? duracionMin;

  bool get tieneTrazado => trazado.isNotEmpty;

  factory RutaEntrega.fromJson(Map<String, dynamic> json) {
    final geometria = json['geometria'] as String?;
    return RutaEntrega(
      origen: ExtremoRuta.fromJson(json['origen'] as Map<String, dynamic>),
      destino: ExtremoRuta.fromJson(json['destino'] as Map<String, dynamic>),
      // El backend guarda la polilínea tal cual la devuelve OSRM; aquí solo se
      // decodifica, igual que hace la pantalla de rutas.
      trazado: geometria == null || geometria.isEmpty
          ? const []
          : decodificarPolyline(geometria),
      distanciaKm: json['distancia_km'] == null
          ? null
          : double.tryParse(json['distancia_km'].toString()),
      duracionMin: json['duracion_min'] as int?,
    );
  }
}

class PedidosRepository {
  final _dio = ApiClient.instance.dio;

  Future<List<Pedido>> listar() async {
    final res = await _dio.get('/pedidos/');
    return resultadosDe(res.data).map(Pedido.fromJson).toList();
  }

  Future<List<Pedido>> buscar(String codigo) async {
    final res = await _dio.get(
      '/pedidos/',
      queryParameters: {'search': codigo.trim()},
    );
    return resultadosDe(res.data).map(Pedido.fromJson).toList();
  }

  Future<Pedido> detalle(int id) async {
    final res = await _dio.get('/pedidos/$id/');
    return Pedido.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Pedido> crear({
    required int direccionOrigenId,
    required int direccionDestinoId,
    String? descripcion,
    double? pesoKg,
  }) async {
    final res = await _dio.post('/pedidos/', data: {
      'direccion_origen': direccionOrigenId,
      'direccion_destino': direccionDestinoId,
      if (descripcion != null && descripcion.trim().isNotEmpty)
        'descripcion': descripcion.trim(),
      if (pesoKg != null) 'peso_kg': pesoKg,
    });
    return Pedido.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> calificar(int id, int puntuacion, {String? comentario}) async {
    await _dio.post('/pedidos/$id/calificar/', data: {
      'puntuacion': puntuacion,
      if (comentario != null && comentario.trim().isNotEmpty)
        'comentario': comentario.trim(),
    });
  }

  Future<RutaEntrega> ruta(int id) async {
    final res = await _dio.get('/pedidos/$id/ruta/');
    return RutaEntrega.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> cambiarEstado(int id, String codigo, {String comentario = ''}) async {
    await _dio.post('/pedidos/$id/cambiar-estado/',
        data: {'codigo': codigo, 'comentario': comentario});
  }
}
