import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/geo/ubicacion_dispositivo.dart';
import '../../../../core/network/errores_api.dart';
import '../../../../core/theme/map_style.dart';
import '../../../../shared/models/direccion.dart';
import '../../../../shared/models/lugar.dart';
import '../../../../shared/widgets/buscador_direccion.dart';
import '../../../../shared/widgets/mapa/capas_base.dart';
import '../../../../shared/widgets/mapa/controles_mapa.dart';
import '../../../../shared/widgets/mapa/hoja_mapa.dart';
import '../../../../shared/widgets/mapa/piezas_mapa.dart';
import '../direcciones_provider.dart';
import '../geocoding_provider.dart';

class EditarDireccionScreen extends ConsumerStatefulWidget {
  const EditarDireccionScreen({super.key, this.direccion});

  final Direccion? direccion;

  @override
  ConsumerState<EditarDireccionScreen> createState() =>
      _EditarDireccionScreenState();
}

class _EditarDireccionScreenState extends ConsumerState<EditarDireccionScreen> {
  static const _porDefecto = LatLng(-12.0464, -77.0428);

  final _formulario = GlobalKey<FormState>();
  final _mapa = MapController();

  late final TextEditingController _alias;
  late final TextEditingController _calle;
  late final TextEditingController _numero;
  late final TextEditingController _distrito;
  late final TextEditingController _ciudad;
  late final TextEditingController _referencia;

  late LatLng _punto;
  late bool _esDefault;
  bool _guardando = false;
  String? _error;

  Timer? _esperaPin;
  CancelToken? _inversaEnCurso;
  Lugar? _lugarDelPin;
  bool _resolviendoPin = false;
  bool _pinConsultado = false;
  bool _buscandoGps = false;

  late bool _editadoAMano;

  bool get _esNueva => widget.direccion == null;

  @override
  void initState() {
    super.initState();
    final d = widget.direccion;
    _alias = TextEditingController(text: d?.alias ?? '');
    _calle = TextEditingController(text: d?.calle ?? '');
    _numero = TextEditingController(text: d?.numero ?? '');
    _distrito = TextEditingController(text: d?.distrito ?? '');
    _ciudad = TextEditingController(text: d?.ciudad ?? '');
    _referencia = TextEditingController(text: d?.referencia ?? '');
    _punto = d?.punto ?? _porDefecto;
    _esDefault = d?.esDefault ?? false;
    // Editando una dirección ya guardada, lo que hay escrito es la verdad:
    // vino del usuario y no se sobrescribe con lo que opine el geocodificador.
    _editadoAMano = d != null;
  }

  @override
  void dispose() {
    _esperaPin?.cancel();
    _inversaEnCurso?.cancel();
    for (final c in [_alias, _calle, _numero, _distrito, _ciudad, _referencia]) {
      c.dispose();
    }
    _mapa.dispose();
    super.dispose();
  }

  void _aplicarLugar(Lugar lugar, {bool moverMapa = true}) {
    _calle.text = lugar.calle ?? lugar.etiqueta;
    _numero.text = lugar.numero ?? '';
    _distrito.text = lugar.distrito ?? '';
    _ciudad.text = lugar.ciudad ?? '';

    setState(() {
      _punto = lugar.punto;
      _lugarDelPin = lugar;
      _resolviendoPin = false;
      _pinConsultado = true;
    });

    if (moverMapa) {
      // 17 es el nivel al que se distingue el portal de la manzana.
      _mapa.move(lugar.punto, 17);
    }
  }

