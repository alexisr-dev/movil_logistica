import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/map_style.dart';
import '../../features/direcciones/presentation/geocoding_provider.dart';
import '../models/lugar.dart';

class BuscadorDireccion extends ConsumerStatefulWidget {
  const BuscadorDireccion({
    super.key,
    required this.onElegido,
    this.cerca,
    this.etiqueta = 'Buscar calle, avenida o lugar',
    this.pista = 'Ej.: Av. Grau 450',
    this.autofoco = false,
  });

  final ValueChanged<Lugar> onElegido;

  final LatLng? cerca;

  final String etiqueta;
  final String pista;
  final bool autofoco;

  @override
  ConsumerState<BuscadorDireccion> createState() => _BuscadorDireccionState();
}

class _BuscadorDireccionState extends ConsumerState<BuscadorDireccion> {
  final _texto = TextEditingController();
  final _foco = FocusNode();

  Timer? _espera;
  CancelToken? _enCurso;

  List<Lugar> _resultados = const [];
  bool _buscando = false;
  bool _sinResultados = false;

  @override
  void dispose() {
    _espera?.cancel();
    _enCurso?.cancel();
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _alEscribir(String valor) {
    _espera?.cancel();
    _enCurso?.cancel();

    if (valor.trim().length < 3) {
      setState(() {
        _resultados = const [];
        _buscando = false;
        _sinResultados = false;
      });
      return;
    }

    setState(() {
      _buscando = true;
      _sinResultados = false;
    });
    _espera = Timer(const Duration(milliseconds: 450), () => _buscar(valor));
  }

  Future<void> _buscar(String valor) async {
    final cancelar = CancelToken();
    _enCurso = cancelar;

    final lugares = await ref.read(geocodingRepositoryProvider).buscar(
          valor,
          cerca: widget.cerca,
          cancelar: cancelar,
        );

    // La petición pudo cancelarse mientras volvía, o cerrarse la pantalla.
    if (!mounted || cancelar.isCancelled) return;
    setState(() {
      _resultados = lugares;
      _buscando = false;
      _sinResultados = lugares.isEmpty;
    });
  }

  void _limpiar() {
    _espera?.cancel();
    _enCurso?.cancel();
    _texto.clear();
    setState(() {
      _resultados = const [];
      _buscando = false;
      _sinResultados = false;
    });
  }

  void _elegir(Lugar lugar) {
    _foco.unfocus();
    _texto.text = lugar.lineaCompleta;
    setState(() {
      _resultados = const [];
      _sinResultados = false;
    });
    widget.onElegido(lugar);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _texto,
          focusNode: _foco,
          autofocus: widget.autofoco,
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.words,
          onChanged: _alEscribir,
          onSubmitted: (v) {
            _espera?.cancel();
            if (v.trim().length >= 3) _buscar(v);
          },
          decoration: InputDecoration(
            labelText: widget.etiqueta,
            hintText: widget.pista,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_texto.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _limpiar,
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Limpiar',
                      )),
          ),
        ),
        if (_sinResultados) ...[
          const SizedBox(height: MapStyle.esp2),
          const Text(
            'Sin coincidencias. Prueba con otro nombre, o coloca el pin a mano '
            'en el mapa.',
            style: MapStyle.secundario,
          ),
        ],
        if (_resultados.isNotEmpty) ...[
          const SizedBox(height: MapStyle.esp2),
          Container(
            decoration: BoxDecoration(
              color: MapStyle.superficie,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MapStyle.borde),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _resultados.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 46, color: MapStyle.borde),
                  _Sugerencia(
                    lugar: _resultados[i],
                    onTap: () => _elegir(_resultados[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Sugerencia extends StatelessWidget {
  const _Sugerencia({required this.lugar, required this.onTap});

  final Lugar lugar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detalle = lugar.detalle;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MapStyle.esp3,
          vertical: MapStyle.esp3 - 2,
        ),
        child: Row(
          children: [
            const Icon(Icons.place_outlined,
                size: 20, color: MapStyle.textoSuave),
            const SizedBox(width: MapStyle.esp3 - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lugar.etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MapStyle.textoFuerte,
                      height: 1.25,
                    ),
                  ),
                  if (detalle.isNotEmpty)
                    Text(
                      detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MapStyle.secundario,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
