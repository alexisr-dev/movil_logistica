import 'package:flutter/material.dart';

import '../../../core/theme/map_style.dart';
import 'piezas_mapa.dart';

class AccionMapa {
  const AccionMapa({
    required this.etiqueta,
    required this.icono,
    required this.onTap,
  });

  final String etiqueta;
  final IconData icono;
  final VoidCallback onTap;
}

class EncabezadoMapa extends StatelessWidget {
  const EncabezadoMapa({
    super.key,
    required this.titulo,
    this.onVolver,
    this.estado,
    this.acciones = const [],
  });

  final String titulo;

  final VoidCallback? onVolver;

  final Widget? estado;
  final List<AccionMapa> acciones;

  @override
  Widget build(BuildContext context) {
    final volver = onVolver;
    final chip = estado;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MapStyle.esp3,
          MapStyle.esp3,
          MapStyle.esp3,
          0,
        ),
        child: TarjetaFlotante(
          radio: MapStyle.radioControl + 2,
          padding: EdgeInsets.only(
            left: volver == null ? MapStyle.esp4 : MapStyle.esp1,
            right: acciones.isEmpty ? MapStyle.esp4 : MapStyle.esp1,
          ),
          child: Row(
            children: [
              if (volver != null)
                BotonMapa(
                  icono: Icons.arrow_back,
                  tooltip: 'Volver',
                  onTap: volver,
                  radio: MapStyle.tap / 2,
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: volver == null ? 0 : MapStyle.esp1,
                    vertical: MapStyle.esp2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MapStyle.tituloBarra,
                      ),
                      if (chip != null) ...[
                        const SizedBox(height: MapStyle.esp1 + 1),
                        // El estado cambia solo (se conecta, se cae la red):
                        // el fundido evita que el cambio pase desapercibido.
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: chip,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (acciones.isNotEmpty)
                PopupMenuButton<AccionMapa>(
                  tooltip: 'Opciones',
                  icon: const Icon(
                    Icons.more_vert,
                    color: MapStyle.textoFuerte,
                    size: 21,
                  ),
                  splashRadius: MapStyle.tap / 2,
                  position: PopupMenuPosition.under,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MapStyle.radioControl),
                  ),
                  onSelected: (accion) => accion.onTap(),
                  itemBuilder: (_) => [
                    for (final accion in acciones)
                      PopupMenuItem(
                        value: accion,
                        child: Row(
                          children: [
                            Icon(accion.icono, size: 19, color: MapStyle.textoSuave),
                            const SizedBox(width: MapStyle.esp3),
                            Text(accion.etiqueta),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
