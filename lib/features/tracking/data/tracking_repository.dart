import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';

class UltimaUbicacion {
  final LatLng punto;
  final double? velocidad;
  final DateTime? momento;

  UltimaUbicacion({required this.punto, this.velocidad, this.momento});
}

class TrackingRepository {
  final _dio = ApiClient.instance.dio;

  Future<UltimaUbicacion?> ultima(int pedidoId) async {
    try {
      final res = await _dio.get('/tracking/ubicaciones/ultimo/$pedidoId/');
      final data = res.data as Map<String, dynamic>;
      return UltimaUbicacion(
        punto: LatLng(
          (data['latitud'] as num).toDouble(),
          (data['longitud'] as num).toDouble(),
        ),
        velocidad: data['velocidad_kmh'] == null
            ? null
            : double.tryParse(data['velocidad_kmh'].toString()),
        momento: DateTime.tryParse(data['timestamp'] as String? ?? ''),
      );
    } on DioException catch (e) {
      // 404 = el repartidor todavía no ha salido. No es un error que mostrar.
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
