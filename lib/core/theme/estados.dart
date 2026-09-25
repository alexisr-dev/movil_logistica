import 'package:flutter/material.dart';

import 'map_style.dart';

@immutable
class Aspecto {
  const Aspecto({required this.color, required this.icono, required this.etiqueta});

  final Color color;
  final IconData icono;
  final String etiqueta;
}

const _desconocido = Aspecto(
  color: MapStyle.neutro,
  icono: Icons.help_outline,
  etiqueta: 'Desconocido',
);

// -----------------------------------------------------------------------------
// Estado del pedido
// -----------------------------------------------------------------------------

const Map<String, Aspecto> _pedido = {
  'pendiente': Aspecto(
    color: MapStyle.aviso,
    icono: Icons.schedule,
    etiqueta: 'Pendiente',
  ),
  'confirmado': Aspecto(
    color: Color(0xFF3B82F6),
    icono: Icons.check_circle_outline,
    etiqueta: 'Confirmado',
  ),
  'en_preparacion': Aspecto(
    color: Color(0xFF8B5CF6),
    icono: Icons.inventory_2_outlined,
    etiqueta: 'En preparación',
  ),
  'en_camino': Aspecto(
    color: Color(0xFF0EA5E9),
    icono: Icons.local_shipping_outlined,
    etiqueta: 'En camino',
  ),
  'entregado': Aspecto(
    color: MapStyle.exito,
    icono: Icons.check_circle,
    etiqueta: 'Entregado',
  ),
  'cancelado': Aspecto(
    color: MapStyle.peligro,
    icono: Icons.cancel_outlined,
    etiqueta: 'Cancelado',
  ),
  'devuelto': Aspecto(
    color: Color(0xFFEA580C),
    icono: Icons.keyboard_return,
    etiqueta: 'Devuelto',
  ),
};

const List<String> caminoDelPedido = [
  'pendiente',
  'confirmado',
  'en_preparacion',
  'en_camino',
  'entregado',
];

Aspecto aspectoDePedido(String codigo) => _pedido[codigo] ?? _desconocido;

// -----------------------------------------------------------------------------
// Estado de la ruta
// -----------------------------------------------------------------------------

const Map<String, Aspecto> _ruta = {
  'planificada': Aspecto(
    color: MapStyle.neutro,
    icono: Icons.event_note_outlined,
    etiqueta: 'Planificada',
  ),
  'en_curso': Aspecto(
    color: MapStyle.primario,
    icono: Icons.navigation,
    etiqueta: 'En curso',
  ),
  'finalizada': Aspecto(
    color: MapStyle.exito,
    icono: Icons.flag,
    etiqueta: 'Finalizada',
  ),
  'cancelada': Aspecto(
    color: MapStyle.peligro,
    icono: Icons.block,
    etiqueta: 'Cancelada',
  ),
};

Aspecto aspectoDeRuta(String codigo) => _ruta[codigo] ?? _desconocido;

// -----------------------------------------------------------------------------
// Estado de la parada
// -----------------------------------------------------------------------------

const Map<String, Aspecto> _parada = {
  'pendiente': Aspecto(
    color: MapStyle.neutro,
    icono: Icons.radio_button_unchecked,
    etiqueta: 'Pendiente',
  ),
  'entregado': Aspecto(
    color: MapStyle.exito,
    icono: Icons.check_circle,
    etiqueta: 'Entregado',
  ),
  'fallido': Aspecto(
    color: MapStyle.peligro,
    icono: Icons.error_outline,
    etiqueta: 'Fallido',
  ),
};

Aspecto aspectoDeParada(String codigo) => _parada[codigo] ?? _desconocido;
