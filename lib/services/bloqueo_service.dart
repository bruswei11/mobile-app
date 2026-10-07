import 'dart:async';
import 'package:flutter/widgets.dart';
import 'api_client.dart';
import 'preferencias.dart';

/// Equivalente de BloqueoPantalla del escritorio: tras N minutos sin tocar la pantalla (o al
/// volver a la app después de N minutos en segundo plano, o a pedido) una capa opaca tapa todo
/// y pide la contraseña de la cuenta. Nada de lo que había abierto se pierde. No se bloquea
/// solo mientras corre el cronómetro de una atención. 5 contraseñas incorrectas cierran la sesión.
class BloqueoService extends ChangeNotifier with WidgetsBindingObserver {
  static const maxIntentos = 5;

  final Preferencias preferencias;
  BloqueoService(this.preferencias);

  bool activo = false; // hay sesión iniciada
  bool bloqueado = false;
  int intentosFallidos = 0;

  /// Cronómetros de atención en marcha (no se bloquea solo mientras haya alguno).
  int atencionesEnCurso = 0;

  DateTime _ultimaActividad = DateTime.now();
  DateTime? _pasoASegundoPlano;
  Timer? _reloj;

  void iniciar() {
    activo = true;
    bloqueado = false;
    intentosFallidos = 0;
    _ultimaActividad = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    _reloj?.cancel();
    _reloj = Timer.periodic(const Duration(seconds: 15), (_) => _revisarInactividad());
  }

  /// `notificar: false` cuando se llama desde un dispose (el árbol está bloqueado).
  void detener({bool notificar = true}) {
    activo = false;
    bloqueado = false;
    atencionesEnCurso = 0;
    _reloj?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (notificar) notifyListeners();
  }

  void registrarActividad() {
    _ultimaActividad = DateTime.now();
  }

  bool get _puedeBloquearseSolo =>
      activo && !bloqueado && preferencias.bloqueoMinutos > 0 && atencionesEnCurso == 0;

  void _revisarInactividad() {
    if (!_puedeBloquearseSolo) return;
    if (DateTime.now().difference(_ultimaActividad).inMinutes >= preferencias.bloqueoMinutos) {
      bloquear();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pasoASegundoPlano ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final desde = _pasoASegundoPlano;
      _pasoASegundoPlano = null;
      if (desde != null && _puedeBloquearseSolo &&
          DateTime.now().difference(desde).inMinutes >= preferencias.bloqueoMinutos) {
        bloquear();
      } else {
        registrarActividad();
      }
    }
  }

  void bloquear() {
    if (!activo || bloqueado) return;
    bloqueado = true;
    intentosFallidos = 0;
    notifyListeners();
    ApiClient.instancia.post('/api/usuarios/me/bloqueo', null).catchError((_) => null);
  }

  /// null = desbloqueado; si no, el mensaje a mostrar. `cerrarSesion` se pone en true al
  /// agotar los intentos.
  Future<({String? error, bool cerrarSesion})> desbloquear(String password) async {
    try {
      await ApiClient.instancia.post('/api/usuarios/me/desbloqueo', {'password': password});
      bloqueado = false;
      intentosFallidos = 0;
      registrarActividad();
      notifyListeners();
      return (error: null, cerrarSesion: false);
    } on ApiException catch (e) {
      if (e.statusCode != 401) return (error: e.mensaje, cerrarSesion: false);
      intentosFallidos++;
      if (intentosFallidos >= maxIntentos) {
        return (error: 'Demasiados intentos. Se cerró la sesión por seguridad.', cerrarSesion: true);
      }
      final restantes = maxIntentos - intentosFallidos;
      return (
        error: 'Contraseña incorrecta${restantes <= 2 ? ' ($restantes intento(s) antes de cerrar la sesión)' : ''}',
        cerrarSesion: false
      );
    } catch (_) {
      return (error: 'No se pudo conectar con el servidor', cerrarSesion: false);
    }
  }
}
