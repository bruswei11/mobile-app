/// Copia fiel de util.EstructuraAcademica del escritorio: el catálogo cerrado y oficial de
/// cursos del colegio. Solo cambia si cambia la oferta real del colegio (y entonces en los dos
/// lados a la vez; el servidor además rechaza cualquier etiqueta fuera del catálogo).
class EstructuraAcademica {
  EstructuraAcademica._();

  static const nivelEEB = 'Educación Escolar Básica';
  static const nivelBachillerato = 'Bachillerato';
  static const niveles = [nivelEEB, nivelBachillerato];

  static const turnoManana = 'Mañana';
  static const turnoTarde = 'Tarde';

  static const gradosEEB = ['7°', '8°', '9°'];
  static const seccionesEEB = ['A', 'B'];

  /// 8°B y 9°B solo tienen Mañana.
  static List<String> turnosValidosEEB(String? grado, String? seccion) {
    if (seccion == 'B' && (grado == '8°' || grado == '9°')) return const [turnoManana];
    return const [turnoManana, turnoTarde];
  }

  static const aniosBachillerato = ['1er año', '2do año', '3er año'];
  static const modalidadTecnico = 'Técnico';
  static const modalidadCientifico = 'Científico';
  static const modalidades = [modalidadTecnico, modalidadCientifico];

  static List<String> especialidadesPorModalidad(String? modalidad) {
    if (modalidad == modalidadTecnico) return const ['Informática', 'Salud', 'Contabilidad'];
    if (modalidad == modalidadCientifico) return const ['Ciencias Sociales'];
    return const [];
  }

  static List<String> turnosValidosBachillerato(String? especialidad) {
    switch (especialidad) {
      case 'Informática':
        return const [turnoManana, turnoTarde];
      case 'Salud':
        return const [turnoTarde];
      case 'Contabilidad':
      case 'Ciencias Sociales':
        return const [turnoManana];
      default:
        return const [];
    }
  }

  static String etiquetaEEB(String grado, String seccion, String turno) => '$grado EEB - Sección $seccion - Turno $turno';

  static String etiquetaBachillerato(String anio, String modalidad, String especialidad, String turno) =>
      'Bachillerato $modalidad en $especialidad - $anio - Turno $turno';

  static SeleccionCurso? parsear(String? etiqueta) {
    if (etiqueta == null) return null;
    final e = etiqueta.trim();
    if (e.startsWith('Bachillerato ')) {
      for (final modalidad in modalidades) {
        final prefijo = 'Bachillerato $modalidad en ';
        if (e.startsWith(prefijo)) {
          final partes = e.substring(prefijo.length).split(' - ');
          if (partes.length == 3) {
            return SeleccionCurso(
              esBachillerato: true,
              especialidad: partes[0].trim(),
              anio: partes[1].trim(),
              modalidad: modalidad,
              turno: partes[2].replaceAll('Turno', '').trim(),
            );
          }
        }
      }
      return null;
    }
    for (final grado in gradosEEB) {
      final prefijo = '$grado EEB - Sección ';
      if (e.startsWith(prefijo)) {
        final partes = e.substring(prefijo.length).split(' - ');
        if (partes.length == 2) {
          return SeleccionCurso(
            esBachillerato: false,
            grado: grado,
            seccion: partes[0].trim(),
            turno: partes[1].replaceAll('Turno', '').trim(),
          );
        }
      }
    }
    return null;
  }
}

/// Estado del selector (lo que se eligió hasta ahora; puede estar incompleto).
class SeleccionCurso {
  bool esBachillerato;
  String? grado;
  String? seccion;
  String? anio;
  String? modalidad;
  String? especialidad;
  String? turno;

  SeleccionCurso({
    this.esBachillerato = false,
    this.grado,
    this.seccion,
    this.anio,
    this.modalidad,
    this.especialidad,
    this.turno,
  });

  List<String> get turnosPosibles => esBachillerato
      ? EstructuraAcademica.turnosValidosBachillerato(especialidad)
      : (grado != null && seccion != null ? EstructuraAcademica.turnosValidosEEB(grado, seccion) : const []);

  /// Etiqueta canónica si la selección está completa y es válida; si no, null.
  String? get etiqueta {
    if (turno == null || !turnosPosibles.contains(turno)) return null;
    if (esBachillerato) {
      if (anio == null || modalidad == null || especialidad == null) return null;
      if (!EstructuraAcademica.especialidadesPorModalidad(modalidad).contains(especialidad)) return null;
      return EstructuraAcademica.etiquetaBachillerato(anio!, modalidad!, especialidad!, turno!);
    }
    if (grado == null || seccion == null) return null;
    return EstructuraAcademica.etiquetaEEB(grado!, seccion!, turno!);
  }

  /// Si solo hay un turno posible se elige solo; si el elegido dejó de ser válido se limpia.
  void ajustarTurno() {
    final posibles = turnosPosibles;
    if (posibles.length == 1) {
      turno = posibles.first;
    } else if (turno != null && !posibles.contains(turno)) {
      turno = null;
    }
  }
}
