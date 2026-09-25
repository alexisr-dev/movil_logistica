import 'package:flutter/material.dart';

import '../../../../core/theme/estados.dart';
import '../../../../core/theme/map_style.dart';
import '../../../../shared/models/pedido.dart';
import '../../../../shared/widgets/piezas_pedido.dart';

class LineaTiempoPedido extends StatelessWidget {
  const LineaTiempoPedido({super.key, required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final pasos = _construirPasos();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < pasos.length; i++)
          _Paso(
            paso: pasos[i],
            primero: i == 0,
            ultimo: i == pasos.length - 1,
          ),
      ],
    );
  }

  List<_PasoDato> _construirPasos() {
    // Cuándo ocurrió cada estado, según el historial. Si un estado se repitiera,
    // manda la primera vez: es cuando el pedido llegó ahí.
    final ocurrido = <String, DateTime>{};
    for (final entrada in pedido.historial) {
      ocurrido.putIfAbsent(entrada.estado.codigo, () => entrada.fecha);
    }
    final comentarios = <String, String>{};
    for (final entrada in pedido.historial) {
      if (entrada.tieneComentario) {
        comentarios[entrada.estado.codigo] = entrada.comentario!.trim();
      }
    }

    // El alta no siempre deja rastro en el historial: `perform_create` fija el
    // estado inicial sin pasar por `cambiar_estado`. Se usa la fecha de
    // creación del pedido, que es el mismo instante.
    ocurrido.putIfAbsent('pendiente', () => pedido.fechaCreacion);

    final actual = pedido.estado.codigo;
    final cortado = actual == 'cancelado' || actual == 'devuelto';

    final pasos = <_PasoDato>[];
    for (final codigo in caminoDelPedido) {
      final momento = ocurrido[codigo];
      // Si el pedido se cortó, no se dibujan los pasos que ya no van a pasar.
      if (cortado && momento == null) break;

      pasos.add(_PasoDato(
        codigo: codigo,
        momento: momento,
        comentario: comentarios[codigo],
        alcanzado: momento != null,
        esActual: codigo == actual,
      ));
    }

    if (cortado) {
      pasos.add(_PasoDato(
        codigo: actual,
        momento: ocurrido[actual],
        comentario: comentarios[actual],
        alcanzado: true,
        esActual: true,
      ));
    }

    return pasos;
  }
}

class _PasoDato {
  const _PasoDato({
    required this.codigo,
    required this.alcanzado,
    required this.esActual,
    this.momento,
    this.comentario,
  });

  final String codigo;
  final bool alcanzado;
  final bool esActual;
  final DateTime? momento;
  final String? comentario;
}

class _Paso extends StatelessWidget {
  const _Paso({required this.paso, required this.primero, required this.ultimo});

  final _PasoDato paso;
  final bool primero;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    final aspecto = aspectoDePedido(paso.codigo);
    final color = paso.alcanzado ? aspecto.color : MapStyle.neutro;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // El tramo de arriba se pinta del color del paso anterior solo
                // si este ya se alcanzó: así la línea de color mide exactamente
                // lo recorrido.
                Expanded(
                  flex: 0,
                  child: SizedBox(
                    height: primero ? 6 : 0,
                    width: 2,
                    child: ColoredBox(
                      color: primero ? Colors.transparent : color,
                    ),
                  ),
                ),
                _Punto(
                  color: color,
                  relleno: paso.alcanzado,
                  actual: paso.esActual,
                  icono: aspecto.icono,
                ),
                if (!ultimo)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: paso.alcanzado ? color : MapStyle.borde,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: MapStyle.esp3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 2,
                bottom: ultimo ? 0 : MapStyle.esp5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aspecto.etiqueta,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          paso.esActual ? FontWeight.w700 : FontWeight.w600,
                      color: paso.alcanzado
                          ? MapStyle.textoFuerte
                          : MapStyle.neutro,
                    ),
                  ),
                  if (paso.momento != null) ...[
                    const SizedBox(height: 2),
                    Text(fechaCorta(paso.momento!), style: MapStyle.secundario),
                  ],
                  if (paso.comentario != null) ...[
                    const SizedBox(height: MapStyle.esp2),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(MapStyle.esp3 - 2),
                      decoration: BoxDecoration(
                        color: MapStyle.superficieTenue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        paso.comentario!,
                        style: MapStyle.secundario,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({
    required this.color,
    required this.relleno,
    required this.actual,
    required this.icono,
  });

  final Color color;
  final bool relleno;
  final bool actual;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: relleno ? color : MapStyle.superficie,
        shape: BoxShape.circle,
        border: Border.all(
          color: relleno ? color : MapStyle.borde,
          width: 2,
        ),
        // Un halo solo en el paso actual: dice dónde está el pedido ahora sin
        // añadir ningún texto.
        boxShadow: actual
            ? [BoxShadow(color: color.withOpacity(0.22), blurRadius: 0, spreadRadius: 3)]
            : null,
      ),
      alignment: Alignment.center,
      child: relleno
          ? Icon(icono, size: 14, color: Colors.white)
          : const SizedBox.shrink(),
    );
  }
}
