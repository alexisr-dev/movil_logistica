import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class PaletaAuth {
  static const fondo = Color(0xFFF6F8FC);
  static const superficie = Colors.white;
  static const campo = Color(0xFFF8FAFC);
  static const borde = Color(0xFFE3E8EF);
  static const bordeError = Color(0xFFFECACA);
  static const textoFuerte = Color(0xFF0F172A);
  static const textoSuave = Color(0xFF64748B);
  static const textoTenue = Color(0xFF94A3B8);
  static const error = Color(0xFFDC2626);
  static const errorTexto = Color(0xFF991B1B);
  static const errorFondo = Color(0xFFFEF2F2);
}

const transicionAuth = Duration(milliseconds: 180);
class MarcaAuth extends StatelessWidget {
  const MarcaAuth({super.key, required this.compacto});

  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final lado = compacto ? 62.0 : 72.0;

    return Column(
      children: [
        Container(
          width: lado,
          height: lado,
          decoration: BoxDecoration(
            // Único gradiente de la pantalla, heredado del login anterior:
            // concentra la marca en una pieza en vez de teñir todo el fondo.
            gradient: const LinearGradient(
              colors: [AppTheme.primario, AppTheme.primarioOscuro],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(lado * 0.3),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primario.withOpacity(0.28),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            // Mismo icono que ya identifica las entregas en el resto de la app.
            Icons.local_shipping_rounded,
            color: Colors.white,
            size: compacto ? 30 : 34,
          ),
        ),
        SizedBox(height: compacto ? 14 : 18),
        Text(
          'Logística',
          style: TextStyle(
            fontSize: compacto ? 26 : 29,
            fontWeight: FontWeight.w700,
            color: PaletaAuth.textoFuerte,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sistema de logística y envíos',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: PaletaAuth.textoSuave,
          ),
        ),
      ],
    );
  }
}

