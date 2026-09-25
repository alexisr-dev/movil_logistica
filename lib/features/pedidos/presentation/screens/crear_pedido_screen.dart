import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/errores_api.dart';
import '../../../../core/theme/map_style.dart';
import '../../../../shared/models/direccion.dart';
import '../../../../shared/widgets/estados_vista.dart';
import '../../../../shared/widgets/mapa/hoja_mapa.dart';
import '../../../../shared/widgets/mapa/piezas_mapa.dart';
import '../../../direcciones/presentation/direcciones_provider.dart';
import '../../../direcciones/presentation/screens/editar_direccion_screen.dart';
import '../pedidos_provider.dart';

class CrearPedidoScreen extends ConsumerStatefulWidget {
  const CrearPedidoScreen({super.key});

  @override
  ConsumerState<CrearPedidoScreen> createState() => _CrearPedidoScreenState();
}

class _CrearPedidoScreenState extends ConsumerState<CrearPedidoScreen> {
  static const _titulos = [
    '¿Dónde recogemos tu pedido?',
    '¿Dónde quieres enviarlo?',
    'Información del envío',
    'Resumen del envío',
  ];

  final _paginas = PageController();
  final _descripcion = TextEditingController();
  final _peso = TextEditingController();

  int _paso = 0;
  Direccion? _origen;
  Direccion? _destino;
  bool _creando = false;
  String? _error;

  @override
  void dispose() {
    _paginas.dispose();
    _descripcion.dispose();
    _peso.dispose();
    super.dispose();
  }

  bool get _puedeAvanzar {
    switch (_paso) {
      case 0:
        return _origen != null;
      case 1:
        // Mandar el mismo punto como origen y destino crea un pedido que no va
        // a ninguna parte; OSRM además devolvería una ruta de longitud cero.
        return _destino != null && _destino!.id != _origen?.id;
      default:
        return true;
    }
  }

  void _irA(int paso) {
    setState(() => _paso = paso);
    _paginas.animateToPage(
      paso,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _siguiente() {
    FocusScope.of(context).unfocus();
    if (_paso < _titulos.length - 1) _irA(_paso + 1);
  }

  bool _atras() {
    if (_paso == 0) return true;
    _irA(_paso - 1);
    return false;
  }

  Future<void> _crear() async {
    if (_origen == null || _destino == null) return;

    setState(() {
      _creando = true;
      _error = null;
    });

    try {
      final pedido = await ref.read(pedidosRepositoryProvider).crear(
            direccionOrigenId: _origen!.id,
            direccionDestinoId: _destino!.id,
            descripcion: _descripcion.text,
            pesoKg: double.tryParse(_peso.text.trim().replaceAll(',', '.')),
          );

      // El pedido nuevo tiene que aparecer en «En curso» al volver.
      ref.invalidate(pedidosProvider);

      if (!mounted) return;
      // `pushReplacement` del router, no del `Navigator`: estas paginas las
      // gestiona `go_router` por lista, y reemplazarlas a mano dispara
      // «A page-based route cannot be completed using imperative api».
      // Tras crear el pedido no tiene sentido volver al formulario.
      context.pushReplacement('/pedidos/creado', extra: pedido);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creando = false;
        _error = mensajeDeError(e, respaldo: 'No se pudo crear el pedido.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // El botón atrás del sistema retrocede de paso antes de cerrar el flujo.
      canPop: _paso == 0,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _atras();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Crear pedido'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // `_atras` solo es async por simetría con `onPopInvoked`; aquí no
              // hay await, así que no hay hueco asíncrono que cruzar.
              if (_paso == 0) {
                Navigator.of(context).pop();
              } else {
                _irA(_paso - 1);
              }
            },
          ),
        ),
        body: Column(
          children: [
            _Progreso(paso: _paso, total: _titulos.length),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MapStyle.esp4,
                MapStyle.esp4,
                MapStyle.esp4,
                MapStyle.esp2,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_titulos[_paso], style: MapStyle.titulo),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _paginas,
                // Solo se navega con los botones: deslizar se saltaría las
                // validaciones de cada paso.
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _PasoDireccion(
                    seleccionada: _origen,
                    onSeleccionar: (d) => setState(() => _origen = d),
                    ayuda: 'Elige de dónde sale el paquete.',
                  ),
                  _PasoDireccion(
                    seleccionada: _destino,
                    onSeleccionar: (d) => setState(() => _destino = d),
                    ayuda: 'Elige a dónde tiene que llegar.',
                    excluir: _origen,
                  ),
                  _PasoEnvio(descripcion: _descripcion, peso: _peso),
                  _PasoResumen(
                    origen: _origen,
                    destino: _destino,
                    descripcion: _descripcion,
                    peso: _peso,
                    error: _error,
                  ),
                ],
              ),
            ),
            _BarraInferior(
              ultimo: _paso == _titulos.length - 1,
              habilitado: _puedeAvanzar && !_creando,
              creando: _creando,
              onSiguiente: _siguiente,
              onCrear: _crear,
            ),
          ],
        ),
      ),
    );
  }
}

