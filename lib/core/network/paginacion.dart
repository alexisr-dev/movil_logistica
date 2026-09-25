List<Map<String, dynamic>> resultadosDe(dynamic datos) {
  if (datos is List) {
    return datos.whereType<Map<String, dynamic>>().toList();
  }
  if (datos is Map && datos['results'] is List) {
    return (datos['results'] as List).whereType<Map<String, dynamic>>().toList();
  }
  return const [];
}

int totalDe(dynamic datos, {int? porDefecto}) {
  if (datos is Map && datos['count'] is int) return datos['count'] as int;
  return porDefecto ?? resultadosDe(datos).length;
}
