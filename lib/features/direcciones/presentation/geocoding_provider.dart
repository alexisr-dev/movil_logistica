import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/geocoding_repository.dart';

final geocodingRepositoryProvider =
    Provider<GeocodingRepository>((ref) => GeocodingRepository());
