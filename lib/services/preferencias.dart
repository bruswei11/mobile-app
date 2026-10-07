import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de ESTE dispositivo (como tema.properties en la PC): tema claro/oscuro y
/// minutos de inactividad antes de bloquear la app.
class Preferencias extends ChangeNotifier {
  static const _claveTema = 'tema.modo';
  static const _claveBloqueo = 'bloqueo.minutos';

  /// Mismas opciones que el combo "Bloquear la pantalla tras" del escritorio (0 = nunca).
  static const opcionesBloqueo = [1, 5, 10, 15, 30, 0];

  ThemeMode modoTema = ThemeMode.system;
  int bloqueoMinutos = 5;

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_claveTema)) {
      case 'claro':
        modoTema = ThemeMode.light;
        break;
      case 'oscuro':
        modoTema = ThemeMode.dark;
        break;
      default:
        modoTema = ThemeMode.system;
    }
    bloqueoMinutos = prefs.getInt(_claveBloqueo) ?? 5;
  }

  Future<void> cambiarTema(ThemeMode modo) async {
    modoTema = modo;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _claveTema, modo == ThemeMode.light ? 'claro' : modo == ThemeMode.dark ? 'oscuro' : 'sistema');
  }

  Future<void> cambiarBloqueo(int minutos) async {
    bloqueoMinutos = minutos;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_claveBloqueo, minutos);
  }

  static String etiquetaBloqueo(int minutos) {
    if (minutos == 0) return 'Nunca';
    if (minutos == 1) return '1 minuto';
    return '$minutos minutos';
  }
}
