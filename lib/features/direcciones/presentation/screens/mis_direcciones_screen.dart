import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/errores_api.dart';
import '../../../../core/theme/map_style.dart';
import '../../../../shared/models/direccion.dart';
import '../../../../shared/widgets/estados_vista.dart';
import '../../../../shared/widgets/mapa/piezas_mapa.dart';
import '../direcciones_provider.dart';
import 'editar_direccion_screen.dart';

class MisDireccionesScreen extends ConsumerWidget {
  const MisDireccionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direcciones = ref.watch(direccionesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis direcciones')),
      floatingActionButton: direcciones.valueOrNull?.isEmpty ?? true
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _abrirEditor(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            ),
      body: direcciones.when(
        loading: () => const ListaEsqueleto(),
        error: (e, _) => VistaError(
          error: e,
          onReintentar: () => ref.invalidate(direccionesProvider),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return VistaVacia(
              icono: Icons.location_off_outlined,
              titulo: 'Aún no tienes direcciones',
              mensaje: 'Agrega una dirección para poder crear tu primer pedido.',
              accion: FilledButton.icon(
                onPressed: () => _abrirEditor(context, ref),
                icon: const Icon(Icons.add_location_alt_outlined, size: 20),
                label: const Text('Agregar dirección'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(240, MapStyle.tap),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(direccionesProvider);
              await ref.read(direccionesProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                MapStyle.esp4,
                MapStyle.esp4,
                MapStyle.esp4,
                96, // hueco para que el FAB no tape la última tarjeta
              ),
              itemCount: lista.length,
              separatorBuilder: (_, __) => const SizedBox(height: MapStyle.esp3),
              itemBuilder: (_, i) => _TarjetaDireccion(
                direccion: lista[i],
                todas: lista,
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<Direccion?> _abrirEditor(
  BuildContext context,
  WidgetRef ref, {
  Direccion? direccion,
}) {
  return Navigator.of(context).push<Direccion>(
    MaterialPageRoute(
      builder: (_) => EditarDireccionScreen(direccion: direccion),
    ),
  );
}

class _TarjetaDireccion extends ConsumerStatefulWidget {
  const _TarjetaDireccion({required this.direccion, required this.todas});

  final Direccion direccion;
  final List<Direccion> todas;

  @override
  ConsumerState<_TarjetaDireccion> createState() => _TarjetaDireccionState();
}

class _TarjetaDireccionState extends ConsumerState<_TarjetaDireccion> {
  bool _trabajando = false;

  Future<void> _hacerPredeterminada() async {
    setState(() => _trabajando = true);
    try {
      await ref.read(direccionesRepositoryProvider).marcarPredeterminada(
            widget.direccion.id,
            widget.todas,
          );
      ref.invalidate(direccionesProvider);
    } catch (e) {
      if (!mounted) return;
      _avisar(mensajeDeError(e, respaldo: 'No se pudo cambiar la predeterminada.'));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Eliminar dirección?'),
        content: Text('Se quitará "${widget.direccion.titulo}" de tu lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            style: FilledButton.styleFrom(backgroundColor: MapStyle.peligro),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _trabajando = true);
    try {
      await ref.read(direccionesRepositoryProvider).eliminar(widget.direccion.id);
      ref.invalidate(direccionesProvider);
      if (mounted) _avisar('Dirección eliminada.');
    } catch (e) {
      if (!mounted) return;
      // `DireccionEnUso` trae su propio mensaje explicando cuántos pedidos la
      // usan: es un caso normal, no un fallo.
      _avisar(mensajeDeError(e, respaldo: 'No se pudo eliminar la dirección.'));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.direccion;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MapStyle.esp4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: MapStyle.primario.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.place_outlined,
                      size: 20, color: MapStyle.primario),
                ),
                const SizedBox(width: MapStyle.esp3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              d.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: MapStyle.textoFuerte,
                              ),
                            ),
                          ),
                          if (d.esDefault) ...[
                            const SizedBox(width: MapStyle.esp2),
                            const ChipEstado(
                              texto: 'Predeterminada',
                              color: MapStyle.exito,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(d.lineaCompleta, style: MapStyle.secundario),
                      if (d.tieneReferencia) ...[
                        const SizedBox(height: 2),
                        Text(
                          d.referencia!,
                          style: MapStyle.secundario.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MapStyle.esp3),
            const Divider(height: 1),
            const SizedBox(height: MapStyle.esp2 - 4),

            // Acciones en fila, con la destructiva separada a la derecha.
            Row(
              children: [
                if (!d.esDefault)
                  TextButton.icon(
                    onPressed: _trabajando ? null : _hacerPredeterminada,
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: const Text('Predeterminada'),
                  ),
                const Spacer(),
                IconButton(
                  onPressed: _trabajando
                      ? null
                      : () => _abrirEditor(context, ref, direccion: d),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Editar',
                ),
                IconButton(
                  onPressed: _trabajando ? null : _eliminar,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: MapStyle.peligro,
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
