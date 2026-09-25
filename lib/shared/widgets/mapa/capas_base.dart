import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../core/theme/map_style.dart';

Widget capaTiles(BuildContext context) {
  return ColorFiltered(
    colorFilter: MapStyle.filtroMapaClaro,
    child: TileLayer(
      urlTemplate: MapStyle.tilesUrl,
      userAgentPackageName: MapStyle.paqueteAgente,
    ),
  );
}

class AtribucionMapa extends StatelessWidget {
  const AtribucionMapa({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: MapStyle.superficie.withOpacity(0.82),
        borderRadius: BorderRadius.circular(MapStyle.radioPildora),
      ),
      child: const Text(
        MapStyle.atribucion,
        style: TextStyle(fontSize: 10, color: MapStyle.textoSuave, height: 1.2),
      ),
    );
  }
}

const Set<MapEventSource> gestosDelUsuario = {
  MapEventSource.dragStart,
  MapEventSource.onDrag,
  MapEventSource.multiFingerGestureStart,
  MapEventSource.onMultiFinger,
  MapEventSource.doubleTapHold,
  MapEventSource.flingAnimationController,
  MapEventSource.scrollWheel,
};

const InteractionOptions interaccionMapa = InteractionOptions(
  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
);
