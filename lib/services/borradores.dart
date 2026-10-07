import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Borradores automáticos de atenciones y entradas de seguimiento sin guardar, en ESTE
/// dispositivo (almacenamiento local del navegador o de la app). Sirven para recuperar lo escrito
/// si se cerró la pestaña, el navegador o el teléfono cerró la app.
///
/// Privacidad (datos clínicos de menores): cada borrador queda atado al usuario y al estudiante,
/// se borra apenas se guarda o se descarta la atención, y vence solo a las 24 horas.
class Borradores {
  Borradores._();

  static const _prefijo = 'borrador.';
  static const vigencia = Duration(hours: 24);

  static String claveAtencion(int usuarioId, int pacienteId) => 'atencion.$usuarioId.$pacienteId';
  static String claveSeguimiento(int usuarioId, int pacienteId) => 'seguimiento.$usuarioId.$pacienteId';

  static Future<void> guardar(String clave, Map<String, dynamic> datos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefijo$clave', jsonEncode({...datos, 'guardadoEn': DateTime.now().toIso8601String()}));
  }

  /// El borrador (con 'guardadoEn') o null si no hay o ya venció.
  static Future<Map<String, dynamic>?> leer(String clave) async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString('$_prefijo$clave');
    if (texto == null) return null;
    try {
      final datos = jsonDecode(texto) as Map<String, dynamic>;
      final fecha = DateTime.tryParse(datos['guardadoEn'] ?? '');
      if (fecha == null || DateTime.now().difference(fecha) > vigencia) {
        await prefs.remove('$_prefijo$clave');
        return null;
      }
      return datos;
    } catch (_) {
      await prefs.remove('$_prefijo$clave');
      return null;
    }
  }

  static Future<void> borrar(String clave) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefijo$clave');
  }

  /// Quita los borradores vencidos (se llama al iniciar sesión).
  static Future<void> limpiarVencidos() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(_prefijo)).toList()) {
      await leer(k.substring(_prefijo.length));
    }
  }
}
