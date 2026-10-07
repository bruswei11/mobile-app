import 'package:flutter/widgets.dart';
import '../tema.dart';
import 'api_client.dart';

/// Navigator raíz: al cerrar sesión se cierran las pantallas abiertas (ficha, formularios) para
/// que no queden visibles debajo del login.
final navegadorRaiz = GlobalKey<NavigatorState>();

/// Equivalente móvil de util.Sesion del escritorio: quién está logueado ahora. La identidad real
/// de cada request la valida el backend a partir del JWT, no de lo que diga este objeto -- esto
/// es solo para que la interfaz sepa qué mostrar/ocultar.
class AuthService extends ChangeNotifier {
  int? usuarioId;
  String? usuario;
  String? nombre;
  String? rol;

  /// Solo josechavez: ve la pestaña Configuración → Usuarios para crear cuentas nuevas (el servidor
  /// vuelve a comprobarlo en cada pedido).
  bool puedeCrearUsuarios = false;

  /// Motivo del último cierre automático (sesión vencida, demasiados intentos), para mostrarlo
  /// en el login.
  String? motivoCierre;

  AuthService() {
    ApiClient.instancia.alExpirarSesion = () {
      if (logueado) cerrarSesion(motivo: 'La sesión venció. Volvé a ingresar.');
    };
  }

  bool get logueado => usuarioId != null;
  // Solo hay profesionales de psicología (cada uno ve únicamente a sus estudiantes).
  bool get esAdmin => false;
  bool get esPsicologo => true;
  bool get esSecretaria => false;

  String etiquetaRol() => Tema.etiquetaRol(rol);

  Future<String?> login(String usuarioInput, String password) async {
    try {
      final resp = await ApiClient.instancia.post('/api/auth/login', {
        'usuario': usuarioInput,
        'password': password,
      });
      ApiClient.instancia.guardarToken(resp['token']);
      usuarioId = resp['usuarioId'];
      usuario = resp['usuario'];
      nombre = resp['nombre'];
      rol = resp['rol'];
      puedeCrearUsuarios = resp['puedeCrearUsuarios'] == true;
      motivoCierre = null;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.mensaje;
    } catch (e) {
      return 'No se pudo conectar con el servidor. Revisá la dirección configurada y que el celular esté en la misma red.';
    }
  }

  void cerrarSesion({String? motivo}) {
    navegadorRaiz.currentState?.popUntil((r) => r.isFirst);
    ApiClient.instancia.cerrarSesion();
    usuarioId = null;
    usuario = null;
    nombre = null;
    rol = null;
    puedeCrearUsuarios = false;
    motivoCierre = motivo;
    notifyListeners();
  }

  void actualizarNombre(String nuevoNombre) {
    nombre = nuevoNombre;
    notifyListeners();
  }
}
