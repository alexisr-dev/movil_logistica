import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/errores_api.dart';
import 'auth_provider.dart';

enum PasoRecuperacion { email, codigo, hecho }

class RecuperacionState {
  const RecuperacionState({
    this.paso = PasoRecuperacion.email,
    this.cargando = false,
    this.email = '',
    this.minutos = 15,
    this.error,
  });

  final PasoRecuperacion paso;
  final bool cargando;
  final String email;
  final int minutos;
  final String? error;

  RecuperacionState copyWith({
    PasoRecuperacion? paso,
    bool? cargando,
    String? email,
    int? minutos,
    String? error,
  }) =>
      RecuperacionState(
        paso: paso ?? this.paso,
        cargando: cargando ?? this.cargando,
        email: email ?? this.email,
        minutos: minutos ?? this.minutos,
        // Igual que en AuthState: el error no se arrastra, cada acción parte
        // de cero y lo vuelve a poner si vuelve a fallar.
        error: error,
      );
}

class RecuperacionNotifier extends StateNotifier<RecuperacionState> {
  RecuperacionNotifier(this._ref) : super(const RecuperacionState());

  final Ref _ref;

  Future<void> solicitarCodigo(String email) async {
    state = state.copyWith(cargando: true, error: null);
    try {
      final minutos = await _ref.read(authRepositoryProvider).solicitarCodigo(email);
      state = state.copyWith(
        cargando: false,
        paso: PasoRecuperacion.codigo,
        email: email.trim(),
        minutos: minutos,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        cargando: false,
        error: mensajeDeErrorDrf(e, respaldo: 'No se pudo enviar el código.'),
      );
    } catch (_) {
      state = state.copyWith(cargando: false, error: 'Error inesperado. Inténtalo de nuevo.');
    }
  }

  Future<bool> confirmar(String codigo, String passwordNueva) async {
    state = state.copyWith(cargando: true, error: null);
    try {
      await _ref.read(authRepositoryProvider).confirmarCodigo(
            email: state.email,
            codigo: codigo,
            passwordNueva: passwordNueva,
          );
      state = state.copyWith(cargando: false, paso: PasoRecuperacion.hecho);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        cargando: false,
        error: mensajeDeErrorDrf(e, respaldo: 'No se pudo cambiar la contraseña.'),
      );
      return false;
    } catch (_) {
      state = state.copyWith(cargando: false, error: 'Error inesperado. Inténtalo de nuevo.');
      return false;
    }
  }

  void volverAlEmail() => state = const RecuperacionState();
}

final recuperacionProvider =
    StateNotifierProvider.autoDispose<RecuperacionNotifier, RecuperacionState>(
  // autoDispose: al salir de la pantalla el formulario se olvida, para no
  // reaparecer a medio rellenar con un código que ya habrá caducado.
  RecuperacionNotifier.new,
);
