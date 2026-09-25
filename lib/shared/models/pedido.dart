import 'direccion.dart';
import 'usuario.dart';

class EstadoPedido {
  const EstadoPedido({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.orden = 0,
  });

  final int id;
  final String codigo;
  final String nombre;
  final int orden;

  static const desconocido =
      EstadoPedido(id: 0, codigo: '', nombre: 'Sin estado');

  factory EstadoPedido.fromJson(Map<String, dynamic> json) => EstadoPedido(
        id: json['id'] as int,
        codigo: json['codigo'] as String,
        nombre: json['nombre'] as String,
        orden: json['orden'] as int? ?? 0,
      );
}

class HistorialEstado {
  const HistorialEstado({
    required this.id,
    required this.estado,
    required this.fecha,
    this.comentario,
    this.usuarioId,
  });

  final int id;
  final EstadoPedido estado;
  final DateTime fecha;
  final String? comentario;
  final int? usuarioId;

  bool get tieneComentario =>
      comentario != null && comentario!.trim().isNotEmpty;

  factory HistorialEstado.fromJson(Map<String, dynamic> json) =>
      HistorialEstado(
        id: json['id'] as int,
        estado: EstadoPedido.fromJson(json['estado'] as Map<String, dynamic>),
        fecha: DateTime.parse(json['fecha'] as String),
        comentario: json['comentario'] as String?,
        usuarioId: json['usuario'] as int?,
      );
}

class Calificacion {
  const Calificacion({
    required this.id,
    required this.puntuacion,
    required this.fecha,
    this.comentario,
  });

  final int id;
  final int puntuacion;
  final DateTime fecha;
  final String? comentario;

  factory Calificacion.fromJson(Map<String, dynamic> json) => Calificacion(
        id: json['id'] as int,
        puntuacion: json['puntuacion'] as int,
        fecha: DateTime.parse(json['fecha'] as String),
        comentario: json['comentario'] as String?,
      );
}

class Pedido {
  const Pedido({
    required this.id,
    required this.codigoSeguimiento,
    required this.estado,
    required this.fechaCreacion,
    required this.direccionOrigen,
    required this.direccionDestino,
    required this.historial,
    required this.transicionesPermitidas,
    this.cliente,
    this.repartidor,
    this.descripcion,
    this.pesoKg,
    this.costoEnvio,
    this.fechaEstimadaEntrega,
    this.fechaEntregaReal,
    this.calificacion,
  });

  final int id;
  final String codigoSeguimiento;
  final EstadoPedido estado;
  final DateTime fechaCreacion;
  final Direccion? direccionOrigen;
  final Direccion? direccionDestino;
  final List<HistorialEstado> historial;

  final List<EstadoPedido> transicionesPermitidas;

  final Usuario? cliente;
  final Usuario? repartidor;
  final String? descripcion;
  final double? pesoKg;
  final double? costoEnvio;
  final DateTime? fechaEstimadaEntrega;
  final DateTime? fechaEntregaReal;
  final Calificacion? calificacion;

  // ---------------------------------------------------------------------------
  // Lecturas de conveniencia. Los códigos son los del backend, no inventados.
  // ---------------------------------------------------------------------------

  static const terminales = {'entregado', 'cancelado', 'devuelto'};

  bool get estaTerminado => terminales.contains(estado.codigo);
  bool get estaEnCurso => !estaTerminado;
  bool get estaEnCamino => estado.codigo == 'en_camino';
  bool get estaEntregado => estado.codigo == 'entregado';
  bool get estaCancelado =>
      estado.codigo == 'cancelado' || estado.codigo == 'devuelto';

  bool puedePasarA(String codigo) =>
      transicionesPermitidas.any((e) => e.codigo == codigo);

  bool get puedeCancelar => puedePasarA('cancelado');

  bool get puedeCalificar => estaEntregado && calificacion == null;

  bool get tieneRepartidor => repartidor != null;

  String get descripcionCorta {
    final texto = descripcion?.trim() ?? '';
    return texto.isEmpty ? 'Sin descripción' : texto;
  }

  factory Pedido.fromJson(Map<String, dynamic> json) {
    Direccion? direccion(String clave) {
      final valor = json[clave];
      return valor is Map<String, dynamic> ? Direccion.fromJson(valor) : null;
    }

    Usuario? usuario(String clave) {
      final valor = json[clave];
      return valor is Map<String, dynamic> ? Usuario.fromJson(valor) : null;
    }

    DateTime? fecha(String clave) {
      final valor = json[clave];
      return valor is String ? DateTime.tryParse(valor) : null;
    }

    // DRF serializa los `DecimalField` como texto ("12.50"), no como número.
    double? decimal(String clave) => json[clave] == null
        ? null
        : double.tryParse(json[clave].toString());

    final historial = ((json['historial'] as List?) ?? [])
        .map((e) => HistorialEstado.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final calificacion = json['calificacion'];

    return Pedido(
      id: json['id'] as int,
      codigoSeguimiento: json['codigo_seguimiento'] as String? ?? '',
      // Con guardia, como el resto de campos anidados: era el único cast a
      // pelo del modelo y bastaba una respuesta sin `estado` para tumbar la
      // app con «type 'Null' is not a subtype of type 'Map<String, dynamic>'».
      estado: json['estado'] is Map<String, dynamic>
          ? EstadoPedido.fromJson(json['estado'] as Map<String, dynamic>)
          : EstadoPedido.desconocido,
      fechaCreacion:
          fecha('fecha_creacion') ?? DateTime.fromMillisecondsSinceEpoch(0),
      direccionOrigen: direccion('direccion_origen'),
      direccionDestino: direccion('direccion_destino'),
      historial: historial,
      transicionesPermitidas: ((json['transiciones_permitidas'] as List?) ?? [])
          .map((e) => EstadoPedido.fromJson(e as Map<String, dynamic>))
          .toList(),
      cliente: usuario('cliente'),
      repartidor: usuario('repartidor'),
      descripcion: json['descripcion'] as String?,
      pesoKg: decimal('peso_kg'),
      costoEnvio: decimal('costo_envio'),
      fechaEstimadaEntrega: fecha('fecha_estimada_entrega'),
      fechaEntregaReal: fecha('fecha_entrega_real'),
      calificacion: calificacion is Map<String, dynamic>
          ? Calificacion.fromJson(calificacion)
          : null,
    );
  }
}
