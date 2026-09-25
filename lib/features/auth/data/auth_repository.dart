import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';

class AuthRepository {
  final _dio = ApiClient.instance.dio;
  final _storage = const FlutterSecureStorage();

  Future<bool> login(String email, String password) async {
    final res = await _dio.post('/auth/login/', data: {
      'email': email,
      'password': password,
    });
    await _guardarSesion(res.data['access'], res.data['refresh']);

    // El rol decide qué ve cada quien: el repartidor sale a repartir, el
    // cliente sigue su pedido. Se cachea para no pedirlo en cada pantalla.
    await refrescarRol();
    return true;
  }

  Future<String?> registrarCliente({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
    String? telefono,
  }) async {
    final res = await _dio.post('/usuarios/registro/', data: {
      'email': email,
      'password': password,
      'nombre': nombre,
      'apellido': apellido,
      if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
    });

    await _guardarSesion(res.data['access'], res.data['refresh']);
    final rol = res.data['usuario']?['rol'] as String?;
    await _storage.write(key: 'rol', value: rol);
    return rol;
  }

  Future<int> solicitarCodigo(String email) async {
    final res = await _dio.post('/auth/password-reset/', data: {'email': email});
    return (res.data['expira_en_minutos'] as int?) ?? 15;
  }

  Future<void> confirmarCodigo({
    required String email,
    required String codigo,
    required String passwordNueva,
  }) async {
    await _dio.post('/auth/password-reset/confirmar/', data: {
      'email': email,
      'codigo': codigo,
      'password_nueva': passwordNueva,
    });
  }

  Future<void> _guardarSesion(String? access, String? refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<String?> refrescarRol() async {
    final perfil = await yo();
    final rol = perfil['rol'] as String?;
    await _storage.write(key: 'rol', value: rol);
    return rol;
  }

  Future<Map<String, dynamic>> yo() async {
    final res = await _dio.get('/usuarios/yo/');
    return res.data as Map<String, dynamic>;
  }

  Future<String?> rolGuardado() => _storage.read(key: 'rol');

  Future<void> logout() async => _storage.deleteAll();

  Future<bool> estaAutenticado() async =>
      await _storage.read(key: 'access_token') != null;
}
