import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/paginacion.dart';
import '../../../shared/models/direccion.dart';

class DireccionEnUso implements Exception {
  const DireccionEnUso(this.mensaje, this.pedidos);

  final String mensaje;
  final int pedidos;

  @override
  String toString() => mensaje;
}

class DireccionesRepository {
  final _dio = ApiClient.instance.dio;

  Future<List<Direccion>> listar() async {
    final res = await _dio.get('/usuarios/direcciones/');
    final direcciones =
        resultadosDe(res.data).map(Direccion.fromJson).toList();
    // La predeterminada primero: es la que la mayoría va a elegir.
    direcciones.sort((a, b) {
      if (a.esDefault != b.esDefault) return a.esDefault ? -1 : 1;
      return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
    });
    return direcciones;
  }

  Future<Direccion> crear(Direccion direccion) async {
    final res = await _dio.post('/usuarios/direcciones/', data: direccion.toJson());
    return Direccion.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Direccion> actualizar(int id, Direccion direccion) async {
    final res =
        await _dio.put('/usuarios/direcciones/$id/', data: direccion.toJson());
    return Direccion.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> eliminar(int id) async {
    try {
      await _dio.delete('/usuarios/direcciones/$id/');
    } on DioException catch (e) {
      final datos = e.response?.data;
      if (e.response?.statusCode == 409 && datos is Map) {
        throw DireccionEnUso(
          datos['detail'] as String? ??
              'Esta dirección se usa en un pedido y no puede eliminarse.',
          datos['pedidos'] as int? ?? 0,
        );
      }
      rethrow;
    }
  }

  Future<void> marcarPredeterminada(int id, List<Direccion> actuales) async {
    for (final otra in actuales) {
      if (otra.esDefault && otra.id != id) {
        await _dio.patch(
          '/usuarios/direcciones/${otra.id}/',
          data: {'es_default': false},
        );
      }
    }
    await _dio.patch('/usuarios/direcciones/$id/', data: {'es_default': true});
  }
}
