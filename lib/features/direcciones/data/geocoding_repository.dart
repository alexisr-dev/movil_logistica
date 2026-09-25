import 'dart:async';

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/env.dart';
import '../../../shared/models/lugar.dart';

class GeocodingRepository {
  GeocodingRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: Env.nominatimUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: const {
                'User-Agent': 'movil_logistica/1.0 (app de reparto)',
                'Accept': 'application/json',
              },
            ));

  final Dio _dio;

  final _cache = <String, List<Lugar>>{};

  final _cacheInversa = <String, Lugar>{};

  static const _tope = 60;

  DateTime _ultima = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _turno;

  Future<void> _espaciar() {
    final anterior = _turno ?? Future<void>.value();
    final propio = anterior.then((_) async {
      final desde = DateTime.now().difference(_ultima);
      const minimo = Duration(milliseconds: 1100);
      if (desde < minimo) await Future<void>.delayed(minimo - desde);
      _ultima = DateTime.now();
    });
    _turno = propio;
    return propio;
  }

  void _guardar(String clave, List<Lugar> lugares) {
    if (_cache.length >= _tope) _cache.clear();
    _cache[clave] = lugares;
  }

  Future<List<Lugar>> buscar(
    String texto, {
    LatLng? cerca,
    CancelToken? cancelar,
    int limite = 6,
  }) async {
    final consulta = texto.trim();
    // Menos de tres letras no discrimina nada y solo gasta peticiones.
    if (consulta.length < 3) return const [];

    final clave = '${consulta.toLowerCase()}@${cerca?.latitude.toStringAsFixed(2)},'
        '${cerca?.longitude.toStringAsFixed(2)}';
    final memorizado = _cache[clave];
    if (memorizado != null) return memorizado;

    try {
      await _espaciar();
      if (cancelar?.isCancelled ?? false) return const [];

      final respuesta = await _dio.get<List<dynamic>>(
        '/search',
        cancelToken: cancelar,
        queryParameters: {
          'q': consulta,
          'format': 'jsonv2',
          'addressdetails': 1,
          'limit': limite,
          'accept-language': 'es',
          if (Env.paisGeocoding.isNotEmpty) 'countrycodes': Env.paisGeocoding,
          if (cerca != null) ...{
            'viewbox': _recuadro(cerca),
            'bounded': 0,
          },
        },
      );

      final lugares = (respuesta.data ?? [])
          .whereType<Map>()
          .map((e) => Lugar.fromNominatim(e.cast<String, dynamic>()))
          .where((l) => l.etiqueta.isNotEmpty)
          .toList(growable: false);

      _guardar(clave, lugares);
      return lugares;
    } on DioException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<Lugar?> direccionDe(LatLng punto, {CancelToken? cancelar}) async {
    final clave = '${punto.latitude.toStringAsFixed(5)},'
        '${punto.longitude.toStringAsFixed(5)}';
    final memorizado = _cacheInversa[clave];
    if (memorizado != null) return memorizado;

    try {
      await _espaciar();
      if (cancelar?.isCancelled ?? false) return null;

      final respuesta = await _dio.get<Map<String, dynamic>>(
        '/reverse',
        cancelToken: cancelar,
        queryParameters: {
          'lat': punto.latitude,
          'lon': punto.longitude,
          'format': 'jsonv2',
          'addressdetails': 1,
          'zoom': 18,
          'accept-language': 'es',
        },
      );

      final datos = respuesta.data;
      if (datos == null || datos['error'] != null) return null;

      final lugar = Lugar.fromNominatim(datos);
      if (lugar.etiqueta.isEmpty) return null;

      if (_cacheInversa.length >= _tope) _cacheInversa.clear();
      _cacheInversa[clave] = lugar;
      return lugar;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  String _recuadro(LatLng centro) {
    const margen = 0.18;
    return '${centro.longitude - margen},${centro.latitude + margen},'
        '${centro.longitude + margen},${centro.latitude - margen}';
  }
}