class TarjetaAuth extends StatelessWidget {
  const TarjetaAuth({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: PaletaAuth.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaletaAuth.borde),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class CampoTexto extends StatefulWidget {
  const CampoTexto({
    super.key,
    required this.etiqueta,
    required this.pista,
    required this.icono,
    required this.controlador,
    required this.foco,
    this.conError = false,
    required this.habilitado,
    this.oculto = false,
    this.sufijo,
    this.tipoTeclado,
    this.accionTeclado,
    this.autocompletado,
    this.alEnviar,
  });

  final String etiqueta;
  final String pista;
  final IconData icono;
  final TextEditingController controlador;
  final FocusNode foco;
  final bool conError;
  final bool habilitado;
  final bool oculto;
  final Widget? sufijo;
  final TextInputType? tipoTeclado;
  final TextInputAction? accionTeclado;
  final List<String>? autocompletado;
  final ValueChanged<String>? alEnviar;

  @override
  State<CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  bool _enfocado = false;

  @override
  void initState() {
    super.initState();
    widget.foco.addListener(_alCambiarFoco);
  }

  @override
  void dispose() {
    widget.foco.removeListener(_alCambiarFoco);
    super.dispose();
  }

  void _alCambiarFoco() {
    if (mounted && _enfocado != widget.foco.hasFocus) {
      setState(() => _enfocado = widget.foco.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acento = widget.conError ? PaletaAuth.error : AppTheme.primario;
    final resaltado = _enfocado || widget.conError;

    final Color colorBorde;
    if (widget.conError) {
      colorBorde = PaletaAuth.error;
    } else if (_enfocado) {
      colorBorde = AppTheme.primario;
    } else {
      colorBorde = PaletaAuth.borde;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            widget.etiqueta,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: widget.conError ? PaletaAuth.error : PaletaAuth.textoSuave,
            ),
          ),
        ),
        AnimatedContainer(
          duration: transicionAuth,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _enfocado ? Colors.white : PaletaAuth.campo,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorBorde, width: resaltado ? 1.5 : 1),
            boxShadow: _enfocado
                ? [
                    // Anillo de foco: sin desenfoque, solo expansión, para que
                    // se lea como un halo nítido y no como una sombra.
                    BoxShadow(
                      color: acento.withOpacity(0.14),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : const [],
          ),
          child: TextField(
            controller: widget.controlador,
            focusNode: widget.foco,
            enabled: widget.habilitado,
            obscureText: widget.oculto,
            keyboardType: widget.tipoTeclado,
            textInputAction: widget.accionTeclado,
            autofillHints: widget.autocompletado,
            onSubmitted: widget.alEnviar,
            cursorColor: acento,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: PaletaAuth.textoFuerte,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: widget.pista,
              hintStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: PaletaAuth.textoTenue,
              ),
              // 16 arriba y abajo dejan el campo en ~54 px: cómodo para el dedo.
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              prefixIcon: Icon(
                widget.icono,
                size: 20,
                color: resaltado ? acento : PaletaAuth.textoTenue,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 46,
                minHeight: 46,
              ),
              suffixIcon: widget.sufijo,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BotonVerContrasena extends StatelessWidget {
  const BotonVerContrasena({
    super.key,
    required this.oculta,
    required this.alPulsar,
  });

  final bool oculta;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: alPulsar,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      tooltip: oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
      icon: Icon(
        oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: PaletaAuth.textoSuave,
      ),
    );
  }
}

class BannerError extends StatelessWidget {
  const BannerError({super.key, required this.mensaje});

  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: mensaje == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 18),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: PaletaAuth.errorFondo,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PaletaAuth.bordeError),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: PaletaAuth.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      mensaje!,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: PaletaAuth.errorTexto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class BotonPrincipal extends StatefulWidget {
  const BotonPrincipal({
    super.key,
    required this.cargando,
    required this.alPulsar,
    required this.texto,
    this.textoCargando = 'Un momento…',
  });

  final bool cargando;
  final VoidCallback alPulsar;
  final String texto;
  final String textoCargando;

  @override
  State<BotonPrincipal> createState() => _BotonPrincipalState();
}

class _BotonPrincipalState extends State<BotonPrincipal> {
  bool _presionado = false;

  void _soltar() {
    if (_presionado) setState(() => _presionado = false);
  }

  @override
  Widget build(BuildContext context) {
    final habilitado = !widget.cargando;

    return Listener(
      // `Listener` escucha el puntero sin competir por el gesto, así que el
      // botón conserva intactos su onPressed y su ripple.
      onPointerDown:
          habilitado ? (_) => setState(() => _presionado = true) : null,
      onPointerUp: (_) => _soltar(),
      onPointerCancel: (_) => _soltar(),
      child: AnimatedScale(
        scale: _presionado ? 0.98 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: transicionAuth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: habilitado && !_presionado
                ? [
                    BoxShadow(
                      color: AppTheme.primario.withOpacity(0.26),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: habilitado ? widget.alPulsar : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primario,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.primario.withOpacity(0.45),
                disabledForegroundColor: Colors.white.withOpacity(0.92),
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: widget.cargando
                    ? Row(
                        key: const ValueKey('cargando'),
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(widget.textoCargando),
                        ],
                      )
                    : Text(widget.texto, key: const ValueKey('etiqueta')),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AparicionSuave extends StatelessWidget {
  const AparicionSuave({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, valor, hijo) => Opacity(
        opacity: valor.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - valor) * 18),
          child: hijo,
        ),
      ),
    );
  }
}

class EnlaceAuth extends StatelessWidget {
  const EnlaceAuth({super.key, required this.texto, this.alPulsar});

  final String texto;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    final habilitado = alPulsar != null;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: alPulsar,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: AppTheme.primario,
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: habilitado
                ? AppTheme.primario
                : AppTheme.primario.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}

class PiePregunta extends StatelessWidget {
  const PiePregunta({
    super.key,
    required this.pregunta,
    required this.accion,
    this.alPulsar,
  });

  final String pregunta;
  final String accion;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    final habilitado = alPulsar != null;
    // Wrap y no Row: con una pregunta larga ("¿Te equivocaste de correo?") y el
    // texto a tamaño grande del sistema, un Row desborda y pinta las franjas
    // amarillas y negras. Así pasa a dos líneas en vez de romperse.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          pregunta,
          style: const TextStyle(fontSize: 13.5, color: PaletaAuth.textoSuave),
        ),
        TextButton(
          onPressed: alPulsar,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            minimumSize: const Size(0, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            accion,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: habilitado
                  ? AppTheme.primario
                  : AppTheme.primario.withOpacity(0.4),
            ),
          ),
        ),
      ],
    );
  }
}
