class Rendimiento {
  const Rendimiento({
    required this.repartidor,
    required this.totalEntregas,
    required this.entregasATiempo,
    required this.entregasTardias,
    this.tiempoPromedioMin,
    this.calificacionPromedio,
  });

  final String repartidor;
  final int totalEntregas;
  final int entregasATiempo;
  final int entregasTardias;
  final double? tiempoPromedioMin;
  final double? calificacionPromedio;

  bool get sinDatos => totalEntregas == 0;

  double? get proporcionATiempo {
    final medidas = entregasATiempo + entregasTardias;
    return medidas == 0 ? null : entregasATiempo / medidas;
  }

  factory Rendimiento.fromJson(Map<String, dynamic> json) {
    double? numero(String clave) => json[clave] == null
        ? null
        : double.tryParse(json[clave].toString());

    return Rendimiento(
      repartidor: json['repartidor'] as String? ?? '',
      totalEntregas: json['total_entregas'] as int? ?? 0,
      entregasATiempo: json['entregas_a_tiempo'] as int? ?? 0,
      entregasTardias: json['entregas_tardias'] as int? ?? 0,
      tiempoPromedioMin: numero('tiempo_promedio_min'),
      calificacionPromedio: numero('calificacion_promedio'),
    );
  }
}