  Future<void> _irAMiUbicacion() async {
    if (_buscandoGps) return;
    setState(() => _buscandoGps = true);

    try {
      final punto = await const UbicacionPuntual().punto();
      if (!mounted) return;

      // 17 es el nivel al que se distingue el portal de la manzana.
      _mapa.move(punto, 17);
      _punto = punto;

      // El `move` de arriba dispara `onPositionChanged`, que programaría la
      // consulta para dentro de 900 ms. Aquí no hace falta esperar: el usuario
      // acaba de pedir esto expresamente.
      _esperaPin?.cancel();
      _inversaEnCurso?.cancel();
      setState(() => _buscandoGps = false);
      await _resolverPin(punto);
    } on UbicacionException catch (e) {
      if (!mounted) return;
      setState(() => _buscandoGps = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _buscandoGps = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener tu ubicación. Coloca el pin a mano.'),
        ),
      );
    }
  }

  void _alMoverPin(LatLng punto) {
    _punto = punto;
    _esperaPin?.cancel();
    _inversaEnCurso?.cancel();
    _esperaPin =
        Timer(const Duration(milliseconds: 900), () => _resolverPin(punto));
  }

  Future<void> _resolverPin(LatLng punto) async {
    if (!mounted) return;
    setState(() {
      _resolviendoPin = true;
      _pinConsultado = true;
    });

    final cancelar = CancelToken();
    _inversaEnCurso = cancelar;
    final lugar =
        await ref.read(geocodingRepositoryProvider).direccionDe(punto,
            cancelar: cancelar);

    if (!mounted || cancelar.isCancelled) return;
    setState(() {
      _lugarDelPin = lugar;
      _resolviendoPin = false;
    });

    // Mientras nadie haya escrito nada, el pin manda y los campos le siguen.
    if (lugar != null && !_editadoAMano) {
      _aplicarLugar(lugar, moverMapa: false);
    }
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    String? limpio(TextEditingController c) {
      final texto = c.text.trim();
      return texto.isEmpty ? null : texto;
    }

    final direccion = Direccion(
      id: widget.direccion?.id ?? 0,
      calle: _calle.text.trim(),
      latitud: _punto.latitude,
      longitud: _punto.longitude,
      alias: limpio(_alias),
      numero: limpio(_numero),
      distrito: limpio(_distrito),
      ciudad: limpio(_ciudad),
      referencia: limpio(_referencia),
      esDefault: _esDefault,
    );

    try {
      final repo = ref.read(direccionesRepositoryProvider);
      final guardada = _esNueva
          ? await repo.crear(direccion)
          : await repo.actualizar(widget.direccion!.id, direccion);

      ref.invalidate(direccionesProvider);
      if (mounted) Navigator.of(context).pop(guardada);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = mensajeDeError(e, respaldo: 'No se pudo guardar la dirección.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esNueva ? 'Nueva dirección' : 'Editar dirección'),
      ),
      body: Form(
        key: _formulario,
        child: ListView(
          padding: const EdgeInsets.all(MapStyle.esp4),
          children: [
            const EtiquetaSeccion('Ubicación en el mapa'),
            const SizedBox(height: MapStyle.esp2),
            const Text(
              'Busca la calle por su nombre, o mueve el mapa para colocar el pin '
              'en la puerta exacta.',
              style: MapStyle.secundario,
            ),
            const SizedBox(height: MapStyle.esp3),
            BuscadorDireccion(
              cerca: _punto,
              onElegido: _aplicarLugar,
            ),
            const SizedBox(height: MapStyle.esp3),
            _SelectorPunto(
              controlador: _mapa,
              punto: _punto,
              onPunto: _alMoverPin,
              onMiUbicacion: _irAMiUbicacion,
              buscandoUbicacion: _buscandoGps,
            ),
            const SizedBox(height: MapStyle.esp2),
            _TiraDelPin(
              consultado: _pinConsultado,
              resolviendo: _resolviendoPin,
              lugar: _lugarDelPin,
              // El botón solo aparece cuando hay algo que respetar: si el
              // usuario no ha escrito nada, los campos ya se rellenaron solos.
              onUsar: (_editadoAMano && _lugarDelPin != null)
                  ? () => _aplicarLugar(_lugarDelPin!, moverMapa: false)
                  : null,
            ),
            const SizedBox(height: MapStyle.esp5),

            const EtiquetaSeccion('Datos de la dirección'),
            const SizedBox(height: MapStyle.esp3),

            TextFormField(
              controller: _alias,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Alias (Casa, Oficina…)',
                prefixIcon: Icon(Icons.label_outline, size: 20),
              ),
            ),
            const SizedBox(height: MapStyle.esp3),

            TextFormField(
              controller: _calle,
              onChanged: (_) => _editadoAMano = true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Calle o avenida *',
                prefixIcon: Icon(Icons.signpost_outlined, size: 20),
              ),
              // El único obligatorio: en el backend `calle` no admite nulos.
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'La calle es obligatoria'
                  : null,
            ),
            const SizedBox(height: MapStyle.esp3),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _numero,
              onChanged: (_) => _editadoAMano = true,
                    decoration: const InputDecoration(labelText: 'Número'),
                  ),
                ),
                const SizedBox(width: MapStyle.esp3),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _distrito,
              onChanged: (_) => _editadoAMano = true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Distrito'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MapStyle.esp3),

            TextFormField(
              controller: _ciudad,
              onChanged: (_) => _editadoAMano = true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ciudad',
                prefixIcon: Icon(Icons.location_city_outlined, size: 20),
              ),
            ),
            const SizedBox(height: MapStyle.esp3),

            TextFormField(
              controller: _referencia,
              maxLines: 2,
              maxLength: 255,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Referencia',
                hintText: 'Portón azul, frente al parque…',
                alignLabelWithHint: true,
              ),
            ),

            SwitchListTile(
              value: _esDefault,
              onChanged: _guardando
                  ? null
                  : (v) => setState(() => _esDefault = v),
              contentPadding: EdgeInsets.zero,
              title: const Text('Usar como predeterminada'),
              subtitle: const Text('Se elegirá primero al crear un pedido'),
            ),

            if (_error != null) ...[
              const SizedBox(height: MapStyle.esp3),
              AvisoError(_error!),
            ],

            const SizedBox(height: MapStyle.esp5),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_esNueva ? 'Guardar dirección' : 'Guardar cambios'),
            ),
            const SizedBox(height: MapStyle.esp5),
          ],
        ),
      ),
    );
  }
}

