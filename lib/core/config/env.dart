class Env {
  static const String _host = '192.168.18.137:8000';

  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://$_host/api/v1',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://$_host',
  );

  static const String osrmUrl = String.fromEnvironment(
    'OSRM_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  static const String nominatimUrl = String.fromEnvironment(
    'NOMINATIM_URL',
    defaultValue: 'https://nominatim.openstreetmap.org',
  );

  static const String paisGeocoding = String.fromEnvironment(
    'PAIS_GEOCODING',
    defaultValue: 'pe',
  );
}
