class PerfilRepartidor {
  const PerfilRepartidor({
    required this.id,
    required this.disponible,
    this.tipoVehiculo,
    this.placa,
    this.licencia,
    this.calificacionPromedio,
  });

  final int id;
  final bool disponible;
  final String? tipoVehiculo;
  final String? placa;
  final String? licencia;
  final double? calificacionPromedio;

  bool get tieneVehiculo =>
      _lleno(tipoVehiculo) || _lleno(placa) || _lleno(licencia);

  static bool _lleno(String? valor) => valor != null && valor.trim().isNotEmpty;

  factory PerfilRepartidor.fromJson(Map<String, dynamic> json) {
    return PerfilRepartidor(
      id: json['id'] as int,
      disponible: json['disponible'] as bool? ?? true,
      tipoVehiculo: json['tipo_vehiculo'] as String?,
      placa: json['placa'] as String?,
      licencia: json['licencia'] as String?,
      // DRF serializa los `DecimalField` como texto, no como número.
      calificacionPromedio: json['calificacion_promedio'] == null
          ? null
          : double.tryParse(json['calificacion_promedio'].toString()),
    );
  }

  PerfilRepartidor copyWith({bool? disponible}) => PerfilRepartidor(
        id: id,
        disponible: disponible ?? this.disponible,
        tipoVehiculo: tipoVehiculo,
        placa: placa,
        licencia: licencia,
        calificacionPromedio: calificacionPromedio,
      );
}

class Usuario {
  const Usuario({
    required this.id,
    required this.email,
    required this.nombre,
    required this.apellido,
    required this.rol,
    this.telefono,
    this.fotoUrl,
    this.perfilRepartidor,
  });

  final int id;
  final String email;
  final String nombre;
  final String apellido;
  final String rol;
  final String? telefono;
  final String? fotoUrl;
  final PerfilRepartidor? perfilRepartidor;

  bool get esRepartidor => rol == 'repartidor';
  bool get esCliente => rol == 'cliente';

  String get nombreCompleto => '$nombre $apellido'.trim();

  String get iniciales {
    final letras = [nombre, apellido]
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.trim()[0].toUpperCase())
        .take(2)
        .join();
    return letras.isEmpty ? '?' : letras;
  }

  bool get tieneTelefono => telefono != null && telefono!.trim().isNotEmpty;

  factory Usuario.fromJson(Map<String, dynamic> json) {
    final perfil = json['perfil_repartidor'];
    return Usuario(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      apellido: json['apellido'] as String? ?? '',
      rol: json['rol'] as String? ?? 'cliente',
      telefono: json['telefono'] as String?,
      fotoUrl: json['foto_url'] as String?,
      perfilRepartidor: perfil is Map<String, dynamic>
          ? PerfilRepartidor.fromJson(perfil)
          : null,
    );
  }
}
