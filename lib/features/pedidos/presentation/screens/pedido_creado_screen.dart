import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/map_style.dart';
import '../../../../shared/models/pedido.dart';
import '../../../../shared/widgets/piezas_pedido.dart';

class PedidoCreadoScreen extends StatelessWidget {
  const PedidoCreadoScreen({super.key, required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final destino = pedido.direccionDestino;

    return Scaffold(
      body: SafeArea(
        // Los `Spacer` centran el mensaje cuando sobra alto, pero en una
        // pantalla corta —o con la tipografia del sistema al maximo— la columna
        // se desborda. Envolverla asi conserva el centrado y deja que ruede
        // cuando no cabe.
        child: LayoutBuilder(
          builder: (context, restricciones) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: restricciones.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(MapStyle.esp5),
                  child: Column(
                    children: [
                      const Spacer(),
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: MapStyle.exito.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 48, color: MapStyle.exito),
                      ),
                      const SizedBox(height: MapStyle.esp5),
                      const Text(
                        '¡Pedido creado!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: MapStyle.textoFuerte,
                        ),
                      ),
                      const SizedBox(height: MapStyle.esp2),
                      const Text(
                        'Guarda este código para seguir tu envío.',
                        textAlign: TextAlign.center,
                        style: MapStyle.direccion,
                      ),
                      const SizedBox(height: MapStyle.esp5),
                      _CodigoSeguimiento(codigo: pedido.codigoSeguimiento),
                      const SizedBox(height: MapStyle.esp5),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(MapStyle.esp4),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                      child: EtiquetaSeccionTexto('Estado')),
                                  EstadoPedidoChip(
                                    pedido.estado.codigo,
                                    nombre: pedido.estado.nombre,
                                  ),
                                ],
                              ),
                              if (destino != null) ...[
                                const Divider(height: MapStyle.esp5),
                                FilaDato(
                                  'Destino',
                                  destino.lineaCompleta,
                                  icono: Icons.place_outlined,
                                ),
                              ],
                              // `fecha_estimada_entrega` llega vacía: el backend no la
                              // calcula al crear. No se pinta una fila con un guion.
                              if (pedido.fechaEstimadaEntrega != null)
                                FilaDato(
                                  'Entrega estimada',
                                  fechaCorta(pedido.fechaEstimadaEntrega!),
                                  icono: Icons.event_available_outlined,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          // `go` y no `push`: esta pantalla reemplazó al formulario, y
                          // detrás de ella ya no hay nada a lo que volver.
                          context.go('/pedidos');
                          context.push('/pedidos/${pedido.id}');
                        },
                        icon: const Icon(Icons.receipt_long_outlined, size: 20),
                        label: const Text('Ver pedido'),
                      ),
                      const SizedBox(height: MapStyle.esp3),
                      OutlinedButton(
                        onPressed: () => context.go('/inicio'),
                        child: const Text('Volver al inicio'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CodigoSeguimiento extends StatelessWidget {
  const _CodigoSeguimiento({required this.codigo});

  final String codigo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: MapStyle.esp4,
        vertical: MapStyle.esp4,
      ),
      decoration: BoxDecoration(
        color: MapStyle.primario.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MapStyle.primario.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const EtiquetaSeccionTexto('Código de seguimiento'),
          const SizedBox(height: MapStyle.esp2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: SelectableText(
                  codigo,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: MapStyle.textoFuerte,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: MapStyle.esp2),
              IconButton(
                tooltip: 'Copiar código',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: codigo));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado.')),
                  );
                },
                icon: const Icon(Icons.copy_rounded,
                    size: 20, color: MapStyle.primario),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EtiquetaSeccionTexto extends StatelessWidget {
  const EtiquetaSeccionTexto(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) =>
      Text(texto.toUpperCase(), style: MapStyle.etiqueta);
}
