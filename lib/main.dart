import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/bloqueo_service.dart';
import 'services/navegacion.dart';
import 'services/preferencias.dart';
import 'screens/login_screen.dart';
import 'pantallas/menu_principal.dart';
import 'screens/pantalla_bloqueo.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instancia.cargarConfiguracion();
  final preferencias = Preferencias();
  await preferencias.cargar();
  runApp(SistemaPsicologiaApp(preferencias: preferencias));
}

class SistemaPsicologiaApp extends StatelessWidget {
  final Preferencias preferencias;
  const SistemaPsicologiaApp({super.key, required this.preferencias});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: preferencias),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => BloqueoService(preferencias)),
        ChangeNotifierProvider(create: (_) => Navegacion()),
      ],
      child: Consumer<Preferencias>(
        builder: (context, prefs, _) => MaterialApp(
          title: 'Depto. de Psicología',
          navigatorKey: navegadorRaiz,
          debugShowCheckedModeBanner: false,
          theme: Tema.claro(),
          darkTheme: Tema.oscuro(),
          themeMode: prefs.modoTema,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // La capa de bloqueo va por encima del Navigator: tapa también las pantallas abiertas
          // encima del menú (ficha, formularios) sin cerrarlas.
          builder: (context, child) => _CapaSesion(child: child ?? const SizedBox()),
          home: Consumer<AuthService>(
            builder: (context, auth, _) => auth.logueado ? const MenuPrincipal() : const LoginScreen(),
          ),
        ),
      ),
    );
  }
}

class _CapaSesion extends StatelessWidget {
  final Widget child;
  const _CapaSesion({required this.child});

  @override
  Widget build(BuildContext context) {
    final bloqueo = context.watch<BloqueoService>();
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => bloqueo.registrarActividad(),
      child: Stack(
        children: [
          child,
          if (bloqueo.bloqueado) const Positioned.fill(child: PantallaBloqueo()),
        ],
      ),
    );
  }
}
