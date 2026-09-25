import '../../../core/network/api_client.dart';
import '../../../shared/models/rendimiento.dart';

class ReportesRepository {
  final _dio = ApiClient.instance.dio;

  Future<Rendimiento> miRendimiento() async {
    final res = await _dio.get('/reportes/mi-rendimiento/');
    return Rendimiento.fromJson(res.data as Map<String, dynamic>);
  }
}
