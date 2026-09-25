import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notificaciones_repository.dart';
import '../../../shared/models/notificacion.dart';

final notificacionesRepositoryProvider =
    Provider((ref) => NotificacionesRepository());

final notificacionesProvider = FutureProvider<List<Notificacion>>((ref) async {
  return ref.watch(notificacionesRepositoryProvider).listar();
});

final noLeidasProvider = FutureProvider<int>((ref) async {
  final cacheadas = ref.watch(notificacionesProvider).valueOrNull;
  if (cacheadas != null) {
    return cacheadas.where((n) => !n.leido).length;
  }
  return ref.watch(notificacionesRepositoryProvider).contarNoLeidas();
});
