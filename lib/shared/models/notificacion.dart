class Notificacion {
  const Notificacion({
    required this.id,
    required this.leido,
    required this.fechaCreacion,
    this.pedidoId,
    this.tipo,
    this.titulo,
    this.mensaje,
  });

  final int id;
  final bool leido;
  final DateTime fechaCreacion;
  final int? pedidoId;
  final String? tipo;
  final String? titulo;
  final String? mensaje;

  bool get llevaAPedido => pedidoId != null;

  String get tituloVisible {
    final texto = titulo?.trim() ?? '';
    return texto.isEmpty ? 'Notificación' : texto;
  }

  String get mensajeVisible => mensaje?.trim() ?? '';

  factory Notificacion.fromJson(Map<String, dynamic> json) => Notificacion(
        id: json['id'] as int,
        leido: json['leido'] as bool? ?? false,
        fechaCreacion: DateTime.tryParse(json['fecha_creacion'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        pedidoId: json['pedido'] as int?,
        tipo: json['tipo'] as String?,
        titulo: json['titulo'] as String?,
        mensaje: json['mensaje'] as String?,
      );

  Notificacion copyWith({bool? leido}) => Notificacion(
        id: id,
        leido: leido ?? this.leido,
        fechaCreacion: fechaCreacion,
        pedidoId: pedidoId,
        tipo: tipo,
        titulo: titulo,
        mensaje: mensaje,
      );
}
