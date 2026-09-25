import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/direcciones_repository.dart';
import '../../../shared/models/direccion.dart';

final direccionesRepositoryProvider = Provider((ref) => DireccionesRepository());

final direccionesProvider = FutureProvider<List<Direccion>>((ref) async {
  return ref.watch(direccionesRepositoryProvider).listar();
});
