import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/estados.dart';
import '../../../../core/theme/map_style.dart';
import '../../../../shared/models/pedido.dart';
import '../../../../shared/widgets/estados_vista.dart';
import '../../../../shared/widgets/mapa/piezas_mapa.dart';
import '../../../../shared/widgets/piezas_pedido.dart';
import '../../../notificaciones/presentation/notificaciones_provider.dart';
import '../../../pedidos/presentation/pedidos_provider.dart';
import '../../../perfil/presentation/perfil_provider.dart';
import '../widgets/campana_notificaciones.dart';

class HomeClienteScreen extends ConsumerStatefulWidget {
  const HomeClienteScreen({super.key});

  @override
  ConsumerState<HomeClienteScreen> createState() => _HomeClienteScreenState();
}

class _HomeClienteScreenState extends ConsumerState<HomeClienteScreen> {
  final _codigo = TextEditingController();
  bool _buscando = false;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _rastrear() async {
    final codigo = _codigo.text.trim();
    if (codigo.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _buscando = true);
    try {
      final encontrados =
          await ref.read(pedidosRepositoryProvider).buscar(codigo);
      if (!mounted) return;

      if (encontrados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No encontramos ningún pedido con el código $codigo.')),
        );
        return;
      }
      _codigo.clear();
      context.push('/pedidos/${encontrados.first.id}');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo buscar. Revisa tu conexión.')),
      );
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilProvider);
    final clasificados = ref.watch(pedidosClasificadosProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pedidosProvider);
            ref.invalidate(notificacionesProvider);
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
              _Encabezado(
                saludo: perfil.valueOrNull?.nombre,
                cargando: perfil.isLoading,
              ),
              const SizedBox(height: MapStyle.esp5),

              _BuscadorPedido(
                controlador: _codigo,
                buscando: _buscando,
                onBuscar: _rastrear,
              ),
              const SizedBox(height: MapStyle.esp5),

              _AccesosRapidos(
                onCrear: () => context.push('/pedidos/nuevo'),
                onVerPedidos: () => context.go('/pedidos'),
              ),
              const SizedBox(height: MapStyle.esp6),

              clasificados.when(
                loading: () => const _CargandoActivo(),
                error: (e, _) => VistaError(
                  error: e,
                  onReintentar: () => ref.invalidate(pedidosProvider),
                ),
                data: (datos) => _Contenido(datos: datos),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({this.saludo, this.cargando = false});

  final String? saludo;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hola', style: MapStyle.secundario),
              const SizedBox(height: 2),
              if (cargando && saludo == null)
                const Esqueleto(alto: 22, ancho: 160)
              else
                Text(
                  saludo == null ? 'Bienvenido' : '$saludo 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MapStyle.titulo,
                ),
            ],
          ),
        ),
        const CampanaNotificaciones(),
      ],
    );
  }
}

class _BuscadorPedido extends StatelessWidget {
  const _BuscadorPedido({
    required this.controlador,
    required this.buscando,
    required this.onBuscar,
  });

  final TextEditingController controlador;
  final bool buscando;
  final VoidCallback onBuscar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MapStyle.esp4),
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
          const Text(
            '¿Dónde está tu pedido?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: MapStyle.esp3),
          TextField(
            controller: controlador,
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => onBuscar(),
            decoration: const InputDecoration(
              hintText: 'Código de seguimiento',
              prefixIcon: Icon(Icons.qr_code_2, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: MapStyle.esp3),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: buscando ? null : onBuscar,
              icon: buscando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: MapStyle.primario),
                    )
                  : const Icon(Icons.search, size: 20),
              label: Text(buscando ? 'Buscando…' : 'Rastrear pedido'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: MapStyle.primario,
                disabledBackgroundColor: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccesosRapidos extends StatelessWidget {
  const _AccesosRapidos({required this.onCrear, required this.onVerPedidos});

  final VoidCallback onCrear;
  final VoidCallback onVerPedidos;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Acceso(
            icono: Icons.add_box_outlined,
            titulo: 'Crear pedido',
            subtitulo: 'Enviar algo',
            color: MapStyle.primario,
            onTap: onCrear,
          ),
        ),
        const SizedBox(width: MapStyle.esp3),
        Expanded(
          child: _Acceso(
            icono: Icons.inventory_2_outlined,
            titulo: 'Mis pedidos',
            subtitulo: 'Ver todos',
            color: const Color(0xFF8B5CF6),
            onTap: onVerPedidos,
          ),
        ),
      ],
    );
  }
}

