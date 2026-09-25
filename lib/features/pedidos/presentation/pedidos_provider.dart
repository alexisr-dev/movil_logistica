import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pedidos_repository.dart';
import '../../../shared/models/pedido.dart';

final pedidosRepositoryProvider = Provider((ref) => PedidosRepository());

final pedidosProvider = FutureProvider<List<Pedido>>((ref) async {
  return ref.watch(pedidosRepositoryProvider).listar();
});

class PedidosClasificados {
  const PedidosClasificados({
    required this.enCurso,
    required this.completados,
    required this.cancelados,
  });

  final List<Pedido> enCurso;
  final List<Pedido> completados;
  final List<Pedido> cancelados;

  bool get vacio => enCurso.isEmpty && completados.isEmpty && cancelados.isEmpty;

  Pedido? get activo {
    if (enCurso.isEmpty) return null;
    final ordenados = [...enCurso]
      ..sort((a, b) => b.estado.orden.compareTo(a.estado.orden));
    return ordenados.first;
  }
}

final pedidosClasificadosProvider = Provider<AsyncValue<PedidosClasificados>>((ref) {
  return ref.watch(pedidosProvider).whenData((pedidos) {
    return PedidosClasificados(
      enCurso: pedidos.where((p) => p.estaEnCurso).toList(),
      completados: pedidos.where((p) => p.estaEntregado).toList(),
      // `cancelado` y `devuelto` van juntos: para el cliente son lo mismo, un
      // pedido que no llegó. Son los dos únicos códigos terminales que quedan.
      cancelados: pedidos.where((p) => p.estaCancelado).toList(),
    );
  });
});

final pedidoProvider =
    FutureProvider.autoDispose.family<Pedido, int>((ref, id) async {
  return ref.watch(pedidosRepositoryProvider).detalle(id);
});
