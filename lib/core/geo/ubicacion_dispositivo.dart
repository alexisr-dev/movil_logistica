import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum ErrorUbicacion {
  servicioApagado,
  permisoDenegado,
  permisoDenegadoParaSiempre,
  tiempoAgotado,
}

class UbicacionException implements Exception {
  const UbicacionException(this.motivo);

  final ErrorUbicacion motivo;

  String get mensaje {
    switch (motivo) {
      case ErrorUbicacion.servicioApagado:
        return 'El GPS está apagado. Actívalo para usar tu ubicación.';
      case ErrorUbicacion.permisoDenegado:
        return 'Se necesita permiso de ubicación para saber dónde estás.';
      case ErrorUbicacion.permisoDenegadoParaSiempre:
        return 'El permiso de ubicación está bloqueado. Habilítalo desde los '
            'ajustes de la aplicación.';
      case ErrorUbicacion.tiempoAgotado:
        return 'No se pudo fijar tu posición. Bajo techo el GPS tarda: sal a '
            'un sitio despejado o coloca el pin a mano.';
    }
  }

  @override
  String toString() => mensaje;
}

Future<void> asegurarPermisoUbicacion() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const UbicacionException(ErrorUbicacion.servicioApagado);
  }

  var permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
  }

  if (permiso == LocationPermission.deniedForever) {
    throw const UbicacionException(ErrorUbicacion.permisoDenegadoParaSiempre);
  }
  if (permiso == LocationPermission.denied) {
    throw const UbicacionException(ErrorUbicacion.permisoDenegado);
  }
}

class UbicacionPuntual {
  const UbicacionPuntual();

  Future<LatLng> punto({
    Duration limite = const Duration(seconds: 12),
  }) async {
    await asegurarPermisoUbicacion();

    try {
      final posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: limite,
      );
      return LatLng(posicion.latitude, posicion.longitude);
    } on TimeoutException {
      throw const UbicacionException(ErrorUbicacion.tiempoAgotado);
    } on LocationServiceDisabledException {
      // El usuario pudo apagar el GPS entre la comprobación y la lectura.
      throw const UbicacionException(ErrorUbicacion.servicioApagado);
    }
  }
}
