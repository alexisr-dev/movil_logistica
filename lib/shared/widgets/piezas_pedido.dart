import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/estados.dart';
import '../../core/theme/map_style.dart';
import '../models/pedido.dart';
import '../models/usuario.dart';
import 'mapa/piezas_mapa.dart';

final _formatoCorto = DateFormat('d MMM, HH:mm', 'es');
final _formatoDia = DateFormat('d MMM y', 'es');
final _formatoHora = DateFormat('HH:mm', 'es');

String fechaCorta(DateTime fecha) => _formatoCorto.format(fecha.toLocal());
String fechaDia(DateTime fecha) => _formatoDia.format(fecha.toLocal());
String soloHora(DateTime fecha) => _formatoHora.format(fecha.toLocal());

String hace(DateTime fecha) {
  final diferencia = DateTime.now().difference(fecha.toLocal());
  if (diferencia.inMinutes < 1) return 'ahora mismo';
  if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
  if (diferencia.inDays == 1) return 'ayer';
  if (diferencia.inDays < 7) return 'hace ${diferencia.inDays} días';
  return fechaDia(fecha);
}

class EstadoPedidoChip extends StatelessWidget {
  const EstadoPedidoChip(this.codigo, {super.key, this.nombre});

  final String codigo;

  final String? nombre;

  @override
  Widget build(BuildContext context) {
    final aspecto = aspectoDePedido(codigo);
    return ChipEstado(texto: nombre ?? aspecto.etiqueta, color: aspecto.color);
  }
}

class AvatarUsuario extends StatelessWidget {
  const AvatarUsuario({super.key, required this.usuario, this.radio = 22});

  final Usuario usuario;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final foto = usuario.fotoUrl;
    final iniciales = CircleAvatar(
      radius: radio,
      backgroundColor: MapStyle.primario.withOpacity(0.12),
      child: Text(
        usuario.iniciales,
        style: TextStyle(
          fontSize: radio * 0.7,
          fontWeight: FontWeight.w700,
          color: MapStyle.primario,
        ),
      ),
    );

    if (foto == null || foto.trim().isEmpty) return iniciales;

    return CircleAvatar(
      radius: radio,
      backgroundColor: MapStyle.primario.withOpacity(0.12),
      // `foto_url` apunta fuera de la app y puede estar caída o dar 404: sin
      // este respaldo, el avatar se quedaría como un hueco roto.
      child: ClipOval(
        child: Image.network(
          foto,
          width: radio * 2,
          height: radio * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => iniciales,
        ),
      ),
    );
  }
}

class FilaDato extends StatelessWidget {
  const FilaDato(this.etiqueta, this.valor, {super.key, this.icono});

  final String etiqueta;
  final String valor;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MapStyle.esp2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 17, color: MapStyle.neutro),
            const SizedBox(width: MapStyle.esp3),
          ],
          Expanded(
            flex: 4,
            child: Text(etiqueta, style: MapStyle.secundario),
          ),
          const SizedBox(width: MapStyle.esp3),
          Expanded(
            flex: 6,
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MapStyle.textoFuerte,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SeccionTarjeta extends StatelessWidget {
  const SeccionTarjeta({
    super.key,
    required this.titulo,
    required this.child,
    this.accion,
  });

  final String titulo;
  final Widget child;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: MapStyle.esp1,
            right: MapStyle.esp1,
            bottom: MapStyle.esp3,
          ),
          child: Row(
            children: [
              Expanded(child: EtiquetaSeccion(titulo)),
              if (accion != null) accion!,
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(MapStyle.esp4),
            child: child,
          ),
        ),
      ],
    );
  }
}

class TarjetaPedido extends StatelessWidget {
  const TarjetaPedido({
    super.key,
    required this.pedido,
    required this.onTap,
    this.ordenParada,
    this.horaEstimada,
    this.destacada = false,
    this.accion,
  });

  final Pedido pedido;
  final VoidCallback onTap;

  final int? ordenParada;
  final DateTime? horaEstimada;

  final bool destacada;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final aspecto = aspectoDePedido(pedido.estado.codigo);
    final destino = pedido.direccionDestino;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: destacada ? MapStyle.primario : MapStyle.borde,
          width: destacada ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MapStyle.esp4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Insignia(aspecto: aspecto, orden: ordenParada),
                  const SizedBox(width: MapStyle.esp3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pedido.codigoSeguimiento,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: MapStyle.textoFuerte,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pedido.descripcionCorta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MapStyle.secundario,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: MapStyle.esp2),
                  EstadoPedidoChip(
                    pedido.estado.codigo,
                    nombre: pedido.estado.nombre,
                  ),
                ],
              ),

              if (destino != null) ...[
                const SizedBox(height: MapStyle.esp3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 16, color: MapStyle.neutro),
                    const SizedBox(width: MapStyle.esp2),
                    Expanded(
                      child: Text(
                        destino.lineaCompleta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MapStyle.secundario,
                      ),
                    ),
                  ],
                ),
              ],

              if (horaEstimada != null) ...[
                const SizedBox(height: MapStyle.esp2),
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 16, color: MapStyle.neutro),
                    const SizedBox(width: MapStyle.esp2),
                    Text(
                      'Estimada ${soloHora(horaEstimada!)}',
                      style: MapStyle.secundario,
                    ),
                  ],
                ),
              ],

              if (accion != null) ...[
                const SizedBox(height: MapStyle.esp4),
                SizedBox(width: double.infinity, child: accion!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Insignia extends StatelessWidget {
  const _Insignia({required this.aspecto, this.orden});

  final Aspecto aspecto;
  final int? orden;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: aspecto.color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: orden != null
          ? Text(
              orden.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: aspecto.color,
              ),
            )
          : Icon(aspecto.icono, size: 20, color: aspecto.color),
    );
  }
}
