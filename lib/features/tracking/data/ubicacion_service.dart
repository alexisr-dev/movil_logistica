import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/geo/ubicacion_dispositivo.dart';

// La comprobación de GPS y permiso y su excepción se mudaron a
// `core/geo/ubicacion_dispositivo.dart` cuando el cliente necesitó pulsar «Mi
// ubicación» al escribir una dirección. Se reexportan para que quien ya
// dependía de este archivo —`reparto_provider`— no tenga que enterarse.
export '../../../core/geo/ubicacion_dispositivo.dart'
    show ErrorUbicacion, UbicacionException;

class UbicacionService {
  Future<void> asegurarPermiso() async {
    await asegurarPermisoUbicacion();
    await _pedirPermisoDeNotificaciones();
  }

  Future<void> _pedirPermisoDeNotificaciones() async {
    if (!Platform.isAndroid) return;
    if (await Permission.notification.isGranted) return;
    await Permission.notification.request();
  }

  Stream<Position> flujo({int metrosMinimos = 10}) {
    return Geolocator.getPositionStream(
      locationSettings: Platform.isAndroid
          ? _ajustesAndroid(metrosMinimos)
          : LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: metrosMinimos,
            ),
    );
  }

  AndroidSettings _ajustesAndroid(int metrosMinimos) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: metrosMinimos,
      intervalDuration: const Duration(seconds: 5),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Reparto en curso',
        notificationText: 'Compartiendo tu ubicación con el cliente.',
        notificationChannelName: 'Reparto en curso',
        // Mantiene el proceso despierto para que los puntos lleguen según se
        // producen, en vez de en ráfagas cuando el sistema despierta.
        enableWakeLock: true,
        // No descartable: si el repartidor pudiera deslizarla, cortaría el
        // seguimiento sin enterarse.
        setOngoing: true,
      ),
    );
  }

  Future<Position> posicionActual() => Geolocator.getCurrentPosition();
}
