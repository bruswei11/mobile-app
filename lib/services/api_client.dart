import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Error con el mensaje que ya viene armado por el backend (`{"error": "..."}`), para
/// mostrarlo directo en un SnackBar sin tener que adivinar qué pasó.
class ApiException implements Exception {
  final int statusCode;
  final String mensaje;
  ApiException(this.statusCode, this.mensaje);
  @override
  String toString() => mensaje;
}

/// Un solo lugar para la URL base del backend y el token JWT. La URL se guarda en el dispositivo;
/// el token vive solo en memoria: al cerrar la app hay que volver a ingresar (datos sensibles de
/// menores, igual que el escritorio pide la contraseña en cada inicio).
class ApiClient {
  static const _claveServidor = 'servidor_url';
  static const _claveToken = 'jwt_token';
  static const String servidorPorDefecto = 'http://192.168.18.54:8080';

  String baseUrl = servidorPorDefecto;
  String? token;

  /// Se llama cuando el servidor rechaza el token (venció o se invalidó): la app vuelve al login.
  void Function()? alExpirarSesion;

  static final ApiClient instancia = ApiClient._interno();
  ApiClient._interno();

  Future<void> cargarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();
    // Versión web: la app la sirve el mismo servidor, así que la API está en la misma dirección
    // que la página (no hay IP que configurar).
    baseUrl = kIsWeb ? Uri.base.origin : (prefs.getString(_claveServidor) ?? servidorPorDefecto);
    // Versiones anteriores guardaban el token en el teléfono: se borra.
    await prefs.remove(_claveToken);
  }

  Future<void> guardarServidor(String url) async {
    baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveServidor, url);
  }

  void guardarToken(String nuevoToken) {
    token = nuevoToken;
  }

  void cerrarSesion() {
    token = null;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    // Listas (ej. ids=1&ids=2) se mandan como parámetro repetido.
    final q = query?.map((k, v) => MapEntry(k, v is Iterable ? v.map((e) => e.toString()).toList() : v.toString()));
    return Uri.parse('$baseUrl$path').replace(queryParameters: q);
  }

  dynamic _procesar(http.Response r, String path) {
    if (r.statusCode == 401 && token != null && path != '/api/usuarios/me/desbloqueo'
        && path != '/api/usuarios/me/password' && path != '/api/auth/login') {
      token = null;
      alExpirarSesion?.call();
      throw ApiException(401, 'La sesión venció. Volvé a ingresar.');
    }
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.body.isEmpty) return null;
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
    String mensaje = 'Error de conexión (${r.statusCode})';
    try {
      final cuerpo = jsonDecode(utf8.decode(r.bodyBytes));
      if (cuerpo is Map && cuerpo['error'] != null) {
        mensaje = cuerpo['error'];
      } else if (cuerpo is Map && cuerpo['advertencia'] != null) {
        mensaje = cuerpo['advertencia'];
      }
    } catch (_) {
      // cuerpo no era JSON (ej. 403 de Spring Security sin body) -- se deja el mensaje genérico
    }
    throw ApiException(r.statusCode, mensaje);
  }

  Future<dynamic> get(String path, [Map<String, dynamic>? query]) async {
    final r = await http.get(_uri(path, query), headers: _headers).timeout(const Duration(seconds: 15));
    return _procesar(r, path);
  }

  Future<dynamic> post(String path, Object? body, [Map<String, dynamic>? query]) async {
    final r = await http
        .post(_uri(path, query), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return _procesar(r, path);
  }

  Future<dynamic> put(String path, Object? body, [Map<String, dynamic>? query]) async {
    final r = await http
        .put(_uri(path, query), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return _procesar(r, path);
  }

  /// Descarga un archivo (reporte, adjunto). Devuelve el contenido y el nombre que manda el servidor.
  Future<ArchivoDescargado> descargar(String path, [Map<String, dynamic>? query]) async {
    final r = await http.get(_uri(path, query), headers: _headers).timeout(const Duration(seconds: 60));
    if (r.statusCode < 200 || r.statusCode >= 300) {
      _procesar(r, path); // lanza ApiException con el mensaje del servidor
    }
    return ArchivoDescargado(r.bodyBytes, _nombreDe(r.headers['content-disposition']) ?? 'archivo',
        r.headers['content-type'] ?? 'application/octet-stream');
  }

  /// Sube un archivo como multipart (campo "archivo").
  Future<dynamic> subir(String path, List<int> bytes, String nombre) async {
    final pedido = http.MultipartRequest('POST', _uri(path));
    if (token != null) pedido.headers['Authorization'] = 'Bearer $token';
    pedido.files.add(http.MultipartFile.fromBytes('archivo', bytes, filename: nombre));
    final r = await http.Response.fromStream(await pedido.send().timeout(const Duration(seconds: 120)));
    return _procesar(r, path);
  }

  static String? _nombreDe(String? disposicion) {
    if (disposicion == null) return null;
    final utf8Nombre = RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false).firstMatch(disposicion);
    if (utf8Nombre != null) return Uri.decodeComponent(utf8Nombre.group(1)!);
    final simple = RegExp(r'filename="?([^";]+)"?', caseSensitive: false).firstMatch(disposicion);
    return simple?.group(1);
  }

  Future<dynamic> delete(String path) async {
    final r = await http.delete(_uri(path), headers: _headers).timeout(const Duration(seconds: 15));
    return _procesar(r, path);
  }
}

class ArchivoDescargado {
  final List<int> bytes;
  final String nombre;
  final String tipo;
  ArchivoDescargado(this.bytes, this.nombre, this.tipo);
}
