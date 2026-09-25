import 'package:latlong2/latlong.dart';

class Direccion {
  const Direccion({
    required this.id,
    required this.calle,
    required this.latitud,
    required this.longitud,
    this.alias,
    this.numero,
    this.distrito,
    this.ciudad,
    this.referencia,
    this.esDefault = false,
  });

  final int id;
  final String calle;
  final double latitud;
  final double longitud;
  final String? alias;
  final String? numero;
  final String? distrito;
  final String? ciudad;
  final String? referencia;
  final bool esDefault;

  LatLng get punto => LatLng(latitud, longitud);

  String get titulo =>
      (alias != null && alias!.trim().isNotEmpty) ? alias!.trim() : calle;

  String get lineaCompleta {
    final calleYNumero = [calle, numero]
        .where((p) => p != null && p.trim().isNotEmpty)
        .join(' ');
    return [calleYNumero, distrito, ciudad]
        .where((p) => p != null && p.trim().isNotEmpty)
        .join(' · ');
  }

  bool get tieneReferencia =>
      referencia != null && referencia!.trim().isNotEmpty;

  String get lineaHumana {
    final calleYNumero = [calle, numero]
        .where((p) => p != null && p.trim().isNotEmpty)
        .join(' ');
    return [
      if (calleYNumero.isNotEmpty) calleYNumero,
      if (tieneReferencia) referencia!.trim(),
    ].join(', ');
  }

  factory Direccion.fromJson(Map<String, dynamic> json) => Direccion(
        id: json['id'] as int,
        calle: json['calle'] as String? ?? '',
        latitud: (json['latitud'] as num).toDouble(),
        longitud: (json['longitud'] as num).toDouble(),
        alias: json['alias'] as String?,
        numero: json['numero'] as String?,
        distrito: json['distrito'] as String?,
        ciudad: json['ciudad'] as String?,
        referencia: json['referencia'] as String?,
        esDefault: json['es_default'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'calle': calle,
        'latitud': latitud,
        'longitud': longitud,
        'alias': alias,
        'numero': numero,
        'distrito': distrito,
        'ciudad': ciudad,
        'referencia': referencia,
        'es_default': esDefault,
      };

  Direccion copyWith({bool? esDefault}) => Direccion(
        id: id,
        calle: calle,
        latitud: latitud,
        longitud: longitud,
        alias: alias,
        numero: numero,
        distrito: distrito,
        ciudad: ciudad,
        referencia: referencia,
        esDefault: esDefault ?? this.esDefault,
      );
}
