import 'package:flutter/material.dart';

import '../../../core/theme/map_style.dart';
import 'piezas_mapa.dart';

class ControlesMapa extends StatelessWidget {
  const ControlesMapa({
    super.key,
    required this.onAcercar,
    required this.onAlejar,
    this.onUbicacion,
    this.ubicacionActiva = false,
    this.iconoUbicacion = Icons.my_location,
    this.tooltipUbicacion,
  });

  final VoidCallback onAcercar;
  final VoidCallback onAlejar;

  final VoidCallback? onUbicacion;
  final bool ubicacionActiva;
  final IconData iconoUbicacion;
  final String? tooltipUbicacion;

  @override
  Widget build(BuildContext context) {
    final ubicacion = onUbicacion;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TarjetaFlotante(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BotonMapa(
                icono: Icons.add,
                tooltip: 'Acercar',
                onTap: onAcercar,
              ),
              const SizedBox(
                width: MapStyle.tap - 16,
                child: Divider(height: 1, color: MapStyle.borde),
              ),
              BotonMapa(
                icono: Icons.remove,
                tooltip: 'Alejar',
                onTap: onAlejar,
              ),
            ],
          ),
        ),
        if (ubicacion != null) ...[
          const SizedBox(height: MapStyle.esp3),
          TarjetaFlotante(
            radio: MapStyle.tap / 2,
            child: BotonMapa(
              icono: iconoUbicacion,
              tooltip: tooltipUbicacion,
              onTap: ubicacion,
              activo: ubicacionActiva,
              radio: MapStyle.tap / 2,
            ),
          ),
        ],
      ],
    );
  }
}
