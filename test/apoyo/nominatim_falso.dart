// Nominatim de mentira, compartido por las pruebas de geocodificación y las de
// ubicación. Ninguna sale a la red.
import 'package:dio/dio.dart';

Map<String, dynamic> crudoConCalle() => {
      'place_id': 123456,
      'licence': 'Data © OpenStreetMap contributors',
      'osm_type': 'way',
      'osm_id': 987,
      'lat': '-5.1945',
      'lon': '-80.6328',
      'display_name':
          'Avenida Grau, Piura, Provincia de Piura, Piura, 20001, Perú',
      'name': 'Avenida Grau',
      'address': {
        'road': 'Avenida Grau',
        'house_number': '450',
        'suburb': 'Miraflores',
        'city': 'Piura',
        'postcode': '20001',
        'country': 'Perú',
        'country_code': 'pe',
      },
      'boundingbox': ['-5.19', '-5.18', '-80.64', '-80.63'],
    };

Map<String, dynamic> crudoSinCalle() => {
      'lat': '-12.0464',
      'lon': '-77.0428',
      'display_name': 'Plaza Mayor, Cercado de Lima, Lima, 15001, Perú',
      'name': 'Plaza Mayor',
      'address': {
        'city_district': 'Cercado de Lima',
        'city': 'Lima',
        'postcode': '15001',
        'country': 'Perú',
      },
    };

class DioFalso {
  DioFalso(this.respuesta) {
    dio = Dio(BaseOptions(baseUrl: 'https://nominatim.test'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opciones, handler) {
        peticiones.add(opciones);
        final cuerpo = respuesta(opciones);
        if (cuerpo == null) {
          return handler.reject(DioException(
            requestOptions: opciones,
            type: DioExceptionType.connectionError,
          ));
        }
        handler.resolve(Response(
          requestOptions: opciones,
          statusCode: 200,
          data: cuerpo,
        ));
      },
    ));
  }

  late final Dio dio;
  final List<RequestOptions> peticiones = [];
  final Object? Function(RequestOptions) respuesta;
}
