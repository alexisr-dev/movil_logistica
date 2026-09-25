import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reportes_repository.dart';
import '../../../shared/models/rendimiento.dart';

final reportesRepositoryProvider = Provider((ref) => ReportesRepository());

final rendimientoProvider = FutureProvider<Rendimiento>((ref) async {
  return ref.watch(reportesRepositoryProvider).miRendimiento();
});