class _Progreso extends StatelessWidget {
  const _Progreso({required this.paso, required this.total});

  final int paso;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MapStyle.esp4,
        vertical: MapStyle.esp3,
      ),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: 5,
                decoration: BoxDecoration(
                  color: i <= paso ? MapStyle.primario : MapStyle.borde,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
          const SizedBox(width: MapStyle.esp3),
          Text(
            '${paso + 1}/$total',
            style: MapStyle.etiqueta,
          ),
        ],
      ),
    );
  }
}

class _PasoDireccion extends ConsumerWidget {
  const _PasoDireccion({
    required this.seleccionada,
    required this.onSeleccionar,
    required this.ayuda,
    this.excluir,
  });

  final Direccion? seleccionada;
  final ValueChanged<Direccion> onSeleccionar;
  final String ayuda;

  final Direccion? excluir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direcciones = ref.watch(direccionesProvider);

    return direcciones.when(
      loading: () => const ListaEsqueleto(),
      error: (e, _) => VistaError(
        error: e,
        onReintentar: () => ref.invalidate(direccionesProvider),
      ),
      data: (todas) {
        final disponibles =
            todas.where((d) => d.id != excluir?.id).toList(growable: false);

        if (disponibles.isEmpty) {
          return VistaVacia(
            icono: Icons.location_off_outlined,
            titulo: todas.isEmpty
                ? 'Aún no tienes direcciones'
                : 'No tienes otra dirección',
            mensaje: todas.isEmpty
                ? 'Agrega una dirección para crear tu primer pedido.'
                : 'El origen y el destino deben ser distintos. Agrega otra dirección para continuar.',
            accion: FilledButton.icon(
              onPressed: () => _nueva(context, ref),
              icon: const Icon(Icons.add_location_alt_outlined, size: 20),
              label: const Text('Agregar dirección'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(240, MapStyle.tap),
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            MapStyle.esp4,
            0,
            MapStyle.esp4,
            MapStyle.esp4,
          ),
          children: [
            Text(ayuda, style: MapStyle.direccion),
            const SizedBox(height: MapStyle.esp4),
            ...disponibles.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: MapStyle.esp3),
                child: _OpcionDireccion(
                  direccion: d,
                  elegida: d.id == seleccionada?.id,
                  onTap: () => onSeleccionar(d),
                ),
              ),
            ),
            const SizedBox(height: MapStyle.esp2),
            OutlinedButton.icon(
              onPressed: () => _nueva(context, ref),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Agregar nueva dirección'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _nueva(BuildContext context, WidgetRef ref) async {
    final creada = await Navigator.of(context).push<Direccion>(
      MaterialPageRoute(builder: (_) => const EditarDireccionScreen()),
    );
    if (creada != null) onSeleccionar(creada);
  }
}

class _OpcionDireccion extends StatelessWidget {
  const _OpcionDireccion({
    required this.direccion,
    required this.elegida,
    required this.onTap,
  });

  final Direccion direccion;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: elegida ? MapStyle.primario : MapStyle.borde,
          width: elegida ? 1.8 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MapStyle.esp4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                elegida
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 22,
                color: elegida ? MapStyle.primario : MapStyle.neutro,
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
                            direccion.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: MapStyle.textoFuerte,
                            ),
                          ),
                        ),
                        if (direccion.esDefault) ...[
                          const SizedBox(width: MapStyle.esp2),
                          const ChipEstado(
                            texto: 'Predeterminada',
                            color: MapStyle.exito,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(direccion.lineaCompleta, style: MapStyle.secundario),
                    if (direccion.tieneReferencia) ...[
                      const SizedBox(height: 2),
                      Text(direccion.referencia!, style: MapStyle.secundario),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasoEnvio extends StatelessWidget {
  const _PasoEnvio({required this.descripcion, required this.peso});

  final TextEditingController descripcion;
  final TextEditingController peso;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MapStyle.esp4,
        0,
        MapStyle.esp4,
        MapStyle.esp4,
      ),
      children: [
        const Text(
          'Cuéntanos qué estás enviando. Los dos campos son opcionales.',
          style: MapStyle.direccion,
        ),
        const SizedBox(height: MapStyle.esp5),
        TextField(
          controller: descripcion,
          maxLines: 3,
          // 255 es el largo real de `Pedido.descripcion`; cortarlo aquí evita
          // un 400 después de rellenar todo el flujo.
          maxLength: 255,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Descripción',
            hintText: 'Documentos, ropa, accesorios…',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: MapStyle.esp3),
        TextField(
          controller: peso,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            // `peso_kg` es un DECIMAL(6,2): hasta 4 enteros y 2 decimales.
            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}([.,]\d{0,2})?')),
          ],
          decoration: const InputDecoration(
            labelText: 'Peso aproximado',
            hintText: '2.5',
            suffixText: 'kg',
            prefixIcon: Icon(Icons.scale_outlined, size: 20),
          ),
        ),
      ],
    );
  }
}

