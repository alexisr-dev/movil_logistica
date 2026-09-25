import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env.dart';

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(_authInterceptor());
  }

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  Dio get dio => _dio;

  void Function()? onSesionExpirada;

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refresh = await _storage.read(key: 'refresh_token');
          if (refresh != null) {
            try {
              final res = await Dio().post(
                '${Env.apiUrl}/auth/refresh/',
                data: {'refresh': refresh},
              );
              final nuevo = res.data['access'] as String;
              await _storage.write(key: 'access_token', value: nuevo);
              error.requestOptions.headers['Authorization'] = 'Bearer $nuevo';
              final clone = await _dio.fetch(error.requestOptions);
              return handler.resolve(clone);
            } catch (_) {
              await _storage.deleteAll();
              onSesionExpirada?.call();
            }
          } else {
            // 401 sin refresh guardado: tampoco hay sesión que recuperar.
            onSesionExpirada?.call();
          }
        }
        handler.next(error);
      },
    );
  }
}
