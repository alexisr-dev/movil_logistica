import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Los datos del locale español para `intl`. Sin esto, cualquier
  // `DateFormat(..., 'es')` lanza `LocaleDataException` en cuanto se pinta la
  // primera fecha: la app va en español, así que el formato no puede depender
  // del idioma que tenga configurado el teléfono.
  await initializeDateFormatting('es');

  // Se restaura la sesión guardada antes del primer frame, para no mostrar el
  // login y saltar a la lista un instante después. Es solo lectura local, sin
  // red: no retrasa el arranque aunque el backend esté caído.
  final contenedor = ProviderContainer();
  await contenedor.read(authProvider.notifier).comprobarSesion();

  runApp(
    UncontrolledProviderScope(
      container: contenedor,
      child: const LogisticaApp(),
    ),
  );
}

class LogisticaApp extends ConsumerWidget {
  const LogisticaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Logística',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Traduce los textos que pone Flutter por su cuenta: el tirador de
      // recarga, los menús de los campos de texto y el selector de fechas
      // salían en inglés dentro de una app en español.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
