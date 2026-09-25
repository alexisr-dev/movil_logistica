import 'package:latlong2/latlong.dart';

class Lugar {
  const Lugar({
    required this.punto,
    required this.etiqueta,
    this.calle,
    this.numero,
    this.distrito,
    this.ciudad,
  });

  final LatLng punto;

  final String etiqueta;

  final String? calle;
  final String? numero;
  final String? distrito;
  final String? ciudad;

  String get detalle {
    final partes = <String>[];
    for (final parte in [distrito, ciudad]) {
      final limpio = parte?.trim();
      if (limpio == null || limpio.isEmpty) continue;
      if (partes.any((p) => p.toLowerCase() == limpio.toLowerCase())) continue;
      partes.add(limpio);
    }
    return partes.join(', ');
  }

  String get lineaCompleta =>
      [etiqueta, detalle].where((p) => p.isNotEmpty).join(', ');

  factory Lugar.fromNominatim(Map<String, dynamic> json) {
    final direccion = (json['address'] as Map?)?.cast<String, dynamic>() ?? {};

    String? campo(List<String> claves) {
      for (final clave in claves) {
        final valor = direccion[clave];
        if (valor is String && valor.trim().isNotEmpty) return valor.trim();
      }
      return null;
    }

    // Una vía puede venir como `road`, pero también como peatonal, pasaje o
    // carretera según cómo esté mapeada en OSM.
    final calle = campo(['road', 'pedestrian', 'footway', 'residential',
        'highway', 'path']);
    final numero = campo(['house_number']);

    // En Perú, Nominatim mete el distrito en cualquiera de estas y la ciudad
    // en `city` unas veces y en `province`/`county` otras. Se prueban en orden
    // de lo más pequeño a lo más grande.
    final distrito =
        campo(['suburb', 'neighbourhood', 'city_district', 'town', 'village']);
    final ciudad = campo(['city', 'province', 'county', 'state_district',
        'state']);

    // `name` es el nombre propio del sitio. Solo manda cuando no es la calle:
    // para «Avenida Grau» name y road son lo mismo y no aporta.
    final nombre = campo(['name']);
    final calleYNumero =
        [calle, numero].where((p) => p != null && p.isNotEmpty).join(' ');

    final etiqueta = calleYNumero.isNotEmpty
        ? calleYNumero
        : (nombre ??
            // Último recurso: el primer tramo de `display_name`, que siempre
            // es la parte más específica. Nunca la cadena entera: acaba en
            // «…, 20001, Perú».
            (json['display_name'] as String? ?? '').split(',').first.trim());

    return Lugar(
      punto: LatLng(
        double.parse(json['lat'].toString()),
        double.parse(json['lon'].toString()),
      ),
      etiqueta: etiqueta,
      calle: calle ?? (calleYNumero.isEmpty ? nombre : null),
      numero: numero,
      distrito: distrito,
      ciudad: ciudad,
    );
  }
}
