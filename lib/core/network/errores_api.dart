import 'package:dio/dio.dart';

import '../config/env.dart';

String mensajeDeErrorDrf(DioException e, {String respaldo = 'No se pudo completar la operación.'}) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'El servidor no responde (${Env.apiUrl}).\n'
          'Revisa que el backend esté corriendo y que estés en la misma red Wi-Fi.';
    case DioExceptionType.connectionError:
      return 'No se pudo conectar a ${Env.apiUrl}.\n'
          'Comprueba la IP del servidor, el firewall y la conexión Wi-Fi.';
    case DioExceptionType.badResponse:
      return _delCuerpo(e.response?.data) ?? _porEstado(e.response?.statusCode, respaldo);
    default:
      return 'Fallo de red: ${e.message ?? e.type.name}';
  }
}

String mensajeDeError(Object error, {String respaldo = 'No se pudo completar la operación.'}) {
  if (error is DioException) return mensajeDeErrorDrf(error, respaldo: respaldo);
  // Excepciones propias (`DireccionEnUso`, `UbicacionException`) definen un
  // `toString()` que ya es el mensaje para el usuario.
  final texto = error.toString().trim();
  if (texto.isEmpty || texto.startsWith('Instance of')) return respaldo;
  return texto;
}

String? _delCuerpo(dynamic datos) {
  if (datos is String && datos.trim().isNotEmpty) return datos;
  if (datos is! Map) return null;

  final detalle = datos['detail'];
  if (detalle is String && detalle.isNotEmpty) return detalle;

  final partes = <String>[];
  datos.forEach((clave, valor) {
    if (clave == 'code' || clave == 'codigo') return;
    final texto = valor is List ? valor.join(' ') : valor.toString();
    if (texto.isEmpty) return;
    // `non_field_errors` no tiene campo al que anclarse: se muestra suelto.
    partes.add(clave == 'non_field_errors' ? texto : '${_etiqueta(clave)}: $texto');
  });

  return partes.isEmpty ? null : partes.join('\n');
}

String _porEstado(int? codigo, String respaldo) {
  if (codigo == 429) {
    return 'Demasiados intentos. Espera un rato antes de volver a probar.';
  }
  if (codigo == null) return respaldo;
  return 'El servidor respondió con un error (HTTP $codigo).';
}

const _etiquetas = {
  'email': 'Correo',
  'password': 'Contraseña',
  'password_nueva': 'Contraseña nueva',
  'nombre': 'Nombre',
  'apellido': 'Apellido',
  'telefono': 'Teléfono',
  'codigo': 'Código',
};

String _etiqueta(String clave) => _etiquetas[clave] ?? clave;
