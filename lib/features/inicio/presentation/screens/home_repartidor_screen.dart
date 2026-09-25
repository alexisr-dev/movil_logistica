import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/map_style.dart';
import '../../../../shared/widgets/estados_vista.dart';
import '../../../../shared/widgets/mapa/piezas_mapa.dart';
import '../../../../shared/widgets/piezas_pedido.dart';
import '../../../entregas/presentation/entregas_provider.dart';
import '../../../pedidos/presentation/pedidos_provider.dart';
import '../../../perfil/presentation/perfil_provider.dart';
import '../../../rutas/presentation/rutas_provider.dart';
import '../widgets/campana_notificaciones.dart';

class HomeRepartidorScreen extends ConsumerWidget {
  const HomeRepartidorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilProvider);
    final entregas = ref.watch(entregasProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            refrescarEntregas(ref);
            ref.invalidate(perfilProvider);
            await ref.read(pedidosProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              MapStyle.esp4,
              MapStyle.esp2,
              MapStyle.esp4,
              MapStyle.esp6,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hola', style: MapStyle.secundario),
                        const SizedBox(height: 2),
                        if (perfil.isLoading && perfil.valueOrNull == null)
                          const Esqueleto(alto: 22, ancho: 150)
                        else
                          Text(
                            perfil.valueOrNull?.nombre ?? 'Repartidor',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MapStyle.titulo,
                          ),
                      ],
                    ),
                  ),
                  const CampanaNotificaciones(),
                ],
              ),
              const SizedBox(height: MapStyle.esp4),

              const _Disponibilidad(),
              const SizedBox(height: MapStyle.esp5),

              entregas.when(
                loading: () => const _CargandoResumen(),
                error: (e, _) => VistaError(
                  error: e,
                  onReintentar: () => refrescarEntregas(ref),
                ),
                data: (dia) => _Contenido(dia: dia),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Disponibilidad extends ConsumerWidget {
  const _Disponibilidad();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(disponibilidadProvider);
    final disponible = estado.valueOrNull ?? false;
    final color = disponible ? MapStyle.exito : MapStyle.neutro;

    return Container(
      padding: const EdgeInsets.all(MapStyle.esp4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.32)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              disponible ? Icons.wifi_tethering : Icons.wifi_tethering_off,
              size: 21,
              color: color,
            ),
          ),
          const SizedBox(width: MapStyle.esp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disponible ? 'Disponible' : 'No disponible',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MapStyle.textoFuerte,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  estado.hasError
                      ? 'No se pudo leer tu estado'
                      : (disponible
                          ? 'Puedes recibir nuevas entregas'
                          : 'No se te asignarán entregas'),
                  style: MapStyle.secundario,
                ),
              ],
            ),
          ),
          if (estado.isLoading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: disponible,
              onChanged: (valor) async {
                final error = await ref
                    .read(disponibilidadProvider.notifier)
                    .cambiar(valor);
                if (error != null && context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
                }
              },
            ),
        ],
      ),
    );
  }
}

class _CargandoResumen extends StatelessWidget {
  const _CargandoResumen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EtiquetaSeccion('Próxima entrega'),
        const SizedBox(height: MapStyle.esp3),
        Container(
          padding: const EdgeInsets.all(MapStyle.esp4),
          decoration: BoxDecoration(
            color: MapStyle.superficie,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MapStyle.borde),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Esqueleto(alto: 16, ancho: 140),
              SizedBox(height: MapStyle.esp3),
              Esqueleto(alto: 12),
              SizedBox(height: MapStyle.esp2),
              Esqueleto(alto: 12, ancho: 200),
            ],
          ),
        ),
      ],
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.dia});

  final EntregasDelDia dia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ruta = ref.watch(rutaActivaProvider).valueOrNull;

    if (dia.vacio) {
      return const Padding(
        padding: EdgeInsets.only(top: MapStyle.esp5),
        child: VistaVacia(
          icono: Icons.local_shipping_outlined,
          titulo: 'No tienes entregas asignadas',
          mensaje:
              'Cuando el operador te asigne pedidos o planifique tu ruta, '
              'aparecerán aquí.',
        ),
      );
    }

    final proxima = dia.proxima;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Resumen(
          pendientes: dia.totalPendientes,
          completadas: dia.completadas.length,
          distanciaKm: ruta?.distanciaKm,
          minutos: ruta?.tiempoEstimadoMin,
        ),
        const SizedBox(height: MapStyle.esp6),

        if (proxima != null) ...[
          const EtiquetaSeccion('Próxima entrega'),
          const SizedBox(height: MapStyle.esp3),
          TarjetaPedido(
            pedido: proxima.pedido,
            ordenParada: proxima.orden,
            horaEstimada: proxima.horaEstimada,
            destacada: true,
            onTap: () => context.push('/entregas/${proxima.pedido.id}'),
            accion: FilledButton.icon(
              onPressed: () => context.push('/entregas/${proxima.pedido.id}'),
              icon: const Icon(Icons.navigation, size: 20),
              label: const Text('Ver entrega'),
            ),
          ),
          const SizedBox(height: MapStyle.esp4),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(MapStyle.esp4),
            decoration: BoxDecoration(
              color: MapStyle.exito.withOpacity(0.09),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MapStyle.exito.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: MapStyle.exito, size: 26),
                SizedBox(width: MapStyle.esp3),
                Expanded(
                  child: Text(
                    'Todas tus entregas están resueltas. ¡Buen trabajo!',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: MapStyle.textoFuerte,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MapStyle.esp4),
        ],

        OutlinedButton.icon(
          onPressed: () => context.go('/recorrido'),
          icon: const Icon(Icons.map_outlined, size: 20),
          label: const Text('Ver mi recorrido'),
        ),
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.pendientes,
    required this.completadas,
    this.distanciaKm,
    this.minutos,
  });

  final int pendientes;
  final int completadas;
  final double? distanciaKm;
  final int? minutos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EtiquetaSeccion('Resumen de hoy'),
        const SizedBox(height: MapStyle.esp3),
        Row(
          children: [
            Expanded(
              child: _Metrica(
                valor: pendientes.toString(),
                etiqueta: pendientes == 1 ? 'Pendiente' : 'Pendientes',
                icono: Icons.pending_actions,
                color: MapStyle.aviso,
              ),
            ),
            const SizedBox(width: MapStyle.esp3),
            Expanded(
              child: _Metrica(
                valor: completadas.toString(),
                etiqueta: 'Completadas',
                icono: Icons.check_circle_outline,
                color: MapStyle.exito,
              ),
            ),
          ],
        ),
        if (distanciaKm != null || minutos != null) ...[
          const SizedBox(height: MapStyle.esp3),
          Wrap(
            spacing: MapStyle.esp2,
            runSpacing: MapStyle.esp2,
            children: [
              if (distanciaKm != null)
                PildoraMetrica(
                  icono: Icons.straighten,
                  texto: '${distanciaKm!.toStringAsFixed(1)} km de ruta',
                ),
              if (minutos != null)
                PildoraMetrica(
                  icono: Icons.schedule,
                  texto: '$minutos min estimados',
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({
    required this.valor,
    required this.etiqueta,
    required this.icono,
    required this.color,
  });

  final String valor;
  final String etiqueta;
  final IconData icono;
  final Color color;

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
              fontSize: 26,
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
