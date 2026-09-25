import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/map_style.dart';
import '../../../notificaciones/presentation/notificaciones_provider.dart';

class CampanaNotificaciones extends ConsumerWidget {
  const CampanaNotificaciones({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sinLeer = ref.watch(noLeidasProvider).valueOrNull ?? 0;

    return Semantics(
      button: true,
      label: sinLeer == 0
          ? 'Notificaciones'
          : 'Notificaciones, $sinLeer sin leer',
      child: SizedBox(
        width: MapStyle.tap,
        height: MapStyle.tap,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/notificaciones'),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none,
                    size: 24, color: MapStyle.textoFuerte),
                if (sinLeer > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: MapStyle.peligro,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: MapStyle.superficie, width: 1.5),
                      ),
                      child: Text(
                        // Más de 99 no cabe y tampoco aporta: lo que importa es
                        // que hay muchas.
                        sinLeer > 99 ? '99+' : sinLeer.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
