import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/errores_api.dart';
import '../../../../core/theme/map_style.dart';
import '../../../../shared/models/usuario.dart';
import '../../../../shared/widgets/mapa/hoja_mapa.dart';
import '../../../../shared/widgets/mapa/piezas_mapa.dart';
import '../../../../shared/widgets/piezas_pedido.dart';
import '../pedidos_provider.dart';

Future<bool> mostrarHojaCalificacion(
  BuildContext context, {
  required int pedidoId,
  Usuario? repartidor,
}) async {
  final guardada = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HojaCalificacion(pedidoId: pedidoId, repartidor: repartidor),
  );
  return guardada ?? false;
}

class _HojaCalificacion extends ConsumerStatefulWidget {
  const _HojaCalificacion({required this.pedidoId, this.repartidor});

  final int pedidoId;
  final Usuario? repartidor;

  @override
  ConsumerState<_HojaCalificacion> createState() => _HojaCalificacionState();
}

class _HojaCalificacionState extends ConsumerState<_HojaCalificacion> {
  final _comentario = TextEditingController();
  int _puntuacion = 0;
  bool _enviando = false;
  String? _error;

  static const _leyendas = {
    1: 'Muy mala',
    2: 'Mala',
    3: 'Regular',
    4: 'Buena',
    5: 'Excelente',
  };

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_puntuacion == 0) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref.read(pedidosRepositoryProvider).calificar(
            widget.pedidoId,
            _puntuacion,
            comentario: _comentario.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = mensajeDeError(e, respaldo: 'No se pudo guardar tu calificación.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final repartidor = widget.repartidor;

    return Padding(
      // Sube con el teclado: sin esto el campo de comentario queda tapado.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
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

              const Text(
                '¿Cómo fue tu entrega?',
                textAlign: TextAlign.center,
                style: MapStyle.titulo,
              ),
              const SizedBox(height: MapStyle.esp2),

              if (repartidor != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AvatarUsuario(usuario: repartidor, radio: 16),
                    const SizedBox(width: MapStyle.esp2),
                    Flexible(
                      child: Text(
                        repartidor.nombreCompleto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MapStyle.direccion,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MapStyle.esp4),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var estrella = 1; estrella <= 5; estrella++)
                    IconButton(
                      onPressed: _enviando
                          ? null
                          : () => setState(() => _puntuacion = estrella),
                      iconSize: 38,
                      // Cada estrella es un objetivo de toque completo: con el
                      // tamaño justo del icono se falla la puntuación.
                      constraints: const BoxConstraints(
                        minWidth: MapStyle.tap,
                        minHeight: MapStyle.tap,
                      ),
                      tooltip: _leyendas[estrella],
                      icon: Icon(
                        estrella <= _puntuacion
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: estrella <= _puntuacion
                            ? const Color(0xFFF59E0B)
                            : MapStyle.neutro,
                      ),
                    ),
                ],
              ),

              SizedBox(
                height: 22,
                child: Center(
                  child: Text(
                    _leyendas[_puntuacion] ?? 'Toca una estrella para puntuar',
                    style: MapStyle.secundario,
                  ),
                ),
              ),
              const SizedBox(height: MapStyle.esp4),

              TextField(
                controller: _comentario,
                enabled: !_enviando,
                maxLines: 3,
                maxLength: 255, // el límite real de `Calificacion.comentario`
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Comentario (opcional)',
                  alignLabelWithHint: true,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: MapStyle.esp2),
                AvisoError(_error!),
                const SizedBox(height: MapStyle.esp2),
              ],

              const SizedBox(height: MapStyle.esp2),
              FilledButton(
                onPressed: _puntuacion == 0 || _enviando ? null : _enviar,
                child: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enviar calificación'),
              ),
              TextButton(
                onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
                child: const Text('Ahora no'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
