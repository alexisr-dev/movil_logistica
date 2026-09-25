import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'recuperacion_provider.dart';
import 'widgets/piezas_auth.dart';

class RecuperarPasswordScreen extends ConsumerStatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  ConsumerState<RecuperarPasswordScreen> createState() => _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends ConsumerState<RecuperarPasswordScreen> {
  final _email = TextEditingController();
  final _codigo = TextEditingController();
  final _password = TextEditingController();

  final _focoEmail = FocusNode();
  final _focoCodigo = FocusNode();
  final _focoPassword = FocusNode();

  bool _ocultarPassword = true;
  String? _errorLocal;

  @override
  void dispose() {
    for (final c in [_email, _codigo, _password]) {
      c.dispose();
    }
    for (final f in [_focoEmail, _focoCodigo, _focoPassword]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _pedirCodigo() async {
    if (ref.read(recuperacionProvider).cargando) return;
    FocusScope.of(context).unfocus();

    if (!_email.text.contains('@') || !_email.text.contains('.')) {
      setState(() => _errorLocal = 'Escribe un correo válido.');
      return;
    }
    setState(() => _errorLocal = null);
    await ref.read(recuperacionProvider.notifier).solicitarCodigo(_email.text.trim());
    if (mounted && ref.read(recuperacionProvider).error == null) {
      _focoCodigo.requestFocus();
    }
  }

  Future<void> _cambiarPassword() async {
    if (ref.read(recuperacionProvider).cargando) return;
    FocusScope.of(context).unfocus();

    if (_codigo.text.length != 6) {
      setState(() => _errorLocal = 'El código son 6 dígitos.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _errorLocal = 'La contraseña debe tener al menos 8 caracteres.');
      return;
    }
    setState(() => _errorLocal = null);

    final ok = await ref.read(recuperacionProvider.notifier).confirmar(
          _codigo.text,
          _password.text,
        );
    if (!mounted || !ok) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña actualizada. Ya puedes iniciar sesión.')),
    );
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(recuperacionProvider);
    final enPasoEmail = estado.paso == PasoRecuperacion.email;
    final mensaje = _errorLocal ?? estado.error;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: PaletaAuth.fondo,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: PaletaAuth.fondo,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: PaletaAuth.textoFuerte,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: estado.cargando ? null : () => context.pop(),
          ),
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, restricciones) {
              final compacto = restricciones.maxHeight < 680;
              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(24, 0, 24, compacto ? 20 : 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AparicionSuave(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Encabezado(
                            enPasoEmail: enPasoEmail,
                            email: estado.email,
                            minutos: estado.minutos,
                          ),
                          SizedBox(height: compacto ? 20 : 28),
                          TarjetaAuth(
                            children: enPasoEmail
                                ? _camposEmail(estado.cargando, mensaje)
                                : _camposCodigo(estado.cargando, mensaje),
                          ),
                          if (!enPasoEmail) ...[
                            SizedBox(height: compacto ? 14 : 20),
                            PiePregunta(
                              pregunta: '¿Te equivocaste de correo?',
                              accion: 'Cambiarlo',
                              alPulsar: estado.cargando
                                  ? null
                                  : () {
                                      setState(() => _errorLocal = null);
                                      _codigo.clear();
                                      _password.clear();
                                      ref
                                          .read(recuperacionProvider.notifier)
                                          .volverAlEmail();
                                    },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _camposEmail(bool cargando, String? mensaje) => [
        CampoTexto(
          etiqueta: 'Correo electrónico',
          pista: 'nombre@correo.com',
          icono: Icons.alternate_email_rounded,
          controlador: _email,
          foco: _focoEmail,
          habilitado: !cargando,
          tipoTeclado: TextInputType.emailAddress,
          accionTeclado: TextInputAction.done,
          autocompletado: const [AutofillHints.email],
          alEnviar: (_) => _pedirCodigo(),
        ),
        BannerError(mensaje: mensaje),
        const SizedBox(height: 24),
        BotonPrincipal(
          cargando: cargando,
          alPulsar: _pedirCodigo,
          texto: 'Enviar código',
          textoCargando: 'Enviando…',
        ),
      ];

  List<Widget> _camposCodigo(bool cargando, String? mensaje) => [
        CampoTexto(
          etiqueta: 'Código de 6 dígitos',
          pista: '000000',
          icono: Icons.pin_outlined,
          controlador: _codigo,
          foco: _focoCodigo,
          habilitado: !cargando,
          tipoTeclado: TextInputType.number,
          accionTeclado: TextInputAction.next,
          autocompletado: const [AutofillHints.oneTimeCode],
          alEnviar: (_) => _focoPassword.requestFocus(),
        ),
        const SizedBox(height: 18),
        CampoTexto(
          etiqueta: 'Nueva contraseña',
          pista: 'Mínimo 8 caracteres',
          icono: Icons.lock_outline_rounded,
          controlador: _password,
          foco: _focoPassword,
          habilitado: !cargando,
          oculto: _ocultarPassword,
          accionTeclado: TextInputAction.done,
          autocompletado: const [AutofillHints.newPassword],
          alEnviar: (_) => _cambiarPassword(),
          sufijo: BotonVerContrasena(
            oculta: _ocultarPassword,
            alPulsar: () => setState(() => _ocultarPassword = !_ocultarPassword),
          ),
        ),
        BannerError(mensaje: mensaje),
        const SizedBox(height: 24),
        BotonPrincipal(
          cargando: cargando,
          alPulsar: _cambiarPassword,
          texto: 'Cambiar contraseña',
          textoCargando: 'Guardando…',
        ),
      ];
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.enPasoEmail,
    required this.email,
    required this.minutos,
  });

  final bool enPasoEmail;
  final String email;
  final int minutos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          enPasoEmail ? 'Recuperar contraseña' : 'Revisa tu correo',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: PaletaAuth.textoFuerte,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          enPasoEmail
              ? 'Te enviaremos un código de 6 dígitos para que puedas elegir una contraseña nueva.'
              : 'Si $email está registrado, recibirá un código. Caduca en $minutos minutos.',
          style: const TextStyle(fontSize: 14, height: 1.45, color: PaletaAuth.textoSuave),
        ),
      ],
    );
  }
}
