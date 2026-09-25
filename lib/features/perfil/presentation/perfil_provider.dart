import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/perfil_repository.dart';
import '../../../shared/models/usuario.dart';

final perfilRepositoryProvider = Provider((ref) => PerfilRepository());

final perfilProvider = FutureProvider<Usuario>((ref) async {
  ref.watch(authProvider.select((a) => a.autenticado));
  return ref.watch(perfilRepositoryProvider).yo();
});

class DisponibilidadNotifier extends StateNotifier<AsyncValue<bool>> {
  DisponibilidadNotifier(this._repo) : super(const AsyncValue.loading()) {
    cargar();
  }

  final PerfilRepository _repo;

  Future<void> cargar() async {
    state = const AsyncValue.loading();
    try {
      final perfil = await _repo.miPerfilRepartidor();
      if (mounted) state = AsyncValue.data(perfil.disponible);
    } catch (e, s) {
      if (mounted) state = AsyncValue.error(e, s);
    }
  }

  Future<String?> cambiar(bool disponible) async {
    final anterior = state.valueOrNull;
    // Optimista: el interruptor no debe quedarse a medias mientras va la
    // petición, que en la calle puede tardar.
    state = AsyncValue.data(disponible);
    try {
      final perfil = await _repo.cambiarDisponibilidad(disponible);
      if (mounted) state = AsyncValue.data(perfil.disponible);
      return null;
    } catch (_) {
      // Se revierte a lo último que confirmó el servidor: dejar el interruptor
      // en la posición nueva haría creer al repartidor que ya no le asignan
      // pedidos cuando en realidad el cambio no se guardó.
      if (mounted && anterior != null) state = AsyncValue.data(anterior);
      return 'No se pudo cambiar tu disponibilidad. Revisa tu conexión.';
    }
  }
}

final disponibilidadProvider =
    StateNotifierProvider<DisponibilidadNotifier, AsyncValue<bool>>((ref) {
  return DisponibilidadNotifier(ref.watch(perfilRepositoryProvider));
});