class _TiraDelPin extends StatelessWidget {
  const _TiraDelPin({
    required this.consultado,
    required this.resolviendo,
    required this.lugar,
    this.onUsar,
  });

  final bool consultado;
  final bool resolviendo;
  final Lugar? lugar;
  final VoidCallback? onUsar;

  @override
  Widget build(BuildContext context) {
    if (!consultado) return const SizedBox.shrink();

    final (icono, texto, atenuado) = switch ((resolviendo, lugar)) {
      (true, _) => (Icons.more_horiz, 'Buscando la dirección de este punto…', true),
      (false, null) => (
          Icons.help_outline,
          'No encontramos una dirección para este punto. Escríbela abajo.',
          true,
        ),
      (false, final l?) => (Icons.place_outlined, l.lineaCompleta, false),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono,
            size: 18,
            color: atenuado ? MapStyle.textoSuave : MapStyle.primario),
        const SizedBox(width: MapStyle.esp2),
        Expanded(
          child: Text(
            texto,
            style: atenuado
                ? MapStyle.secundario
                : const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MapStyle.textoFuerte,
                    height: 1.3,
                  ),
          ),
        ),
        if (onUsar != null)
          TextButton(
            onPressed: onUsar,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Usar'),
          ),
      ],
    );
  }
}

class _SelectorPunto extends StatefulWidget {
  const _SelectorPunto({
    required this.controlador,
    required this.punto,
    required this.onPunto,
    required this.onMiUbicacion,
    required this.buscandoUbicacion,
  });

  final MapController controlador;
  final LatLng punto;
  final ValueChanged<LatLng> onPunto;
  final VoidCallback onMiUbicacion;
  final bool buscandoUbicacion;

  @override
  State<_SelectorPunto> createState() => _SelectorPuntoState();
}

class _SelectorPuntoState extends State<_SelectorPunto> {
  late LatLng _centro = widget.punto;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 260,
        child: Stack(
          children: [
            FlutterMap(
              mapController: widget.controlador,
              options: MapOptions(
                initialCenter: widget.punto,
                initialZoom: 16,
                interactionOptions: interaccionMapa,
                onPositionChanged: (posicion, _) {
                  // `center` es nulable en flutter_map 6: durante una animación
                  // puede no haber posición resuelta todavía.
                  final centro = posicion.center;
                  if (centro == null) return;
                  _centro = centro;
                  widget.onPunto(centro);
                },
              ),
              children: [capaTiles(context)],
            ),

            // El pin va en el Stack y no como marcador del mapa: así se queda
            // clavado en el centro mientras el mapa se mueve por debajo.
            IgnorePointer(
              child: Center(
                child: Transform.translate(
                  // El vértice del pin es la punta de abajo, no su centro.
                  offset: const Offset(0, -16),
                  child: const Icon(
                    Icons.place,
                    size: 40,
                    color: MapStyle.primario,
                    shadows: [
                      Shadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              right: MapStyle.esp3,
              bottom: MapStyle.esp3,
              child: ControlesMapa(
                onAcercar: () => widget.controlador.move(
                    _centro, widget.controlador.camera.zoom + 1),
                onAlejar: () => widget.controlador.move(
                    _centro, widget.controlador.camera.zoom - 1),
                // Mientras busca sigue visible pero no responde: esconder el
                // botón movería los otros dos justo cuando el dedo va hacia él.
                onUbicacion: widget.buscandoUbicacion
                    ? () {}
                    : widget.onMiUbicacion,
                ubicacionActiva: widget.buscandoUbicacion,
                iconoUbicacion: widget.buscandoUbicacion
                    ? Icons.more_horiz
                    : Icons.my_location,
                tooltipUbicacion: widget.buscandoUbicacion
                    ? 'Buscando tu ubicación…'
                    : 'Mi ubicación actual',
              ),
            ),

            const Positioned(
              left: MapStyle.esp2,
              bottom: MapStyle.esp2,
              child: AtribucionMapa(),
            ),
          ],
        ),
      ),
    );
  }
}
