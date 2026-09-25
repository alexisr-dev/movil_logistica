import 'package:flutter/material.dart';

import '../../../core/theme/map_style.dart';
import 'piezas_mapa.dart';

const BoxDecoration decoracionHoja = BoxDecoration(
  color: MapStyle.superficie,
  borderRadius: BorderRadius.vertical(top: Radius.circular(MapStyle.radioHoja)),
  boxShadow: MapStyle.sombraHoja,
);

class HojaMapa extends StatelessWidget {
  const HojaMapa({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      MapStyle.esp5,
      0,
      MapStyle.esp5,
      MapStyle.esp5,
    ),
    this.conAsa = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool conAsa;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: decoracionHoja,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (conAsa) const Center(child: AsaHoja()),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class AvisoError extends StatelessWidget {
  const AvisoError(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MapStyle.esp3),
      decoration: BoxDecoration(
        color: MapStyle.peligro.withOpacity(0.08),
        borderRadius: BorderRadius.circular(MapStyle.radioControl - 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: MapStyle.peligro),
          const SizedBox(width: MapStyle.esp2 + 2),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                fontSize: 13,
                color: MapStyle.peligro,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
