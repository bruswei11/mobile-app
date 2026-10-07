import 'turno.dart';

class CasoPendiente {
  final int? pacienteId;
  final String estudiante;
  final String? curso;
  final String ultimoSeguimiento;
  CasoPendiente(this.pacienteId, this.estudiante, this.curso, this.ultimoSeguimiento);
  factory CasoPendiente.fromJson(Map<String, dynamic> j) =>
      CasoPendiente(j['pacienteId'], j['estudiante'], j['curso'], j['ultimoSeguimiento']);
}

class Dashboard {
  final int totalEstudiantes;
  final int totalAtenciones;
  final int totalCitas;
  final int totalProfesionales;
  final int casosPendientes;
  final Map<String, int> nuevosPorMes;
  final Map<String, int> porCurso;
  final Map<String, int> porMotivo;
  final List<Turno> proximasCitas;
  final int? seguimientosVencidosTotal; // ausente para secretaria
  final List<CasoPendiente>? seguimientosVencidosLista;

  Dashboard({
    required this.totalEstudiantes,
    required this.totalAtenciones,
    required this.totalCitas,
    required this.totalProfesionales,
    required this.casosPendientes,
    required this.nuevosPorMes,
    required this.porCurso,
    required this.porMotivo,
    required this.proximasCitas,
    this.seguimientosVencidosTotal,
    this.seguimientosVencidosLista,
  });

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        totalEstudiantes: j['totalEstudiantes'] ?? 0,
        totalAtenciones: j['totalAtenciones'] ?? 0,
        totalCitas: j['totalCitas'] ?? 0,
        totalProfesionales: j['totalProfesionales'] ?? 0,
        casosPendientes: j['casosPendientes'] ?? 0,
        nuevosPorMes: Map<String, int>.from(j['nuevosPorMes'] ?? {}),
        porCurso: Map<String, int>.from(j['porCurso'] ?? {}),
        porMotivo: Map<String, int>.from(j['porMotivo'] ?? {}),
        proximasCitas: (j['proximasCitas'] as List? ?? []).map((e) => Turno.fromJson(e)).toList(),
        seguimientosVencidosTotal: j['seguimientosVencidosTotal'],
        seguimientosVencidosLista: j['seguimientosVencidosLista'] == null
            ? null
            : (j['seguimientosVencidosLista'] as List).map((e) => CasoPendiente.fromJson(e)).toList(),
      );
}
