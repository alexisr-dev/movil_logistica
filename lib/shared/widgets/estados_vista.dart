import 'package:flutter/material.dart';

import '../../core/theme/map_style.dart';

class VistaVacia extends StatelessWidget {
  const VistaVacia({
    super.key,
    required this.icono,
    required this.titulo,
    this.mensaje,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? mensaje;

  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MapStyle.esp6 + MapStyle.esp2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: MapStyle.superficieTenue,
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 34, color: MapStyle.neutro),
            ),
            const SizedBox(height: MapStyle.esp5),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: MapStyle.textoFuerte,
              ),
            ),
            if (mensaje != null) ...[
              const SizedBox(height: MapStyle.esp2),
              Text(
                mensaje!,
                textAlign: TextAlign.center,
                style: MapStyle.direccion,
              ),
            ],
            if (accion != null) ...[
              const SizedBox(height: MapStyle.esp5),
              accion!,
            ],
          ],
        ),
      ),
    );
  }
}

class VistaError extends StatelessWidget {
  const VistaError({super.key, required this.error, this.onReintentar});

  final Object error;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MapStyle.esp6 + MapStyle.esp2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: MapStyle.neutro),
            const SizedBox(height: MapStyle.esp4),
            const Text(
              'No se pudieron cargar los datos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MapStyle.textoFuerte,
              ),
            ),
            const SizedBox(height: MapStyle.esp2),
            Text(
              _describir(error),
              textAlign: TextAlign.center,
              style: MapStyle.secundario,
            ),
            if (onReintentar != null) ...[
              const SizedBox(height: MapStyle.esp5),
              OutlinedButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh, size: 19),
                label: const Text('Reintentar'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(180, MapStyle.tap),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _describir(Object error) {
    final texto = error.toString();
    final limpio = texto.replaceFirst(RegExp(r'^\w+Exception \[[^\]]*\]:\s*'), '');
    return limpio.length > 220 ? '${limpio.substring(0, 220)}…' : limpio;
  }
}

class Esqueleto extends StatefulWidget {
  const Esqueleto({
    super.key,
    this.alto = 16,
    this.ancho = double.infinity,
    this.radio = 8,
  });

  final double alto;
  final double ancho;
  final double radio;

  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      // Un latido suave, no un parpadeo: la animación es para decir "esto está
      // por llegar", no para llamar la atención.
      opacity: Tween<double>(begin: 0.45, end: 0.85).animate(_control),
      child: Container(
        width: widget.ancho,
        height: widget.alto,
        decoration: BoxDecoration(
          color: MapStyle.borde,
          borderRadius: BorderRadius.circular(widget.radio),
        ),
      ),
    );
  }
}

class ListaEsqueleto extends StatelessWidget {
  const ListaEsqueleto({super.key, this.filas = 3});

  final int filas;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(MapStyle.esp4),
      itemCount: filas,
      separatorBuilder: (_, __) => const SizedBox(height: MapStyle.esp3),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(MapStyle.esp4),
        decoration: BoxDecoration(
          color: MapStyle.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MapStyle.borde),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Esqueleto(alto: 14, ancho: 120),
            SizedBox(height: MapStyle.esp3),
            Esqueleto(alto: 12),
            SizedBox(height: MapStyle.esp2),
            Esqueleto(alto: 12, ancho: 180),
          ],
        ),
      ),
    );
  }
}
