import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';
import 'widgets/piezas_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController(text: 'cliente@logistica.com');
  final _password = TextEditingController(text: 'clave1234');

  final _focoEmail = FocusNode();
  final _focoPassword = FocusNode();

  bool _ocultarPassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _focoEmail.dispose();
    _focoPassword.dispose();
    super.dispose();
  }

  void _iniciarSesion() {
    if (ref.read(authProvider).cargando) return;
    FocusScope.of(context).unfocus();
    ref.read(authProvider.notifier).login(_email.text, _password.text);
  }

  bool _errorEnCredenciales(String? error) =>
      error != null && error.toLowerCase().contains('credenciales');

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(authProvider);

    // No hace falta navegar a mano al autenticarse: el `redirect` del router
    // reacciona al cambio de estado y saca del login por su cuenta.

    final marcarCampos = _errorEnCredenciales(estado.error);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Fondo claro: la barra de estado necesita iconos oscuros para leerse.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: PaletaAuth.fondo,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: PaletaAuth.fondo,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, restricciones) {
              // Pantallas bajas (o con el teclado abierto) reciben una versión
              // más compacta antes de tener que recurrir al scroll.
              final compacto = restricciones.maxHeight < 680;
              final margenVertical = compacto ? 20.0 : 32.0;

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: margenVertical,
                ),
                child: ConstrainedBox(
                  // Centra el bloque cuando sobra alto y deja que crezca (y se
                  // desplace) cuando el teclado se come la pantalla.
                  constraints: BoxConstraints(
                    minHeight: restricciones.maxHeight - margenVertical * 2,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      // En tablets y teléfonos grandes el formulario no se
                      // estira: mantiene un ancho de lectura cómodo.
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AparicionSuave(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            MarcaAuth(compacto: compacto),
                            SizedBox(height: compacto ? 26 : 38),
                            TarjetaAuth(
                              children: [
                                CampoTexto(
                                  etiqueta: 'Correo electrónico',
                                  pista: 'nombre@correo.com',
                                  icono: Icons.alternate_email_rounded,
                                  controlador: _email,
                                  foco: _focoEmail,
                                  conError: marcarCampos,
                                  habilitado: !estado.cargando,
                                  tipoTeclado: TextInputType.emailAddress,
                                  accionTeclado: TextInputAction.next,
                                  autocompletado: const [
                                    AutofillHints.username,
                                    AutofillHints.email,
                                  ],
                                  alEnviar: (_) => _focoPassword.requestFocus(),
                                ),
                                const SizedBox(height: 18),
                                CampoTexto(
                                  etiqueta: 'Contraseña',
                                  pista: 'Tu contraseña',
                                  icono: Icons.lock_outline_rounded,
                                  controlador: _password,
                                  foco: _focoPassword,
                                  conError: marcarCampos,
                                  habilitado: !estado.cargando,
                                  oculto: _ocultarPassword,
                                  accionTeclado: TextInputAction.done,
                                  autocompletado: const [
                                    AutofillHints.password,
                                  ],
                                  alEnviar: (_) => _iniciarSesion(),
                                  sufijo: BotonVerContrasena(
                                    oculta: _ocultarPassword,
                                    alPulsar: () => setState(
                                      () => _ocultarPassword = !_ocultarPassword,
                                    ),
                                  ),
                                ),
                                BannerError(mensaje: estado.error),
                                const SizedBox(height: 24),
                                BotonPrincipal(
                                  cargando: estado.cargando,
                                  alPulsar: _iniciarSesion,
                                  texto: 'Iniciar sesión',
                                  textoCargando: 'Ingresando…',
                                ),
                                const SizedBox(height: 4),
                                EnlaceAuth(
                                  texto: '¿Olvidaste tu contraseña?',
                                  alPulsar: estado.cargando
                                      ? null
                                      : () => context.push('/recuperar'),
                                ),
                              ],
                            ),
                            SizedBox(height: compacto ? 18 : 26),
                            PiePregunta(
                              pregunta: '¿No tienes cuenta?',
                              accion: 'Crear una',
                              alPulsar: estado.cargando
                                  ? null
                                  : () => context.push('/registro'),
                            ),
                          ],
                        ),
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
}
