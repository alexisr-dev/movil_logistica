import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/errores_api.dart';
import '../../../../core/theme/map_style.dart';
import '../../../../shared/widgets/mapa/hoja_mapa.dart';
import '../../../../shared/widgets/mapa/piezas_mapa.dart';
import '../../data/entregas_service.dart';
import '../entregas_provider.dart';

Future<CierreEntrega?> confirmarEntrega(
  BuildContext context,
  WidgetRef ref, {
  required int pedidoId,
  required String codigo,
  int? paradaId,
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      icon: const Icon(Icons.check_circle_outline,
          size: 34, color: MapStyle.exito),
      title: const Text('¿Confirmar entrega?'),
      content: Text(
        'El pedido $codigo quedará como entregado. Esta acción no se puede '
        'deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogo).pop(false),
          child: const Text('Todavía no'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogo).pop(true),
          style: FilledButton.styleFrom(backgroundColor: MapStyle.exito),
          child: const Text('Sí, entregado'),
        ),
      ],
    ),
  );

  if (confirmado != true || !context.mounted) return null;

  try {
    final cierre = await ref.read(entregasServiceProvider).cerrar(
          pedidoId: pedidoId,
          entregada: true,
          paradaId: paradaId,
        );
    refrescarEntregas(ref);
    return cierre;
  } catch (e) {
    return CierreEntrega(
      ok: false,
      mensaje: mensajeDeError(e, respaldo: 'No se pudo registrar la entrega.'),
    );
  }
}

Future<CierreEntrega?> registrarEntregaFallida(
  BuildContext context,
  WidgetRef ref, {
  required int pedidoId,
  required String codigo,
  int? paradaId,
}) async {
  return showModalBottomSheet<CierreEntrega>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HojaFallida(
      pedidoId: pedidoId,
      codigo: codigo,
      paradaId: paradaId,
    ),
  );
}

class _HojaFallida extends ConsumerStatefulWidget {
  const _HojaFallida({
    required this.pedidoId,
    required this.codigo,
    this.paradaId,
  });

  final int pedidoId;
  final String codigo;
  final int? paradaId;

  @override
  ConsumerState<_HojaFallida> createState() => _HojaFallidaState();
}

class _HojaFallidaState extends ConsumerState<_HojaFallida> {
  static const _motivos = [
    'Nadie en el domicilio',
    'Dirección incorrecta',
    'El cliente rechazó el paquete',
    'No se pudo acceder a la zona',
    'Cliente no responde',
  ];

  final _detalle = TextEditingController();
  String? _motivo;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _detalle.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (_motivo == null) return;

    setState(() {
      _enviando = true;
      _error = null;
    });

    // El motivo elegido más lo que haya escrito, recortado al límite real de
    // `HistorialEstadoPedido.comentario`.
    final extra = _detalle.text.trim();
    var comentario = extra.isEmpty ? _motivo! : '$_motivo: $extra';
    if (comentario.length > 255) comentario = comentario.substring(0, 255);

    try {
      final cierre = await ref.read(entregasServiceProvider).cerrar(
            pedidoId: widget.pedidoId,
            entregada: false,
            paradaId: widget.paradaId,
            comentario: comentario,
          );
      refrescarEntregas(ref);
      if (mounted) Navigator.of(context).pop(cierre);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = mensajeDeError(e,
            respaldo: 'No se pudo registrar la entrega fallida.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            MapStyle.esp5,
            MapStyle.esp3,
            MapStyle.esp5,
            MapStyle.esp5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AsaHoja()),
              const SizedBox(height: MapStyle.esp3),

              const Row(
                children: [
                  Icon(Icons.error_outline, color: MapStyle.peligro, size: 24),
                  SizedBox(width: MapStyle.esp2),
                  Expanded(
                    child: Text(
                      'No pude realizar la entrega',
                      style: MapStyle.titulo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MapStyle.esp2),
              Text(
                'Pedido ${widget.codigo}. Indica qué pasó para que el operador '
                'pueda reprogramarlo.',
                style: MapStyle.direccion,
              ),
              const SizedBox(height: MapStyle.esp4),

              const EtiquetaSeccion('Motivo'),
              const SizedBox(height: MapStyle.esp2),
              ..._motivos.map(
                (motivo) => RadioListTile<String>(
                  value: motivo,
                  groupValue: _motivo,
                  onChanged: _enviando
                      ? null
                      : (valor) => setState(() => _motivo = valor),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    motivo,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: MapStyle.textoFuerte,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: MapStyle.esp3),
              TextField(
                controller: _detalle,
                enabled: !_enviando,
                maxLines: 2,
                maxLength: 180,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Detalle (opcional)',
                  hintText: 'Añade lo que ayude a entender qué pasó',
                  alignLabelWithHint: true,
                ),
              ),

              Container(
                padding: const EdgeInsets.all(MapStyle.esp3),
                decoration: BoxDecoration(
                  color: MapStyle.superficieTenue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: MapStyle.neutro),
                    SizedBox(width: MapStyle.esp2),
                    Expanded(
                      child: Text(
                        'El pedido se marcará como devuelto y la parada como '
                        'fallida.',
                        style: MapStyle.secundario,
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: MapStyle.esp3),
                AvisoError(_error!),
              ],

              const SizedBox(height: MapStyle.esp4),
              FilledButton(
                onPressed: _motivo == null || _enviando ? null : _registrar,
                style: FilledButton.styleFrom(
                  backgroundColor: MapStyle.peligro,
                ),
                child: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Registrar entrega fallida'),
              ),
              TextButton(
                onPressed:
                    _enviando ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void mostrarResultadoCierre(BuildContext context, CierreEntrega cierre) {
  final aviso = cierre.avisoPendiente;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(aviso == null ? cierre.mensaje : '${cierre.mensaje}. $aviso'),
      backgroundColor: cierre.ok ? null : MapStyle.peligro,
      duration: Duration(seconds: aviso == null ? 3 : 6),
    ),
  );
}
