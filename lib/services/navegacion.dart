import 'package:flutter/foundation.dart';
import '../models/paciente.dart';

/// Las tres tarjetas del menú principal del escritorio (MenuPrincipal).
enum Seccion { menu, estudiantes, panel, configuracion }

/// Pestañas de EstudiantesPanel.
enum PestanaEstudiantes { lista, agenda, reportes }

/// Lo que en el escritorio hacen MenuPrincipal + EstudiantesPanel + Dashboard.Navegacion +
/// BusquedaRapida.registrarReciente: qué sección se ve, qué pestaña de Estudiantes, si hay una ficha
/// abierta en lugar de la lista, pedidos entre secciones (ej. "Estudiantes por curso" → lista
/// filtrada) y los estudiantes abiertos en esta sesión. Se reinicia en cada inicio de sesión.
class Navegacion extends ChangeNotifier {
  Seccion seccion = Seccion.menu;
  PestanaEstudiantes pestana = PestanaEstudiantes.lista;
  int? fichaAbierta;
  int pestanaFicha = 0;

  /// Curso pedido desde el Panel; la lista lo toma y lo limpia.
  String? cursoPedido;

  /// Sube cada vez que algo cambió datos que otras pantallas muestran (para recargar).
  int version = 0;

  final List<Paciente> recientes = [];

  /// Manejadores de Esc apilados (paneles laterales abiertos, ficha…). El último que devuelve
  /// true "consume" la tecla; si ninguno, Esc vuelve al menú.
  final List<bool Function()> _alEscape = [];

  void reiniciar() {
    seccion = Seccion.menu;
    pestana = PestanaEstudiantes.lista;
    fichaAbierta = null;
    cursoPedido = null;
    recientes.clear();
    _alEscape.clear();
  }

  void irA(Seccion nueva) {
    seccion = nueva;
    notifyListeners();
  }

  void irAlMenu() => irA(Seccion.menu);

  void verPestana(PestanaEstudiantes p) {
    seccion = Seccion.estudiantes;
    pestana = p;
    fichaAbierta = null;
    notifyListeners();
  }

  void verListaFiltrada(String curso) {
    cursoPedido = curso;
    verPestana(PestanaEstudiantes.lista);
  }

  String? tomarCursoPedido() {
    final c = cursoPedido;
    cursoPedido = null;
    return c;
  }

  void abrirFicha(int pacienteId, {int pestanaInicial = 0}) {
    seccion = Seccion.estudiantes;
    fichaAbierta = pacienteId;
    pestanaFicha = pestanaInicial;
    notifyListeners();
  }

  void cerrarFicha() {
    fichaAbierta = null;
    notifyListeners();
  }

  void datosCambiados() {
    version++;
    notifyListeners();
  }

  void registrarReciente(Paciente p) {
    recientes.removeWhere((r) => r.id == p.id);
    recientes.insert(0, p);
    if (recientes.length > 6) recientes.removeLast();
  }

  void registrarEscape(bool Function() manejador) => _alEscape.add(manejador);
  void quitarEscape(bool Function() manejador) => _alEscape.remove(manejador);

  /// Esc: primero lo que esté abierto (panel, ficha), después volver al menú.
  bool escape() {
    for (final m in _alEscape.reversed.toList()) {
      if (m()) return true;
    }
    if (fichaAbierta != null) {
      cerrarFicha();
      return true;
    }
    if (seccion != Seccion.menu) {
      irAlMenu();
      return true;
    }
    return false;
  }
}
