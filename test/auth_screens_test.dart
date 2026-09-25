// Pruebas de las pantallas de acceso.
//
// El proyecto no tenía tests: estos cubren lo que no se ve al compilar — que
// las pantallas montan de verdad y que la validación en cliente corta antes de
// llegar al backend.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_logistica/features/auth/presentation/recuperar_password_screen.dart';
import 'package:movil_logistica/features/auth/presentation/registro_screen.dart';
import 'package:movil_logistica/features/auth/presentation/widgets/piezas_auth.dart';

Future<void> _pulsarCrearCuenta(WidgetTester tester) async {
  final boton = find.widgetWithText(FilledButton, 'Crear cuenta');
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pump();
}

Widget _montar(Widget pantalla) => ProviderScope(
      child: MaterialApp(home: pantalla),
    );

void main() {
  group('RegistroScreen', () {
    testWidgets('muestra los campos del alta de cliente', (tester) async {
      await tester.pumpWidget(_montar(const RegistroScreen()));

      expect(find.text('Crear cuenta'), findsWidgets);
      for (final etiqueta in [
        'Nombre',
        'Apellido',
        'Correo electrónico',
        'Teléfono (opcional)',
        'Contraseña',
        'Repite la contraseña',
      ]) {
        expect(find.text(etiqueta), findsOneWidget, reason: 'falta el campo $etiqueta');
      }
    });

    testWidgets('avisa si las dos contraseñas no coinciden', (tester) async {
      await tester.pumpWidget(_montar(const RegistroScreen()));

      final campos = find.byType(TextField);
      await tester.enterText(campos.at(0), 'Ana');
      await tester.enterText(campos.at(1), 'Pérez');
      await tester.enterText(campos.at(2), 'ana@correo.com');
      await tester.enterText(campos.at(4), 'Trufa#Naranja7');
      await tester.enterText(campos.at(5), 'OtraDistinta#9');
      await tester.pump();

      await _pulsarCrearCuenta(tester);

      expect(find.text('Las dos contraseñas no coinciden.'), findsOneWidget);
    });

    testWidgets('rechaza un correo sin formato válido', (tester) async {
      await tester.pumpWidget(_montar(const RegistroScreen()));

      final campos = find.byType(TextField);
      await tester.enterText(campos.at(2), 'esto-no-es-un-correo');
      await tester.pump();

      await _pulsarCrearCuenta(tester);

      expect(find.text('Escribe un correo válido.'), findsOneWidget);
    });
  });

  group('RecuperarPasswordScreen', () {
    testWidgets('arranca en el paso del correo', (tester) async {
      await tester.pumpWidget(_montar(const RecuperarPasswordScreen()));

      expect(find.text('Recuperar contraseña'), findsOneWidget);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Enviar código'), findsOneWidget);
      // El código y la contraseña son del segundo paso: aún no deben estar.
      expect(find.text('Código de 6 dígitos'), findsNothing);
    });

    testWidgets('rechaza un correo inválido sin llamar al backend', (tester) async {
      await tester.pumpWidget(_montar(const RecuperarPasswordScreen()));

      await tester.enterText(find.byType(TextField).first, 'sin-arroba');
      await tester.pump();
      await tester.tap(find.text('Enviar código'));
      await tester.pump();

      expect(find.text('Escribe un correo válido.'), findsOneWidget);
      // Sigue en el paso 1: no ha avanzado.
      expect(find.text('Código de 6 dígitos'), findsNothing);
    });
  });

  group('BannerError', () {
    testWidgets('no ocupa sitio cuando no hay mensaje', (tester) async {
      await tester.pumpWidget(_montar(
        const Scaffold(body: BannerError(mensaje: null)),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('error'), findsNothing);
    });

    testWidgets('muestra el mensaje del backend tal cual', (tester) async {
      await tester.pumpWidget(_montar(
        const Scaffold(body: BannerError(mensaje: 'Correo: Ya existe un usuario con este correo.')),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Correo: Ya existe un usuario con este correo.'), findsOneWidget);
    });
  });
}