class _PasoResumen extends StatelessWidget {
  const _PasoResumen({
    required this.origen,
    required this.destino,
    required this.descripcion,
    required this.peso,
    this.error,
  });

  final Direccion? origen;
  final Direccion? destino;
  final TextEditingController descripcion;
  final TextEditingController peso;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final texto = descripcion.text.trim();
    final kilos = peso.text.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MapStyle.esp4,
        0,
        MapStyle.esp4,
        MapStyle.esp4,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(MapStyle.esp4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FilaResumen(
                  icono: Icons.trip_origin,
                  etiqueta: 'Origen',
                  titulo: origen?.titulo ?? '—',
                  detalle: origen?.lineaCompleta ?? '',
                  referencia: origen?.referencia,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: MapStyle.esp2),
                  child: Icon(Icons.arrow_downward,
                      size: 18, color: MapStyle.neutro),
                ),
                _FilaResumen(
                  icono: Icons.place,
                  etiqueta: 'Destino',
                  titulo: destino?.titulo ?? '—',
                  detalle: destino?.lineaCompleta ?? '',
                  referencia: destino?.referencia,
                  color: MapStyle.primario,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: MapStyle.esp4),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(MapStyle.esp4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EtiquetaSeccion('Contenido'),
                const SizedBox(height: MapStyle.esp2),
                Text(
                  texto.isEmpty ? 'Sin descripción' : texto,
                  style: MapStyle.direccion,
                ),
                if (kilos.isNotEmpty) ...[
                  const SizedBox(height: MapStyle.esp3),
                  PildoraMetrica(icono: Icons.scale_outlined, texto: '$kilos kg'),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: MapStyle.esp4),
        // El costo de envío no se muestra porque el backend no lo calcula:
        // `costo_envio` es un campo escribible y nulo, y nadie lo rellena al
        // crear desde la app. Enseñar "S/ 0.00" sería inventar un precio.
        Container(
          padding: const EdgeInsets.all(MapStyle.esp3),
          decoration: BoxDecoration(
            color: MapStyle.superficieTenue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 17, color: MapStyle.neutro),
              SizedBox(width: MapStyle.esp2),
              Expanded(
                child: Text(
                  'El costo del envío y la fecha estimada los confirma el '
                  'operador al revisar tu pedido.',
                  style: MapStyle.secundario,
                ),
              ),
            ],
          ),
        ),

        if (error != null) ...[
          const SizedBox(height: MapStyle.esp4),
          AvisoError(error!),
        ],
      ],
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({
    required this.icono,
    required this.etiqueta,
    required this.titulo,
    required this.detalle,
    this.referencia,
    this.color = MapStyle.neutro,
  });

  final IconData icono;
  final String etiqueta;
  final String titulo;
  final String detalle;

  final String? referencia;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 19, color: color),
        const SizedBox(width: MapStyle.esp3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta, style: MapStyle.etiqueta),
              const SizedBox(height: 2),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MapStyle.textoFuerte,
                ),
              ),
              if (detalle.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(detalle, style: MapStyle.secundario),
              ],
              if (referencia != null && referencia!.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 13, color: MapStyle.textoSuave),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(referencia!.trim(),
                          style: MapStyle.secundario),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BarraInferior extends StatelessWidget {
  const _BarraInferior({
    required this.ultimo,
    required this.habilitado,
    required this.creando,
    required this.onSiguiente,
    required this.onCrear,
  });

  final bool ultimo;
  final bool habilitado;
  final bool creando;
  final VoidCallback onSiguiente;
  final VoidCallback onCrear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MapStyle.superficie,
        border: Border(top: BorderSide(color: MapStyle.borde)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(MapStyle.esp4),
          child: FilledButton.icon(
            onPressed: habilitado ? (ultimo ? onCrear : onSiguiente) : null,
            icon: creando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(ultimo ? Icons.check : Icons.arrow_forward, size: 20),
            label: Text(
              creando
                  ? 'Creando…'
                  : (ultimo ? 'Crear pedido' : 'Continuar'),
            ),
          ),
        ),
      ),
    );
  }
}
