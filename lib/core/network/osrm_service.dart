import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../config/env.dart';

class OsrmService {
  final Dio _dio = Dio();

  Future<List<LatLng>> obtenerRuta(List<LatLng> puntos) async {
    final coords =
        puntos.map((p) => '${p.longitude},${p.latitude}').join(';');
    final url = '${Env.osrmUrl}/route/v1/driving/$coords';

    final res = await _dio.get(url, queryParameters: {
      'overview': 'full',
      'geometries': 'geojson',
    });

    final coordenadas = res.data['routes'][0]['geometry']['coordinates'] as List;
    return coordenadas
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }
}
