import 'package:latlong2/latlong.dart';

List<LatLng> decodificarPolyline(String codificado, {int precision = 5}) {
  final puntos = <LatLng>[];
  final factor = _potencia10(precision);

  var indice = 0;
  var lat = 0;
  var lng = 0;

  while (indice < codificado.length) {
    var resultado = 1;
    var desplazamiento = 0;
    int b;
    do {
      b = codificado.codeUnitAt(indice++) - 63 - 1;
      resultado += b << desplazamiento;
      desplazamiento += 5;
    } while (b >= 0x1f);
    lat += (resultado & 1) != 0 ? ~(resultado >> 1) : resultado >> 1;

    resultado = 1;
    desplazamiento = 0;
    do {
      b = codificado.codeUnitAt(indice++) - 63 - 1;
      resultado += b << desplazamiento;
      desplazamiento += 5;
    } while (b >= 0x1f);
    lng += (resultado & 1) != 0 ? ~(resultado >> 1) : resultado >> 1;

    puntos.add(LatLng(lat / factor, lng / factor));
  }

  return puntos;
}

int _potencia10(int exponente) {
  var valor = 1;
  for (var i = 0; i < exponente; i++) {
    valor *= 10;
  }
  return valor;
}
