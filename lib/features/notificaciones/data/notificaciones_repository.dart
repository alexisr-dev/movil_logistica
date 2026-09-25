import '../../../core/network/api_client.dart';
import '../../../core/network/paginacion.dart';
import '../../../shared/models/notificacion.dart';

class NotificacionesRepository {
  final _dio = ApiClient.instance.dio;

  Future<List<Notificacion>> listar() async {
    final res = await _dio.get('/notificaciones/');
    return resultadosDe(res.data).map(Notificacion.fromJson).toList();
  }

  Future<int> contarNoLeidas() async {
    final res = await _dio.get('/notificaciones/no-leidas/');
    final datos = res.data;
    if (datos is Map && datos['count'] is int) return datos['count'] as int;
    return resultadosDe(datos is Map ? datos['resultados'] : datos).length;
  }

  Future<Notificacion> marcarLeida(int id) async {
    final res = await _dio.post('/notificaciones/$id/marcar-leida/');
    return Notificacion.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> marcarTodas(Iterable<int> ids) async {
    await Future.wait(
      ids.map((id) => marcarLeida(id).catchError((_) => _ignorada)),
    );
  }

  static final _ignorada = Notificacion(
    id: -1,
    leido: true,
    fechaCreacion: DateTime.fromMillisecondsSinceEpoch(0),
  );
}
