import 'package:flutter/material.dart';

import '../../../core/theme/map_style.dart';

class ChipEstado extends StatelessWidget {
  const ChipEstado({super.key, required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MapStyle.esp2,
        vertical: MapStyle.esp1,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(MapStyle.radioPildora),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: MapStyle.esp2 - 2),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color.alphaBlend(color.withOpacity(0.85), MapStyle.textoFuerte),
            ),
          ),
        ],
      ),
    );
  }
}

class PildoraMetrica extends StatelessWidget {
  const PildoraMetrica({super.key, required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MapStyle.esp3,
        vertical: MapStyle.esp2 - 1,
      ),
      decoration: BoxDecoration(
        color: MapStyle.superficieTenue,
        borderRadius: BorderRadius.circular(MapStyle.radioPildora),
        border: Border.all(color: MapStyle.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15, color: MapStyle.textoSuave),
          const SizedBox(width: MapStyle.esp2 - 2),
          Text(texto, style: MapStyle.metrica),
        ],
      ),
    );
  }
}

class EtiquetaSeccion extends StatelessWidget {
  const EtiquetaSeccion(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) =>
      Text(texto.toUpperCase(), style: MapStyle.etiqueta);
}

class BotonMapa extends StatelessWidget {
  const BotonMapa({
    super.key,
    required this.icono,
    required this.onTap,
    this.tooltip,
    this.activo = false,
    this.radio = MapStyle.radioControl,
  });

  final IconData icono;
  final VoidCallback? onTap;
  final String? tooltip;

  final bool activo;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final boton = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radio),
        child: SizedBox(
          width: MapStyle.tap,
          height: MapStyle.tap,
          child: Icon(
            icono,
            size: 21,
            color: onTap == null
                ? MapStyle.neutro
                : (activo ? MapStyle.primario : MapStyle.textoFuerte),
          ),
        ),
      ),
    );

    return tooltip == null ? boton : Tooltip(message: tooltip!, child: boton);
  }
}

class TarjetaFlotante extends StatelessWidget {
  const TarjetaFlotante({
    super.key,
    required this.child,
    this.radio = MapStyle.radioControl,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radio;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: MapStyle.superficie,
        borderRadius: BorderRadius.circular(radio),
        boxShadow: MapStyle.sombraFlotante,
      ),
      child: child,
    );
  }
}

class AsaHoja extends StatelessWidget {
  const AsaHoja({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: MapStyle.esp3 - 2),
      decoration: BoxDecoration(
        color: MapStyle.borde,
        borderRadius: BorderRadius.circular(MapStyle.radioPildora),
      ),
    );
  }
}

class MedidorAltura extends StatefulWidget {
  const MedidorAltura({super.key, required this.child, required this.onAltura});

  final Widget child;
  final ValueChanged<double> onAltura;

  @override
  State<MedidorAltura> createState() => _MedidorAlturaState();
}

class _MedidorAlturaState extends State<MedidorAltura> {
  final _clave = GlobalKey();
  double? _ultima;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final alto = _clave.currentContext?.size?.height;
      if (alto == null || alto == _ultima) return;
      _ultima = alto;
      widget.onAltura(alto);
    });

    return KeyedSubtree(key: _clave, child: widget.child);
  }
}
