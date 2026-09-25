import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/map_style.dart';
import '../../../../shared/models/rendimiento.dart';
import '../../../../shared/widgets/estados_vista.dart';
import '../../../../shared/widgets/mapa/piezas_mapa.dart';
import '../reportes_provider.dart';

class ReportesRepartidorScreen extends ConsumerWidget {
  const ReportesRepartidorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rendimiento = ref.watch(rendimientoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi rendimiento')),
      body: rendimiento.when(
        loading: () => const ListaEsqueleto(filas: 3),
        error: (e, _) => VistaError(
          error: e,
          onReintentar: () => ref.invalidate(rendimientoProvider),
        ),
        data: (datos) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(rendimientoProvider);
            await ref.read(rendimientoProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(MapStyle.esp4),
            children: [
              _Cabecera(datos: datos),
              const SizedBox(height: MapStyle.esp5),

              if (datos.sinDatos)
                const VistaVacia(
                  icono: Icons.insights_outlined,
                  titulo: 'Aún no hay indicadores',
                  mensaje:
                      'Los números aparecen cuando marcas tu primera entrega '
                      'como completada.',
                )
              else ...[
                _Puntualidad(datos: datos),
                const SizedBox(height: MapStyle.esp4),
                Row(
                  children: [
                    Expanded(
                      child: _Tarjeta(
                        icono: Icons.check_circle_outline,
                        color: MapStyle.exito,
                        valor: datos.entregasATiempo.toString(),
                        etiqueta: 'A tiempo',
                      ),
                    ),
                    const SizedBox(width: MapStyle.esp3),
                    Expanded(
                      child: _Tarjeta(
                        icono: Icons.running_with_errors_outlined,
                        color: MapStyle.aviso,
                        valor: datos.entregasTardias.toString(),
                        etiqueta: 'Tardías',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MapStyle.esp3),
                Row(
                  children: [
                    Expanded(
                      child: _Tarjeta(
                        icono: Icons.timer_outlined,
                        color: MapStyle.primario,
                        valor: datos.tiempoPromedioMin == null
                            ? '—'
                            : datos.tiempoPromedioMin!.toStringAsFixed(0),
                        etiqueta: 'Min. promedio',
                      ),
                    ),
                    const SizedBox(width: MapStyle.esp3),
                    Expanded(
                      child: _Tarjeta(
                        icono: Icons.star_rounded,
                        color: const Color(0xFFF59E0B),
                        valor: datos.calificacionPromedio == null ||
                                datos.calificacionPromedio == 0
                            ? '—'
                            : datos.calificacionPromedio!.toStringAsFixed(1),
                        etiqueta: 'Calificación',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: MapStyle.esp5),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.datos});

  final Rendimiento datos;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MapStyle.esp5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MapStyle.primario, Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            datos.repartidor.isEmpty ? 'Mi rendimiento' : datos.repartidor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: MapStyle.esp3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                datos.totalEntregas.toString(),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: MapStyle.esp2),
              Text(
                datos.totalEntregas == 1
                    ? 'entrega completada'
                    : 'entregas completadas',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Puntualidad extends StatelessWidget {
  const _Puntualidad({required this.datos});

  final Rendimiento datos;

  @override
  Widget build(BuildContext context) {
    final proporcion = datos.proporcionATiempo;

    return Container(
      padding: const EdgeInsets.all(MapStyle.esp4),
      decoration: BoxDecoration(
        color: MapStyle.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MapStyle.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: EtiquetaSeccion('Puntualidad')),
              Text(
                proporcion == null
                    ? 'Sin plazos que comparar'
                    : '${(proporcion * 100).toStringAsFixed(0)} %',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MapStyle.textoFuerte,
                ),
              ),
            ],
          ),
          const SizedBox(height: MapStyle.esp3),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: proporcion ?? 0,
              minHeight: 10,
              backgroundColor: MapStyle.borde,
              valueColor: AlwaysStoppedAnimation(
                proporcion == null
                    ? MapStyle.neutro
                    : (proporcion >= 0.8 ? MapStyle.exito : MapStyle.aviso),
              ),
            ),
          ),
          const SizedBox(height: MapStyle.esp2),
          Text(
            proporcion == null
                ? 'Ninguna de tus entregas tenía fecha estimada.'
                : '${datos.entregasATiempo} de '
                    '${datos.entregasATiempo + datos.entregasTardias} entregas '
                    'llegaron dentro del plazo.',
            style: MapStyle.secundario,
          ),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icono,
    required this.color,
    required this.valor,
    required this.etiqueta,
  });

  final IconData icono;
  final Color color;
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MapStyle.esp4),
      decoration: BoxDecoration(
        color: MapStyle.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MapStyle.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(height: MapStyle.esp3),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1,
              color: MapStyle.textoFuerte,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MapStyle.secundario,
          ),
        ],
      ),
    );
  }
}