class _Acceso extends StatelessWidget {
  const _Acceso({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MapStyle.esp4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: color, size: 21),
              ),
              const SizedBox(height: MapStyle.esp3),
              Text(
                titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MapStyle.textoFuerte,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MapStyle.secundario,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CargandoActivo extends StatelessWidget {
  const _CargandoActivo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EtiquetaSeccion('Pedido en curso'),
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
              Esqueleto(alto: 16, ancho: 130),
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

class _Contenido extends StatelessWidget {
  const _Contenido({required this.datos});

  final PedidosClasificados datos;

  @override
  Widget build(BuildContext context) {
    final activo = datos.activo;

    if (datos.vacio) {
      return Padding(
        padding: const EdgeInsets.only(top: MapStyle.esp5),
        child: VistaVacia(
          icono: Icons.inbox_outlined,
          titulo: 'Todavía no tienes pedidos',
          mensaje:
              'Cuando crees tu primer envío aparecerá aquí, con su seguimiento '
              'en tiempo real.',
          accion: FilledButton.icon(
            onPressed: () => context.push('/pedidos/nuevo'),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Crear mi primer pedido'),
            style: FilledButton.styleFrom(minimumSize: const Size(240, MapStyle.tap)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activo != null) ...[
          const EtiquetaSeccion('Pedido en curso'),
          const SizedBox(height: MapStyle.esp3),
          _TarjetaActivo(pedido: activo),
          const SizedBox(height: MapStyle.esp6),
        ],

        Row(
          children: [
            const Expanded(child: EtiquetaSeccion('Actividad reciente')),
            TextButton(
              onPressed: () => context.go('/pedidos'),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: MapStyle.esp2),

        ..._recientes(activo).map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: MapStyle.esp3),
            child: TarjetaPedido(
              pedido: p,
              onTap: () => context.push('/pedidos/${p.id}'),
            ),
          ),
        ),
      ],
    );
  }

  List<Pedido> _recientes(Pedido? activo) {
    final todos = [...datos.enCurso, ...datos.completados, ...datos.cancelados]
      ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    return todos.where((p) => p.id != activo?.id).take(3).toList();
  }
}

class _TarjetaActivo extends StatelessWidget {
  const _TarjetaActivo({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final aspecto = aspectoDePedido(pedido.estado.codigo);
    final destino = pedido.direccionDestino;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: aspecto.color.withOpacity(0.45), width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/pedidos/${pedido.id}'),
        child: Padding(
          padding: const EdgeInsets.all(MapStyle.esp4 + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pedido.codigoSeguimiento,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MapStyle.titulo,
                    ),
                  ),
                  const SizedBox(width: MapStyle.esp2),
                  EstadoPedidoChip(
                    pedido.estado.codigo,
                    nombre: pedido.estado.nombre,
                  ),
                ],
              ),

              if (destino != null) ...[
                const SizedBox(height: MapStyle.esp3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 17, color: MapStyle.neutro),
                    const SizedBox(width: MapStyle.esp2),
                    Expanded(
                      child: Text(
                        destino.lineaCompleta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MapStyle.direccion,
                      ),
                    ),
                  ],
                ),
              ],

              if (pedido.fechaEstimadaEntrega != null) ...[
                const SizedBox(height: MapStyle.esp3),
                PildoraMetrica(
                  icono: Icons.event_outlined,
                  texto: 'Estimada ${fechaCorta(pedido.fechaEstimadaEntrega!)}',
                ),
              ],

              const SizedBox(height: MapStyle.esp4),
              // El mapa siempre lleva a algún sitio: en camino enseña al
              // repartidor moviéndose, y antes el recorrido que va a hacer.
              if (pedido.estaEnCamino)
                FilledButton.icon(
                  onPressed: () => context.push('/tracking/${pedido.id}'),
                  icon: const Icon(Icons.map_outlined, size: 20),
                  label: const Text('Ver seguimiento en vivo'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => context.push('/tracking/${pedido.id}'),
                  icon: const Icon(Icons.map_outlined, size: 19),
                  label: const Text('Ver recorrido'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
