import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/map_style.dart';
import 'piezas_mapa.dart';

class _FormaPin extends CustomPainter {
  const _FormaPin(this.color);

  final Color color;

  Path _contorno(Size size) {
    final radio = size.width / 2;
    final centro = Offset(radio, radio);
    final circulo = Path()
      ..addOval(Rect.fromCircle(center: centro, radius: radio - 1.4));
    final punta = Path()
      ..moveTo(centro.dx - radio * 0.56, centro.dy + radio * 0.74)
      ..lineTo(centro.dx, size.height - 1)
      ..lineTo(centro.dx + radio * 0.56, centro.dy + radio * 0.74)
      ..close();
    return Path.combine(PathOperation.union, circulo, punta);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final contorno = _contorno(size);
    canvas.drawShadow(contorno, const Color(0x66000000), 3, false);
    canvas.drawPath(contorno, Paint()..color = color);
    canvas.drawPath(
      contorno,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  @override
  bool shouldRepaint(_FormaPin anterior) => anterior.color != color;
}

class MarcadorExtremo extends StatelessWidget {
  const MarcadorExtremo({
    super.key,
    required this.icono,
    required this.color,
    this.tamano = 34,
    this.etiqueta,
  });

  final IconData icono;
  final Color color;
  final double tamano;

  final Widget? etiqueta;

  @override
  Widget build(BuildContext context) {
    return _ColumnaMarcador(
      etiqueta: etiqueta,
      pin: _Pin(
        color: color,
        tamano: tamano,
        contenido: Icon(icono, size: tamano * 0.48, color: Colors.white),
      ),
    );
  }
}

class MarcadorParada extends StatelessWidget {
  const MarcadorParada({
    super.key,
    required this.orden,
    required this.color,
    this.destacada = false,
    this.entregada = false,
    this.etiqueta,
    this.onTap,
  });

  final int orden;
  final Color color;

  final bool destacada;
  final bool entregada;
  final Widget? etiqueta;
  final VoidCallback? onTap;

  static double tamanoPin(bool destacada) => destacada ? 40 : 30;

  @override
  Widget build(BuildContext context) {
    final tamano = tamanoPin(destacada);

    final marcador = _ColumnaMarcador(
      etiqueta: etiqueta,
      pin: _Pin(
        color: color,
        tamano: tamano,
        contenido: entregada
            ? Icon(Icons.check, size: tamano * 0.5, color: Colors.white)
            : Text(
                orden.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: destacada ? 16 : 13,
                  height: 1,
                ),
              ),
      ),
    );

    if (onTap == null) return marcador;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: marcador,
    );
  }
}

class MarcadorRepartidor extends StatefulWidget {
  const MarcadorRepartidor({
    super.key,
    required this.icono,
    this.rumboGrados,
    this.emitiendo = false,
    this.color = MapStyle.primario,
  });

  final IconData icono;

  final double? rumboGrados;

  final bool emitiendo;
  final Color color;

  @override
  State<MarcadorRepartidor> createState() => _MarcadorRepartidorState();
}

class _MarcadorRepartidorState extends State<MarcadorRepartidor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ajustarPulso();
  }

  @override
  void didUpdateWidget(MarcadorRepartidor anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.emitiendo != widget.emitiendo) _ajustarPulso();
  }

  void _ajustarPulso() {
    // Respeta «reducir animaciones» del sistema: quien lo activa suele hacerlo
    // por mareo, y esto es una animación en bucle.
    final permitida =
        widget.emitiendo && !MediaQuery.of(context).disableAnimations;
    if (permitida && !_pulso.isAnimating) {
      _pulso.repeat();
    } else if (!permitida && _pulso.isAnimating) {
      _pulso
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rumbo = widget.rumboGrados;

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulso,
          builder: (_, __) {
            final t = _pulso.value;
            return Container(
              width: 30 + 30 * t,
              height: 30 + 30 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(0.22 * (1 - t)),
              ),
            );
          },
        ),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: MapStyle.superficie,
            shape: BoxShape.circle,
            border: Border.all(color: widget.color, width: 3),
            boxShadow: MapStyle.sombraFlotante,
          ),
          alignment: Alignment.center,
          child: Transform.rotate(
            angle: rumbo == null ? 0 : rumbo * math.pi / 180,
            child: Icon(widget.icono, color: widget.color, size: 18),
          ),
        ),
      ],
    );
  }
}

double altoMarcador(
  BuildContext context, {
  required double tamanoPin,
  bool conEtiqueta = false,
  bool conSubtitulo = true,
}) {
  final pin = tamanoPin * 1.34 + 2;
  if (!conEtiqueta) return pin;
  return pin +
      MapStyle.esp1 +
      EtiquetaMarcador.altoEstimado(context, conSubtitulo: conSubtitulo);
}

class EtiquetaMarcador extends StatelessWidget {
  const EtiquetaMarcador({super.key, required this.titulo, this.subtitulo});

  final String titulo;
  final String? subtitulo;

  static const _escalaMaxima = 1.3;

  static TextScaler _escala(BuildContext context) {
    final actual = MediaQuery.textScalerOf(context).scale(100) / 100;
    return TextScaler.linear(actual.clamp(1.0, _escalaMaxima));
  }

  static double altoEstimado(BuildContext context, {bool conSubtitulo = true}) {
    final escala = _escala(context);
    // Relleno vertical + línea del título + línea del subtítulo, con holgura.
    return 12 +
        escala.scale(11) * 1.2 +
        (conSubtitulo ? escala.scale(13) * 1.25 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final sub = subtitulo;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: _escala(context)),
      child: TarjetaFlotante(
        radio: 10,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titulo.toUpperCase(), style: MapStyle.etiqueta),
            if (sub != null && sub.isNotEmpty)
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MapStyle.textoFuerte,
                  height: 1.25,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Piezas internas
// -----------------------------------------------------------------------------

class _Pin extends StatelessWidget {
  const _Pin({
    required this.color,
    required this.tamano,
    required this.contenido,
  });

  final Color color;
  final double tamano;
  final Widget contenido;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano * 1.34,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _FormaPin(color))),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: tamano,
            child: Center(child: contenido),
          ),
        ],
      ),
    );
  }
}

class _ColumnaMarcador extends StatelessWidget {
  const _ColumnaMarcador({required this.pin, this.etiqueta});

  final Widget pin;
  final Widget? etiqueta;

  @override
  Widget build(BuildContext context) {
    final rotulo = etiqueta;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (rotulo != null) ...[
          Flexible(child: rotulo),
          const SizedBox(height: MapStyle.esp1),
        ],
        pin,
      ],
    );
  }
}
