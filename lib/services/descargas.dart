import 'dart:convert';
import 'descargas_stub.dart' if (dart.library.js_interop) 'descargas_web.dart' as impl;

/// Guardar u abrir un archivo recibido del servidor (reporte, adjunto). En el navegador lo descarga
/// o lo abre en una pestaña nueva; en la app instalada todavía no está disponible.
class Descargas {
  Descargas._();

  static bool get disponible => impl.disponible;

  /// Descarga el archivo en el dispositivo (carpeta Descargas del navegador).
  static void guardar(List<int> bytes, String nombre, String tipo) => impl.guardar(bytes, nombre, tipo);

  /// Abre el archivo en una pestaña (imágenes, PDF, texto); si no se puede mostrar, lo descarga.
  static void abrir(List<int> bytes, String nombre, String tipo) => impl.abrir(bytes, nombre, tipo);

  /// Descarga un texto generado en el propio dispositivo (CSV con BOM para Excel en español).
  static void guardarTexto(String texto, String nombre, String tipo, {bool conBom = true}) =>
      impl.guardar([if (conBom) ...const [0xEF, 0xBB, 0xBF], ...utf8.encode(texto)], nombre, tipo);
}
