import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/pedido.dart';
import '../../pedidos/presentation/pedidos_provider.dart';
import '../../rutas/data/rutas_repository.dart';
import '../../rutas/presentation/rutas_provider.dart';
import '../data/entregas_service.dart';

final entregasServiceProvider = Provider((ref) {
  return EntregasService(
    ref.watch(pedidosRepositoryProvider),
    ref.watch(rutasRepositoryProvider),
  );
});

class Entrega {
  const Entrega({required this.pedido, this.parada});

  final Pedido pedido;
  final Parada? parada;

  int? get paradaId => parada?.id;

  int? get orden => parada?.orden;
  DateTime? get horaEstimada => parada?.horaEstimada;

  bool get terminada => (parada?.resuelta ?? false) || pedido.estaTerminado;

  bool get enReparto => pedido.estaEnCamino;
}

class EntregasDelDia {
  const EntregasDelDia({
    required this.proxima,
    required this.pendientes,
    required this.completadas,
    this.ruta,
  });

  final Entrega? proxima;

  final List<Entrega> pendientes;
  final List<Entrega> completadas;

  final Ruta? ruta;

  bool get vacio =>
      proxima == null && pendientes.isEmpty && completadas.isEmpty;

  int get totalPendientes => pendientes.length + (proxima == null ? 0 : 1);
}

final entregasProvider = Provider<AsyncValue<EntregasDelDia>>((ref) {
  final pedidos = ref.watch(pedidosProvider);
  final rutas = ref.watch(rutasProvider);

  // Se espera a las dos: mostrar las entregas sin el orden de parada y volver a
  // reordenarlas medio segundo después es más confuso que esperar.
  if (pedidos.isLoading || rutas.isLoading) return const AsyncValue.loading();

  final error = pedidos.error ?? rutas.error;
  if (error != null) {
    return AsyncValue.error(
        error, pedidos.stackTrace ?? rutas.stackTrace ?? StackTrace.current);
  }

  final listaPedidos = pedidos.valueOrNull ?? const [];
  final listaRutas = rutas.valueOrNull ?? const [];
  final activa = ref.watch(rutaActivaProvider).valueOrNull;

  // Índice pedido -> parada, de todas las rutas: un pedido de una ruta que ya no
  // es la activa sigue necesitando su estado de parada para verse completado.
  final paradaDe = <int, Parada>{};
  for (final ruta in listaRutas) {
    for (final parada in ruta.paradas) {
      paradaDe.putIfAbsent(parada.pedidoId, () => parada);
    }
  }

  final entregas = listaPedidos
      .map((p) => Entrega(pedido: p, parada: paradaDe[p.id]))
      .toList();

  // Por orden de parada cuando lo hay; los sueltos, al final por antigüedad.
  entregas.sort((a, b) {
    final ordenA = a.orden;
    final ordenB = b.orden;
    if (ordenA != null && ordenB != null) return ordenA.compareTo(ordenB);
    if (ordenA != null) return -1;
    if (ordenB != null) return 1;
    return a.pedido.fechaCreacion.compareTo(b.pedido.fechaCreacion);
  });

  final pendientes = entregas.where((e) => !e.terminada).toList();
  final completadas = entregas.where((e) => e.terminada).toList();

  return AsyncValue.data(EntregasDelDia(
    proxima: pendientes.isEmpty ? null : pendientes.first,
    pendientes: pendientes.skip(1).toList(),
    completadas: completadas,
    ruta: activa,
  ));
});

void refrescarEntregas(WidgetRef ref) {
  ref.invalidate(pedidosProvider);
  ref.invalidate(rutasProvider);
}
