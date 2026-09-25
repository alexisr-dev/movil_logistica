import '../../../core/network/api_client.dart';
import '../../../shared/models/usuario.dart';

class PerfilRepository {
  final _dio = ApiClient.instance.dio;

  Future<Usuario> yo() async {
    final res = await _dio.get('/usuarios/yo/');
    return Usuario.fromJson(res.data as Map<String, dynamic>);
  }

  Future<PerfilRepartidor> miPerfilRepartidor() async {
    final res = await _dio.get('/usuarios/mi-perfil-repartidor/');
    return PerfilRepartidor.fromJson(res.data as Map<String, dynamic>);
  }

  Future<PerfilRepartidor> cambiarDisponibilidad(bool disponible) async {
    final res = await _dio.patch(
      '/usuarios/mi-perfil-repartidor/',
      data: {'disponible': disponible},
    );
    return PerfilRepartidor.fromJson(res.data as Map<String, dynamic>);
  }
}
