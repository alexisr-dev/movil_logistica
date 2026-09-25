import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rutas_repository.dart';

final rutasRepositoryProvider = Provider((ref) => RutasRepository());

final rutasProvider = FutureProvider<List<Ruta>>((ref) async {
  return ref.watch(rutasRepositoryProvider).listar();
});

final rutaActivaProvider = Provider<AsyncValue<Ruta?>>((ref) {
  return ref.watch(rutasProvider).whenData((rutas) {
    if (rutas.isEmpty) return null;
    for (final ruta in rutas) {
      if (ruta.estaEnCurso) return ruta;
    }
    for (final ruta in rutas) {
      if (!ruta.estaFinalizada && ruta.pendientes.isNotEmpty) return ruta;
    }
    return rutas.first;
  });
});
