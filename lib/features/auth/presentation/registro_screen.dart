import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';
import 'widgets/piezas_auth.dart';

class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({super.key});

  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _password = TextEditingController();
  final _repetir = TextEditingController();

  final _focoNombre = FocusNode();
  final _focoApellido = FocusNode();
  final _focoEmail = FocusNode();
  final _focoTelefono = FocusNode();
  final _focoPassword = FocusNode();
  final _focoRepetir = FocusNode();

  bool _ocultarPassword = true;
  String? _errorLocal;

  @override
  void dispose() {
    for (final c in [_nombre, _apellido, _email, _telefono, _password, _repetir]) {
      c.dispose();
    }
    for (final f in [
      _focoNombre,
      _focoApellido,
      _focoEmail,
      _focoTelefono,
      _focoPassword,
      _focoRepetir
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  String? _validar() {
    if (!_email.text.contains('@') || !_email.text.contains('.')) {
      return 'Escribe un correo válido.';
    }
    if (_password.text.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (_password.text != _repetir.text) {
      return 'Las dos contraseñas no coinciden.';
    }
    return null;
  }

  Future<void> _crearCuenta() async {
    if (ref.read(authProvider).cargando) return;
    FocusScope.of(context).unfocus();

    final problema = _validar();
    setState(() => _errorLocal = problema);
    if (problema != null) return;

    // Si sale bien, el `redirect` del router saca de esta pantalla solo: la
    // sesión ya queda abierta con los tokens que devuelve el registro.
    await ref.read(authProvider.notifier).registrar(
          email: _email.text.trim(),
          password: _password.text,
          nombre: _nombre.text.trim(),
          apellido: _apellido.text.trim(),
          telefono: _telefono.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(authProvider);
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
                          const _Encabezado(),
                          SizedBox(height: compacto ? 20 : 28),
                          TarjetaAuth(
                            children: [
                              CampoTexto(
                                etiqueta: 'Nombre',
                                pista: 'Ana',
                                icono: Icons.person_outline_rounded,
                                controlador: _nombre,
                                foco: _focoNombre,
                                habilitado: !estado.cargando,
                                accionTeclado: TextInputAction.next,
                                autocompletado: const [AutofillHints.givenName],
                                alEnviar: (_) => _focoApellido.requestFocus(),
                              ),
                              const SizedBox(height: 18),
                              CampoTexto(
                                etiqueta: 'Apellido',
                                pista: 'Pérez',
                                icono: Icons.badge_outlined,
                                controlador: _apellido,
                                foco: _focoApellido,
                                habilitado: !estado.cargando,
                                accionTeclado: TextInputAction.next,
                                autocompletado: const [AutofillHints.familyName],
                                alEnviar: (_) => _focoEmail.requestFocus(),
                              ),
                              const SizedBox(height: 18),
                              CampoTexto(
                                etiqueta: 'Correo electrónico',
                                pista: 'nombre@correo.com',
                                icono: Icons.alternate_email_rounded,
                                controlador: _email,
                                foco: _focoEmail,
                                habilitado: !estado.cargando,
                                tipoTeclado: TextInputType.emailAddress,
                                accionTeclado: TextInputAction.next,
                                autocompletado: const [AutofillHints.email],
                                alEnviar: (_) => _focoTelefono.requestFocus(),
                              ),
                              const SizedBox(height: 18),
                              CampoTexto(
                                etiqueta: 'Teléfono (opcional)',
                                pista: '999 888 777',
                                icono: Icons.phone_outlined,
                                controlador: _telefono,
                                foco: _focoTelefono,
                                habilitado: !estado.cargando,
                                tipoTeclado: TextInputType.phone,
                                accionTeclado: TextInputAction.next,
                                autocompletado: const [AutofillHints.telephoneNumber],
                                alEnviar: (_) => _focoPassword.requestFocus(),
                              ),
                              const SizedBox(height: 18),
                              CampoTexto(
                                etiqueta: 'Contraseña',
                                pista: 'Mínimo 8 caracteres',
                                icono: Icons.lock_outline_rounded,
                                controlador: _password,
                                foco: _focoPassword,
                                habilitado: !estado.cargando,
                                oculto: _ocultarPassword,
                                accionTeclado: TextInputAction.next,
                                autocompletado: const [AutofillHints.newPassword],
                                alEnviar: (_) => _focoRepetir.requestFocus(),
                                sufijo: BotonVerContrasena(
                                  oculta: _ocultarPassword,
                                  alPulsar: () => setState(
                                    () => _ocultarPassword = !_ocultarPassword,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              CampoTexto(
                                etiqueta: 'Repite la contraseña',
                                pista: 'La misma de arriba',
                                icono: Icons.lock_reset_rounded,
                                controlador: _repetir,
                                foco: _focoRepetir,
                                habilitado: !estado.cargando,
                                oculto: _ocultarPassword,
                                accionTeclado: TextInputAction.done,
                                alEnviar: (_) => _crearCuenta(),
                              ),
                              BannerError(mensaje: mensaje),
                              const SizedBox(height: 24),
                              BotonPrincipal(
                                cargando: estado.cargando,
                                alPulsar: _crearCuenta,
                                texto: 'Crear cuenta',
                                textoCargando: 'Creando…',
                              ),
                            ],
                          ),
                          SizedBox(height: compacto ? 18 : 26),
                          PiePregunta(
                            pregunta: '¿Ya tienes cuenta?',
                            accion: 'Inicia sesión',
                            alPulsar: estado.cargando ? null : () => context.pop(),
                          ),
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
}

class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crear cuenta',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: PaletaAuth.textoFuerte,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Regístrate para hacer pedidos y seguir tus entregas en tiempo real.',
          style: TextStyle(fontSize: 14, height: 1.45, color: PaletaAuth.textoSuave),
        ),
      ],
    );
  }
}
