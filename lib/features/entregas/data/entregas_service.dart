import '../../../shared/models/pedido.dart';
import '../../pedidos/data/pedidos_repository.dart';
import '../../rutas/data/rutas_repository.dart';

class CierreEntrega {
  const CierreEntrega({
    required this.ok,
    required this.mensaje,
    this.avisoPendiente,
  });

  final bool ok;
  final String mensaje;

  final String? avisoPendiente;
}

class EntregasService {
  EntregasService(this._pedidos, this._rutas);

  final PedidosRepository _pedidos;
  final RutasRepository _rutas;

  static const _codigoEntregado = 'entregado';
  static const _codigoDevuelto = 'devuelto';

  Future<CierreEntrega> cerrar({
    required int pedidoId,
    required bool entregada,
    int? paradaId,
    String comentario = '',
  }) async {
    if (paradaId != null) {
      final resultado = await _rutas.marcarParada(
        paradaId,
        entregada: entregada,
        comentario: comentario,
      );
      return CierreEntrega(
        ok: true,
        mensaje: entregada
            ? 'Entrega completada'
            : 'Entrega marcada como fallida',
        // El backend avisa si el pedido no pudo avanzar (por ejemplo, porque
        // nadie lo puso «en camino»). La parada sí quedó registrada.
        avisoPendiente: resultado.pedidoActualizado ? null : resultado.motivo,
      );
    }

    // Sin ruta planificada: solo se mueve el pedido.
    await _pedidos.cambiarEstado(
      pedidoId,
      entregada ? _codigoEntregado : _codigoDevuelto,
      comentario: comentario,
    );
    return CierreEntrega(
      ok: true,
      mensaje: entregada ? 'Entrega completada' : 'Entrega marcada como fallida',
    );
  }

  Future<Pedido> ponerEnCamino(Pedido pedido) async {
    const objetivo = 'en_camino';
    // Orden del camino feliz. Se recorre por `orden` del estado y no por una
    // lista escrita aquí, para no duplicar la máquina de estados del backend.
    var actual = pedido;
    // Tope de seguridad: el camino real son tres saltos como mucho
    // (pendiente → confirmado → en_preparacion → en_camino). Sin él, un backend
    // con un ciclo dejaría este bucle girando para siempre.
    for (var intento = 0; intento < 4; intento++) {
      if (actual.estado.codigo == objetivo) return actual;

      final siguiente = actual.transicionesPermitidas
          .where((e) => e.codigo != 'cancelado' && e.codigo != 'devuelto')
          .fold<EstadoPedido?>(null, (mejor, e) {
        if (mejor == null) return e;
        return e.orden < mejor.orden ? e : mejor;
      });

      if (siguiente == null) {
        throw EstadoNoAlcanzable(actual.estado.nombre);
      }

      await _pedidos.cambiarEstado(actual.id, siguiente.codigo);
      actual = await _pedidos.detalle(actual.id);
    }
    return actual;
  }
}

class EstadoNoAlcanzable implements Exception {
  const EstadoNoAlcanzable(this.estadoActual);

  final String estadoActual;

  @override
  String toString() =>
      'Este pedido está en "$estadoActual" y ya no puede salir a reparto.';
}
