class Turno {
  int? id;
  int pacienteId;
  String? pacienteNombre;
  String? curso;
  int? psicologoId;
  String? psicologoNombre;
  String fechaHora; // ISO local date-time, ej. 2026-12-01T10:00:00
  int duracionMinutos;
  String estado; // programado, completado, cancelado, ausente
  String? notas;

  Turno({
    this.id,
    required this.pacienteId,
    this.pacienteNombre,
    this.curso,
    this.psicologoId,
    this.psicologoNombre,
    required this.fechaHora,
    this.duracionMinutos = 45,
    this.estado = 'programado',
    this.notas,
  });

  factory Turno.fromJson(Map<String, dynamic> j) => Turno(
        id: j['id'],
        pacienteId: j['pacienteId'],
        pacienteNombre: j['pacienteNombre'],
        curso: j['curso'],
        psicologoId: j['psicologoId'],
        psicologoNombre: j['psicologoNombre'],
        fechaHora: j['fechaHora'],
        duracionMinutos: j['duracionMinutos'] ?? 45,
        estado: j['estado'] ?? 'programado',
        notas: j['notas'],
      );

  Map<String, dynamic> toJson() => {
        'pacienteId': pacienteId,
        'psicologoId': psicologoId,
        'fechaHora': fechaHora,
        'estado': estado,
        'notas': notas,
      };

  DateTime get fecha => DateTime.parse(fechaHora);

  static String etiquetaEstado(String estado) {
    switch (estado) {
      case 'programado':
        return 'Programada';
      case 'completado':
        return 'Completada';
      case 'cancelado':
        return 'Cancelada';
      case 'ausente':
        return 'No asistió';
      default:
        return estado;
    }
  }
}

class Psicologo {
  final int id;
  final String nombre;
  Psicologo(this.id, this.nombre);
  factory Psicologo.fromJson(Map<String, dynamic> j) => Psicologo(j['id'], j['nombre']);
}
