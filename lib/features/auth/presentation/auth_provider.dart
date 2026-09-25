import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/errores_api.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

class AuthState {
  final bool cargando;
  final bool autenticado;
  final String? rol;
  final String? error;

  const AuthState({
    this.cargando = false,
    this.autenticado = false,
    this.rol,
    this.error,
  });

  bool get esRepartidor => rol == 'repartidor';

  AuthState copyWith({bool? cargando, bool? autenticado, String? rol, String? error}) =>
      AuthState(
        cargando: cargando ?? this.cargando,
        autenticado: autenticado ?? this.autenticado,
        rol: rol ?? this.rol,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState()) {
    // Si el refresh token caduca, el cliente HTTP avisa por aquí y la sesión
    // se cierra sola en vez de dejar la app dentro sin credenciales válidas.
    ApiClient.instance.onSesionExpirada = _cerrarPorExpiracion;
  }

  final AuthRepository _repo;

  Future<void> comprobarSesion() async {
    final ok = await _repo.estaAutenticado();
    final rol = await _repo.rolGuardado();
    state = state.copyWith(autenticado: ok, rol: rol);

    // Una sesión guardada antes de que existiera la clave `rol` dejaría a un
    // repartidor con la interfaz de cliente: sin pestañas y sin acceso a su
    // ruta. Se completa por detrás, sin bloquear el arranque.
    if (ok && rol == null) {
      unawaited(_recuperarRol());
    }
  }

  Future<void> _recuperarRol() async {
    try {
      await _repo.refrescarRol();
      if (mounted) state = state.copyWith(rol: await _repo.rolGuardado());
    } catch (_) {
      // Sin red se queda con el rol por defecto; se corregirá al reintentar.
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(cargando: true, error: null);
    try {
      await _repo.login(email, password);
      state = state.copyWith(
        cargando: false,
        autenticado: true,
        rol: await _repo.rolGuardado(),
      );
    } on DioException catch (e) {
      state = state.copyWith(cargando: false, error: _mensajeDeLogin(e));
    } catch (_) {
      state = state.copyWith(cargando: false, error: 'Error inesperado al iniciar sesión.');
    }
  }

  String _mensajeDeLogin(DioException e) {
    final codigo = e.response?.statusCode;
    if (e.type == DioExceptionType.badResponse && (codigo == 400 || codigo == 401)) {
      return 'Credenciales inválidas.';
    }
    return mensajeDeErrorDrf(e, respaldo: 'No se pudo iniciar sesión.');
  }

  Future<bool> registrar({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
    String? telefono,
  }) async {
    state = state.copyWith(cargando: true, error: null);
    try {
      final rol = await _repo.registrarCliente(
        email: email,
        password: password,
        nombre: nombre,
        apellido: apellido,
        telefono: telefono,
      );
      state = state.copyWith(cargando: false, autenticado: true, rol: rol);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        cargando: false,
        error: mensajeDeErrorDrf(e, respaldo: 'No se pudo crear la cuenta.'),
      );
      return false;
    } catch (_) {
      state = state.copyWith(cargando: false, error: 'Error inesperado al crear la cuenta.');
      return false;
    }
  }

  void _cerrarPorExpiracion() {
    if (!mounted || !state.autenticado) return;
    state = const AuthState(
      autenticado: false,
      error: 'Tu sesión caducó. Vuelve a iniciar sesión.',
    );
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(autenticado: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
